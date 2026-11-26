import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { getIndiaDateString } from '@/lib/crypto';
import { computeKitchenForecast } from '@/lib/ai-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id')?.trim() || '';
  const targetDate = params.get('date')?.trim() || getIndiaDateString();

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok && access.status !== 401) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  let subscriptions: any[] = [];
  let eventsToday: any[] = [];
  let redemptionsLast28Days: any[] = [];
  let supportsDelivery = false;
  let avgMealPriceInr = 80;

  if (admin) {
    try {
      const sinceIso = new Date(Date.now() - 28 * 86400000).toISOString();
      const [provRes, subsRes, evRes, redRes, menuPriceRes] = await Promise.all([
        admin.from('providers').select('supports_delivery').eq('id', providerId).maybeSingle(),
        admin
          .from('subscriptions')
          .select('*, profiles:customer_id(id,display_name,phone_e164)')
          .eq('provider_id', providerId)
          .eq('status', 'active'),
        admin
          .from('daily_meal_events')
          .select('*')
          .eq('provider_id', providerId)
          .eq('service_date', targetDate)
          .then((r) => r, () => ({ data: [] as any[] })),
        admin
          .from('meal_redemptions')
          .select('id,customer_id,redeemed_at,meal_bookings(service_date,meal_slots(name))')
          .eq('provider_id', providerId)
          .gte('redeemed_at', sinceIso)
          .then((r) => r, () => ({ data: [] as any[] })),
        admin
          .from('menu_items')
          .select('price_paise')
          .eq('provider_id', providerId)
          .eq('active', true)
          .eq('is_add_on', false)
          .gt('price_paise', 0)
          .limit(10)
          .then((r) => r, () => ({ data: [] as any[] })),
      ]);

      supportsDelivery = provRes?.data?.supports_delivery === true;
      subscriptions = subsRes.data ?? [];
      eventsToday = (evRes as any)?.data ?? [];
      redemptionsLast28Days = (redRes as any)?.data ?? [];

      const prices = ((menuPriceRes as any)?.data ?? []).map((x: any) => Number(x.price_paise || 0) / 100).filter((n: number) => n > 0);
      if (prices.length > 0) {
        avgMealPriceInr = Math.round(prices.reduce((a: number, b: number) => a + b, 0) / prices.length);
      }
    } catch (e: any) {
      console.warn('ai/kitchen-forecast error:', e?.message);
    }
  }

  if (subscriptions.length === 0) {
    for (const s of platformStore.subscriptions.values()) {
      if (s.provider_id === providerId && s.status === 'active') subscriptions.push(s);
    }
    for (const ev of platformStore.dailyMealEvents.values()) {
      if (ev.provider_id === providerId && ev.service_date === targetDate) eventsToday.push(ev);
    }
    for (const r of platformStore.redemptions.values()) {
      if (r.provider_id === providerId) redemptionsLast28Days.push(r);
    }
  }

  const forecast = computeKitchenForecast({
    subscriptions,
    eventsToday,
    redemptionsLast28Days,
    targetDateStr: targetDate,
    supportsDelivery,
    avgMealPriceInr,
  });

  return NextResponse.json(
    {
      success: true,
      supports_delivery: supportsDelivery,
      ...forecast,
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}
