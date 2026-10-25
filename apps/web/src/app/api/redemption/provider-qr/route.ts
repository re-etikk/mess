import { NextRequest, NextResponse } from 'next/server';
import { generateProviderDailyQR } from '@/lib/platform-service';

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

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = body.provider_id || body.providerId || 'prov-radhe-001';
  const slot = body.slot;

  const qrData = generateProviderDailyQR({
    providerId,
    slot,
  });

  return NextResponse.json({
    success: true,
    ...qrData,
  });
}
