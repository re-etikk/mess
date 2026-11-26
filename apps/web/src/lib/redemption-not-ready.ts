import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { verifyCounterQRToken } from '@/lib/crypto';
import { addPartnerNotification } from '@/lib/partner-notifications';

/**
 * Executes atomic QR redemption if the database RPC is active,
 * or safely fails closed with zero credit deduction if the RPC is not yet applied.
 */
export async function rejectUnimplementedRedemption(
  req: NextRequest,
  token?: string,
  customerIdParam?: string
) {
  if (!token) {
    return NextResponse.json({ success: false, error: 'QR token is required.' }, { status: 400 });
  }

  // 1. Verify token cryptographic integrity and date validity
  const qrVerification = verifyCounterQRToken(token);
  if (!qrVerification.isValid) {
    return NextResponse.json(
      {
        success: false,
        code: qrVerification.isExpired ? 'QR_EXPIRED' : 'INVALID_QR_TOKEN',
        error: qrVerification.error || 'Invalid or expired QR code.',
      },
      { status: 400 }
    );
  }

  try {
    // 2. Authenticate the customer
    const bearer = req.headers.get('authorization');
    let user: { id: string; email?: string } | null = null;
    const admin = getAdminClient();

    if (bearer?.startsWith('Bearer ')) {
      if (admin) {
        const result = await admin.auth.getUser(bearer.slice(7).trim()).catch(() => ({ data: { user: null } }));
        user = result.data.user;
      }
    } else {
      try {
        const supabase = await createClient();
        const result = await supabase.auth.getUser();
        user = result.data.user;
      } catch {
        // Fallback to customerIdParam
      }
    }

    if (!user && customerIdParam) {
      const cleanParam = customerIdParam.trim();
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (isUuid.test(cleanParam)) {
        user = { id: cleanParam };
      } else if (admin) {
        try {
          const { data: profile } = await admin
            .from('profiles')
            .select('id')
            .or(`id.eq.${cleanParam},phone_e164.eq.${cleanParam}`)
            .maybeSingle();
          if (profile) user = { id: profile.id };
        } catch {}
      }
    }

    if (!user) {
      return NextResponse.json({ success: false, error: 'Authentication required to redeem meals.' }, { status: 401 });
    }

    if (!admin) {
      return NextResponse.json(
        {
          success: false,
          code: 'redemption_unavailable',
          error: 'Secure redemption is not enabled on the connected database. No meal credit was consumed.',
        },
        { status: 503 }
      );
    }

    // 3. Attempt atomic stored procedure execution
    let rpcRes = await admin.rpc('redeem_meal_atomic', {
      p_customer_id: user.id,
      p_provider_id: qrVerification.providerId,
      p_service_date: qrVerification.date,
      p_slot_name: (qrVerification.slot || 'lunch').toLowerCase(),
    });

    // If no active subscription found, check if student has a pending_payment pass/subscription that can be auto-activated
    if (rpcRes.data && rpcRes.data.success === false && rpcRes.data.code === 'NO_ACTIVE_SUBSCRIPTION') {
      try {
        const { data: pendingSub } = await admin
          .from('subscriptions')
          .select('id, plan_id, plan_type_snapshot')
          .eq('customer_id', user.id)
          .eq('provider_id', qrVerification.providerId)
          .eq('status', 'pending_payment')
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();

        if (pendingSub) {
          await admin
            .from('subscriptions')
            .update({ status: 'active', updated_at: new Date().toISOString() })
            .eq('id', pendingSub.id);

          // Retry atomic redemption with newly activated subscription
          rpcRes = await admin.rpc('redeem_meal_atomic', {
            p_customer_id: user.id,
            p_provider_id: qrVerification.providerId,
            p_service_date: qrVerification.date,
            p_slot_name: (qrVerification.slot || 'lunch').toLowerCase(),
          });
        }
      } catch (err) {
        console.warn('Pending subscription check failed:', err);
      }
    }

    const { data, error } = rpcRes;

    if (error) {
      // If RPC is missing on the database, fail closed safely
      if (error.code === '42883' || error.code === 'PGRST202') {
        return NextResponse.json(
          {
            success: false,
            code: 'redemption_unavailable',
            error: 'Secure redemption is not enabled on the connected database. No meal credit was consumed.',
          },
          { status: 503, headers: { 'Cache-Control': 'private, no-store' } }
        );
      }
      console.error('Atomic redemption RPC error:', error.message);
      return NextResponse.json({ success: false, error: 'Redemption check failed. No credit was deducted.' }, { status: 503 });
    }

    // 4. Handle RPC result
    if (data && typeof data === 'object') {
      if (data.success === false) {
        return NextResponse.json(
          {
            success: false,
            code: data.code || 'REDEMPTION_FAILED',
            error: data.error || 'Meal redemption could not be completed. No meal credit was deducted.',
          },
          { status: 400 }
        );
      }
      try {
        const slotUpper = (qrVerification.slot || 'lunch').toUpperCase();
        const serviceDateStr = String(qrVerification.date || new Date().toISOString().slice(0, 10));
        const { data: activeSub } = await admin
          .from('subscriptions')
          .select('id')
          .eq('customer_id', user.id)
          .eq('provider_id', qrVerification.providerId)
          .eq('status', 'active')
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();

        if (activeSub?.id) {
          await admin.from('daily_meal_events').upsert(
            {
              subscription_id: activeSub.id,
              customer_id: user.id,
              provider_id: qrVerification.providerId,
              service_date: serviceDateStr,
              slot: slotUpper,
              status: 'delivered',
              fulfillment_mode: 'pickup',
              updated_at: new Date().toISOString(),
            },
            { onConflict: 'subscription_id,service_date,slot' }
          );
        }
      } catch (_) {}
      try {
        if (qrVerification.providerId) {
          addPartnerNotification({
            provider_id: qrVerification.providerId,
            type: 'redemption',
            title: 'Meal Redeemed',
            message: `${user.email?.split('@')[0] || 'Student'} checked in at counter for ${(qrVerification.slot || 'lunch').toUpperCase()}`,
            customer_name: user.email?.split('@')[0] || 'Student',
          });
        }
      } catch (_) {}
      return NextResponse.json({ success: true, ...data }, { status: 200 });
    }

    return NextResponse.json(
      {
        success: false,
        code: 'redemption_unavailable',
        error: 'Secure redemption is not enabled on the connected database. No meal credit was consumed.',
      },
      { status: 503, headers: { 'Cache-Control': 'private, no-store' } }
    );
  } catch (err: any) {
    console.error('Redemption error:', err instanceof Error ? err.message : 'unknown');
    return NextResponse.json(
      { success: false, error: 'Authentication is unavailable. No credit was consumed.' },
      { status: 503 }
    );
  }
}
