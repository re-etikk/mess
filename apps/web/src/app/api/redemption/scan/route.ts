import { NextRequest, NextResponse } from 'next/server';
import { processMealRedemption } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const token = body.token || body.qr_token;
    const userId = body.user_id || body.customerId || 'cust-ritik-001';
    const extras = body.extras || [];

    if (!token) {
      return NextResponse.json(
        { success: false, error: 'QR token is required for meal redemption.' },
        { status: 400 }
      );
    }

    const result = processMealRedemption({
      userId,
      token,
      extras,
    });

    if (!result.success) {
      return NextResponse.json(result, { status: result.message.includes('already redeemed') ? 409 : 400 });
    }

    return NextResponse.json(result, { status: 200 });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Internal server error processing redemption' },
      { status: 500 }
    );
  }
}
