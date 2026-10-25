import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';

  const redemptions = Array.from(platformStore.redemptions.values()).filter(
    (r) => r.provider_id === providerId
  );

  const scanStats = platformStore.providerScanCounts.get(providerId) || { total: 0, unbilled: 0 };
  const invoices = Array.from(platformStore.invoices.values()).filter(
    (i) => i.provider_id === providerId
  );

  // Group by slot
  const slotCounts: Record<string, number> = { BREAKFAST: 0, LUNCH: 0, SNACKS: 0, DINNER: 0 };
  let extraRevenuePaise = 0;
  for (const r of redemptions) {
    if (slotCounts[r.slot] !== undefined) {
      slotCounts[r.slot] += 1;
    }
    extraRevenuePaise += r.amount_extra_paise;
  }

  return NextResponse.json({
    success: true,
    provider_id: providerId,
    total_redemptions: redemptions.length,
    scans_summary: {
      total: scanStats.total,
      unbilled: scanStats.unbilled,
      billed: scanStats.total - scanStats.unbilled,
    },
    by_slot: slotCounts,
    extra_items_revenue_inr: extraRevenuePaise / 100,
    invoices,
  });
}
