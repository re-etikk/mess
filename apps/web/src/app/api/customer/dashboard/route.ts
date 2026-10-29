import { NextRequest, NextResponse } from 'next/server';
import { platformStore, getCurrentMealSlot } from '@/lib/platform-service';
import { getIndiaDateString } from '@/lib/crypto';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const customerId = searchParams.get('customer_id');
  const currentSlot = getCurrentMealSlot();

  if (!customerId) {
    return NextResponse.json({
      success: true,
      today_date: getIndiaDateString(),
      current_slot: currentSlot,
      active_subscription: null,
      provider: null,
      todays_menu: null,
      recent_redemptions: [],
    });
  }

  // Find genuine active subscription
  const activeSub = Array.from(platformStore.subscriptions.values()).find(
    (s) => s.customer_id === customerId && s.status === 'active'
  );

  const provider = activeSub ? platformStore.providers.get(activeSub.provider_id) : null;

  // Today's menu for current slot if subscribed
  let menu = null;
  if (provider && activeSub) {
    const menuKey = `${activeSub.provider_id}_Daily_${currentSlot}`;
    menu = platformStore.menus.get(menuKey) || Array.from(platformStore.menus.values()).find((m) => m.provider_id === activeSub.provider_id);
  }

  // Genuine customer redemptions
  const redemptions = Array.from(platformStore.redemptions.values())
    .filter((r) => r.user_id === customerId)
    .sort((a, b) => b.redeemed_at.localeCompare(a.redeemed_at))
    .slice(0, 15);

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
