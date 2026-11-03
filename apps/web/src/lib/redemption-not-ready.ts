import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { verifyCounterQRToken } from '@/lib/crypto';

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
    let user: { id: string } | null = null;
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
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (isUuid.test(customerIdParam.trim())) {
        user = { id: customerIdParam.trim() };
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
    const { data, error } = await admin.rpc('redeem_meal_atomic', {
      p_customer_id: user.id,
      p_provider_id: qrVerification.providerId,
      p_service_date: qrVerification.date,
      p_slot_name: (qrVerification.slot || 'lunch').toLowerCase(),
    });

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
