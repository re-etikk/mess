import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const subscriberOrUserId = params.id;
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id');

  // Find subscription by ID or customer ID
  let sub = platformStore.subscriptions.get(subscriberOrUserId);
  if (!sub) {
    sub = Array.from(platformStore.subscriptions.values()).find(
      (s) => s.customer_id === subscriberOrUserId || s.customer_phone === subscriberOrUserId
    );
  }

  const customerId = sub?.customer_id || subscriberOrUserId;

  let redemptions = Array.from(platformStore.redemptions.values()).filter(
    (r) => r.user_id === customerId || r.subscription_id === subscriberOrUserId
  );

  if (providerId) {
    redemptions = redemptions.filter((r) => r.provider_id === providerId);
  }

  // Sort descending by redeemed_at
  redemptions.sort((a, b) => new Date(b.redeemed_at).getTime() - new Date(a.redeemed_at).getTime());

  return NextResponse.json({
    success: true,
    subscription: sub || null,
    total_scans: redemptions.length,
    redemptions: redemptions.map((r) => ({
      id: r.id,
      date: r.date,
      time: r.time_formatted || new Date(r.redeemed_at).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true }),
      slot: r.slot,
      plan_name: r.plan_name || sub?.plan_name || 'Active Plan',
      remaining_credits: r.remaining_credits !== undefined ? r.remaining_credits : sub?.remaining_meal_credits,
      amount_extra: r.amount_extra_paise / 100,
      extra_items: r.extra_items,
      redeemed_at: r.redeemed_at,
    })),
  });
}
