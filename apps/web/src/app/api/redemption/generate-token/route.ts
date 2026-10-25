import { NextRequest, NextResponse } from 'next/server';
import { generateSignedQRToken, getIndiaDateString } from '@/lib/crypto';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const bookingId = body.booking_id || `book-${Date.now()}`;
    const customerId = body.customer_id || 'cust-ritik-001';
    const providerId = body.provider_id || 'prov-radhe-001';
    const mealSlotId = body.meal_slot_id || 'slot-lunch';
    const bookingDate = body.booking_date || getIndiaDateString();

    const signedToken = generateSignedQRToken({
      bookingId,
      customerId,
      providerId,
      mealSlotId,
      bookingDate,
    });

    return NextResponse.json({
      success: true,
      token: signedToken.encodedString,
      expires_at: signedToken.payload.expires_at,
      token_hash: signedToken.tokenHash,
    });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err.message }, { status: 500 });
  }
}
