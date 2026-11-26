import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { verifyCounterQRToken } from '@/lib/crypto';
import { addPartnerNotification } from '@/lib/partner-notifications';
import { ensurePlanSlotsLinked, requireCustomerIdentity } from '@/lib/auth-session';
import { checkRateLimit } from '@/lib/rate-limiter';

/**
 * Executes atomic QR redemption via Postgres RPC `redeem_meal_atomic`.
 * Strictly requires verified customer (or admin) authentication, NEVER auto-activates
 * unpaid `pending_payment` passes, and returns slot + kitchen metadata cleanly.
 */
export async function rejectUnimplementedRedemption(
  req: NextRequest,
  token?: string,
  customerIdParam?: string
) {
  if (!token) {
    return NextResponse.json({ success: false, error: 'QR token is required.' }, { status: 400 });
  }

  // 1. Verify token cryptographic integrity and date/window validity
  const qrVerification = verifyCounterQRToken(token);
  if (!qrVerification.isValid || !qrVerification.providerId) {
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
    // 2. Cryptographically authenticate caller & bind customer identity
    const auth = await requireCustomerIdentity(req, customerIdParam);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }

    const rl = checkRateLimit(`scan:${auth.userId}`, 15, 60 * 1000);
    if (!rl.isAllowed) {
      return NextResponse.json(
        { success: false, error: 'Too many scan attempts. Please wait a minute.' },
        { status: 429 }
      );
    }

    const admin = getAdminClient();
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

    const slotLower = (qrVerification.slot || 'lunch').toLowerCase();
    const slotUpper = slotLower.toUpperCase();
    const serviceDateStr = String(qrVerification.date || new Date().toISOString().slice(0, 10));

    // Ensure slot exists and is linked to active provider plans before RPC executes
    await ensurePlanSlotsLinked(admin, qrVerification.providerId);

    // 3. Execute atomic stored procedure ONLY for verified active/paid subscriptions
    const { data, error } = await admin.rpc('redeem_meal_atomic', {
      p_customer_id: auth.userId,
      p_provider_id: qrVerification.providerId,
      p_service_date: serviceDateStr,
      p_slot_name: slotLower,
    });

    if (error) {
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

      let providerName = 'Mess Counter';
      try {
        const [{ data: provRow }, { data: activeSub }] = await Promise.all([
          admin.from('providers').select('display_name').eq('id', qrVerification.providerId).maybeSingle(),
          admin
            .from('subscriptions')
            .select('id')
            .eq('customer_id', auth.userId)
            .eq('provider_id', qrVerification.providerId)
            .eq('status', 'active')
            .order('created_at', { ascending: false })
            .limit(1)
            .maybeSingle(),
        ]);

        if (provRow?.display_name) providerName = provRow.display_name;

        if (activeSub?.id) {
          await admin.from('daily_meal_events').upsert(
            {
              subscription_id: activeSub.id,
              customer_id: auth.userId,
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
      } catch {}

      try {
        addPartnerNotification({
          provider_id: qrVerification.providerId,
          type: 'redemption',
          title: 'Meal Redeemed',
          message: `${auth.email?.split('@')[0] || 'Subscriber'} checked in at counter for ${slotUpper}`,
          customer_name: auth.email?.split('@')[0] || 'Subscriber',
        });
      } catch {}

      return NextResponse.json(
        {
          success: true,
          ...data,
          slot: slotUpper,
          provider_name: providerName,
          provider_id: qrVerification.providerId,
        },
        { status: 200 }
      );
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
