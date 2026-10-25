import { NextRequest, NextResponse } from 'next/server';
import { platformStore, getCurrentMealSlot } from '@/lib/platform-service';
import { getIndiaDateString } from '@/lib/crypto';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const customerId = searchParams.get('customer_id') || 'cust-ritik-001';

  // Find active subscription
  const activeSub = Array.from(platformStore.subscriptions.values()).find(
    (s) => s.customer_id === customerId && s.status === 'active'
  );

  const providerId = activeSub ? activeSub.provider_id : 'prov-radhe-001';
  const provider = platformStore.providers.get(providerId);

  // Today's menu for current slot
  const currentSlot = getCurrentMealSlot();
  const menuKey = `${providerId}_Daily_${currentSlot}`;
  const menu = platformStore.menus.get(menuKey) || Array.from(platformStore.menus.values()).find((m) => m.provider_id === providerId);

  // Customer redemptions
  const redemptions = Array.from(platformStore.redemptions.values())
    .filter((r) => r.user_id === customerId)
    .sort((a, b) => b.redeemed_at.localeCompare(a.redeemed_at))
    .slice(0, 10);

  return NextResponse.json({
    success: true,
    today_date: getIndiaDateString(),
    current_slot: currentSlot,
    active_subscription: activeSub || null,
    provider: provider || null,
    todays_menu: menu ? {
      slot: menu.slot,
      items_included: menu.items_included,
      items_extra: menu.items_extra,
    } : null,
    recent_redemptions: redemptions,
  });
}
