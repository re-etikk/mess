import { NextRequest, NextResponse } from 'next/server';
import { platformStore, getCurrentMealSlot, generateProviderDailyQR } from '@/lib/platform-service';
import { getIndiaDateString } from '@/lib/crypto';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';

  const provider = platformStore.providers.get(providerId);
  const currentSlot = getCurrentMealSlot();
  const today = getIndiaDateString();

  const scanStats = platformStore.providerScanCounts.get(providerId) || { total: 0, unbilled: 0 };

  const todayRedemptions = Array.from(platformStore.redemptions.values()).filter(
    (r) => r.provider_id === providerId && r.date === today
  );

  const activePlans = Array.from(platformStore.plans.values()).filter(
    (p) => p.provider_id === providerId && p.is_active
  );

  const activeSubscribers = Array.from(platformStore.subscriptions.values()).filter(
    (s) => s.provider_id === providerId && s.status === 'active'
  );

  const qrData = generateProviderDailyQR({
    providerId,
    slot: currentSlot,
  });

  return NextResponse.json({
    success: true,
    provider: provider || null,
    today_date: today,
    current_slot: currentSlot,
    qr_token: qrData.token,
    metrics: {
      today_scans_count: todayRedemptions.length,
      total_scans: scanStats.total,
      unbilled_scans: scanStats.unbilled,
      active_subscribers: activeSubscribers.length,
      active_plans_count: activePlans.length,
    },
    today_redemptions: todayRedemptions.slice(0, 15),
  });
}
