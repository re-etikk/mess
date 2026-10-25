import { NextRequest, NextResponse } from 'next/server';
import { validateAndApplyPromo } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const code = body.code || '';
    const orderAmountPaise = Number(body.order_amount_paise) || Number(body.amount_paise) || 120000;

    if (!code) {
      return NextResponse.json(
        { isValid: false, message: 'Promo code is required.' },
        { status: 400 }
      );
    }

    const result = validateAndApplyPromo({
      code,
      orderAmountPaise,
    });

    return NextResponse.json(result);
  } catch (err: any) {
    return NextResponse.json(
      { isValid: false, message: err.message || 'Validation failed' },
      { status: 500 }
    );
  }
}
