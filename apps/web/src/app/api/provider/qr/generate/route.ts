import { NextRequest, NextResponse } from 'next/server';
import { generateProviderDailyQR } from '@/lib/platform-service';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || body.providerId || 'prov-radhe-001';
    const slot = body.slot;
    const date = body.date;

    const qrData = generateProviderDailyQR({
      providerId,
      slot,
      date,
    });

    return NextResponse.json({
      success: true,
      ...qrData,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to generate QR token' },
      { status: 500 }
    );
  }
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';
  const slot = searchParams.get('slot') || undefined;

  const qrData = generateProviderDailyQR({
    providerId,
    slot,
  });

  return NextResponse.json({
    success: true,
    ...qrData,
  });
}
