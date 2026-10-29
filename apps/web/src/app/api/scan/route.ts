import { NextRequest, NextResponse } from 'next/server';
import { processMealRedemption } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const token = body.token || body.qr_token;
    const userId = body.user_id || body.customerId;
    const extras = body.extras || [];

    if (!token) {
      return NextResponse.json(
        { success: false, error: 'QR token is required for meal redemption.' },
        { status: 400 }
      );
    }

    if (!userId) {
      return NextResponse.json(
        { success: false, error: 'Sign in is required. User ID is needed to check meal subscription entitlement.' },
        { status: 401 }
      );
    }

    const result = processMealRedemption({
      userId,
      token,
      extras,
    });

    if (!result.success) {
      const isDuplicate = result.message.toLowerCase().includes('already redeemed');
      return NextResponse.json(result, { status: isDuplicate ? 409 : 400 });
    }

    return NextResponse.json(result, { status: 200 });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Internal server error processing redemption' },
      { status: 500 }
    );
  }
}
