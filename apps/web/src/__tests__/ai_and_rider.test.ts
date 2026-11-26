import { describe, expect, it, beforeEach } from 'vitest';
import { NextRequest } from 'next/server';
import { platformStore } from '../lib/platform-service';
import {
  computeKitchenForecast,
  heuristicParseMenu,
  heuristicSmartSearch,
  recommendBestPlan,
} from '../lib/ai-service';
import { POST as ridersPost, GET as ridersGet } from '../app/api/delivery/riders/route';
import { GET as riderOrdersGet, POST as riderOrdersPost } from '../app/api/rider/orders/route';

describe('Phase 1 AI/ML Engine & Mess Rider Workflows', () => {
  const providerId = 'prov-test-ai-001';
  const customerId = 'cust-test-ai-001';
  const subId = 'sub-test-ai-001';

  beforeEach(() => {
    platformStore.providerRiders.clear();
    platformStore.dailyMealEvents.clear();
    platformStore.subscriptions.clear();
    platformStore.providers.set(providerId, {
      id: providerId,
      owner_user_id: 'owner-1',
      display_name: 'Annapurna Kitchen',
      slug: 'annapurna-test',
      description: 'Home tiffin',
      phone: '9876543210',
      email: 'a@b.com',
      address: 'Street 1',
      locality: 'Koramangala',
      city: 'Bengaluru',
      rating: 4.7,
      total_reviews: 20,
      cuisines: ['Home'],
      dietary_types: ['veg'],
      status: 'active',
      created_at: new Date().toISOString(),
    });
    platformStore.subscriptions.set(subId, {
      id: subId,
      customer_id: customerId,
      customer_name: 'Riya Verma',
      customer_phone: '9123456789',
      provider_id: providerId,
      plan_id: 'plan-1',
      plan_type: 'fixed_period',
      plan_name: 'Monthly Plan',
      status: 'active',
      starts_at: new Date(Date.now() - 10 * 86400000).toISOString(),
      expires_at: new Date(Date.now() + 2 * 86400000).toISOString(),
      price_paid_paise: 300000,
      fulfillment_mode: 'delivery',
      delivery_address: 'Room 204, Elite PG, Koramangala',
      created_at: new Date().toISOString(),
    });
  });

  it('computes accurate kitchen plate forecast & renewal churn alerts', () => {
    const res = computeKitchenForecast({
      subscriptions: [platformStore.subscriptions.get(subId)!],
      eventsToday: [
        { subscription_id: subId, slot: 'BREAKFAST', status: 'skipped' },
      ],
      redemptionsLast28Days: [],
      targetDateStr: '2026-11-26',
      supportsDelivery: true,
      avgMealPriceInr: 90,
    });

    const bf = res.slots.find((s) => s.slot === 'BREAKFAST')!;
    const lunch = res.slots.find((s) => s.slot === 'LUNCH')!;
    expect(bf.skipped_today).toBe(1);
    expect(bf.recommended_plates).toBe(0);
    expect(bf.estimated_waste_saved_inr).toBe(90);
    expect(lunch.delivery_count).toBe(1);
    expect(lunch.recommended_plates).toBe(1);
    expect(res.churn_alerts.length).toBe(1);
    expect(res.churn_alerts[0].customer_name).toBe('Riya Verma');
  });

  it('recommends lowest effective per-meal cost plan dynamically', () => {
    const rec = recommendBestPlan({
      plans: [
        { id: 'p-fixed', name: 'Monthly Unlimited', plan_type: 'fixed_period', duration_days: 30, price_inr: 3400 },
        { id: 'p-credits', name: '40 Meal Tracker', plan_type: 'meal_credits', duration_days: 30, price_inr: 2400, meal_credits: 40 },
      ],
      weeklyDays: 5,
      weeklySkips: 2,
      mealsPerDay: 2,
    });
    expect(rec.recommended_plan_id).toBe('p-credits');
    expect(rec.savings_inr).toBeGreaterThan(0);
  });

  it('parses Hinglish menu lines and natural-language search queries deterministically', () => {
    const parsedMenu = heuristicParseMenu('Rajma Chawal, 4 Roti, Boondi Raita, Extra Gulab Jamun 25rs');
    expect(parsedMenu.included).toContain('Rajma Chawal');
    expect(parsedMenu.extras[0]?.name).toContain('Gulab Jamun');
    expect(parsedMenu.extras[0]?.price).toBe(25);

    const parsedQuery = heuristicSmartSearch('pure veg lunch under 3000 home delivery koramangala');
    expect(parsedQuery.dietary).toBe('veg');
    expect(parsedQuery.slot).toBe('lunch');
    expect(parsedQuery.max_monthly_inr).toBe(3000);
    expect(parsedQuery.delivery_only).toBe(true);
    expect(parsedQuery.keywords.toLowerCase()).toContain('koramangala');
  });

  it('creates mess-linked delivery rider and filters delivery-only orders for /rider/portal', async () => {
    process.env.ADMIN_SECRET_KEY = 'test-admin-secret';
    const postReq = new NextRequest('https://www.thali.store/api/delivery/riders', {
      method: 'POST',
      headers: { Authorization: 'Bearer test-admin-secret' },
      body: JSON.stringify({
        provider_id: providerId,
        name: 'Ramesh Rider',
        phone: '9988776655',
        pin_code: '4321',
      }),
    });
    const postRes = await (await ridersPost(postReq)).json();
    expect(postRes.success).toBe(true);
    expect(postRes.rider.pin_code).toBe('4321');
    expect(postRes.rider.whatsapp_url).toContain('https://wa.me/919988776655');

    const getRiders = await (
      await ridersGet(
        new NextRequest(`https://www.thali.store/api/delivery/riders?provider_id=${providerId}`, {
          headers: { Authorization: 'Bearer test-admin-secret' },
        })
      )
    ).json();
    expect(getRiders.riders.length).toBe(1);

    const { POST: riderOrdersPost } = await import('../app/api/rider/orders/route');
    const loginRes = await (
      await riderOrdersPost(
        new NextRequest('https://www.thali.store/api/rider/orders', {
          method: 'POST',
          body: JSON.stringify({ action: 'login', phone: '9988776655', pin: '4321' }),
        })
      )
    ).json();
    expect(loginRes.success).toBe(true);
    expect(loginRes.rider_token).toMatch(/^thali_rider_/);

    const ordersRes = await (
      await riderOrdersGet(
        new NextRequest('https://www.thali.store/api/rider/orders?slot=LUNCH', {
          headers: { Authorization: `Bearer ${loginRes.rider_token}` },
        })
      )
    ).json();
    expect(ordersRes.success).toBe(true);
    expect(ordersRes.orders.length).toBe(1);
    expect(ordersRes.orders[0].customer_name).toBe('Riya Verma');
  });
});
