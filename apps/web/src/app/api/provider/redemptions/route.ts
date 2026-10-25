import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';
  const date = searchParams.get('date');

  let redemptions = Array.from(platformStore.redemptions.values()).filter(
    (r) => r.provider_id === providerId
  );

  if (date) {
    redemptions = redemptions.filter((r) => r.date === date);
  }

  redemptions.sort((a, b) => b.redeemed_at.localeCompare(a.redeemed_at));

  return NextResponse.json({
    success: true,
    total: redemptions.length,
    redemptions,
  });
}
