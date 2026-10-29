import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id');
  const date = searchParams.get('date');

  if (!providerId) {
    return NextResponse.json({
      success: true,
      total: 0,
      redemptions: [],
    });
  }

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
