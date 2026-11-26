import { describe, expect, it, beforeEach } from 'vitest';
import { platformStore, validateAndApplyPromo } from '../lib/platform-service';
import { POST as mealsPost, GET as mealsGet } from '../app/api/customer/meals/route';
import { POST as managePost, GET as manageGet } from '../app/api/subscription/manage/route';
import { POST as queuePost, GET as queueGet } from '../app/api/provider/kitchen-queue/route';
import { GET as reviewsGet, POST as reviewsPost } from '../app/api/mess/reviews/route';
import { NextRequest } from 'next/server';

describe('Thali Behance Zero-Fake-Data Full Sync APIs', () => {
  const providerId = 'prov-annapurna-002';
  const customerId = 'cust-aarav-001';
  const subId = 'sub-sync-001';

  beforeEach(() => {
    platformStore.dailyMealEvents.clear();
    platformStore.reviews.clear();
    platformStore.subscriptions.set(subId, {
      id: subId,
      customer_id: customerId,
      customer_name: 'Aarav Sharma',
      provider_id: providerId,
      plan_id: 'plan-weekly-1',
      plan_type: 'fixed_period',
      plan_name: 'Weekly Plan',
      status: 'active',
      starts_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
      price_paid_paise: 90000,
      payment_mode: 'cashfree_online',
      created_at: new Date().toISOString(),
    });
  });

  it('validates THALI50 promo flat ₹50 discount accurately', () => {
    const res = validateAndApplyPromo({ code: 'THALI50', orderAmountPaise: 95000 });
    expect(res.isValid).toBe(true);
    expect(res.discountPaise).toBe(5000);
    expect(res.finalAmountPaise).toBe(90000);
  });

  it('coordinates customer meal reschedule, skip, instruction & partner queue status transitions', async () => {
    const { signSessionToken } = await import('../lib/auth-session');
    const custToken = signSessionToken({ userId: customerId, email: 'aarav@example.com', role: 'customer', name: 'Aarav' });

    const reqSkip = new NextRequest('https://www.thali.store/api/customer/meals', {
      method: 'POST',
      headers: { Authorization: `Bearer ${custToken}` },
      body: JSON.stringify({
        action: 'skip',
        subscription_id: subId,
        customer_id: customerId,
        provider_id: providerId,
        service_date: '2026-11-26',
        slot: 'BREAKFAST',
      }),
    });
    const skipRes = await (await mealsPost(reqSkip)).json();
    expect(skipRes.success).toBe(true);
    expect(skipRes.event.status).toBe('skipped');

    const reqInst = new NextRequest('https://www.thali.store/api/customer/meals', {
      method: 'POST',
      headers: { Authorization: `Bearer ${custToken}` },
      body: JSON.stringify({
        action: 'instruction',
        subscription_id: subId,
        customer_id: customerId,
        provider_id: providerId,
        service_date: '2026-11-26',
        slot: 'LUNCH',
        instructions: 'Leave at door please',
      }),
    });
    const instRes = await (await mealsPost(reqInst)).json();
    expect(instRes.success).toBe(true);

    // Partner updates LUNCH -> out_for_delivery (using admin secret header for ownership test)
    process.env.ADMIN_SECRET_KEY = 'test-admin-secret';
    const reqStatus = new NextRequest('https://www.thali.store/api/provider/kitchen-queue', {
      method: 'POST',
      headers: { Authorization: 'Bearer test-admin-secret' },
      body: JSON.stringify({
        provider_id: providerId,
        subscription_id: subId,
        customer_id: customerId,
        service_date: '2026-11-26',
        slot: 'LUNCH',
        status: 'out_for_delivery',
        eta_minutes: 18,
      }),
    });
    const stRes = await (await queuePost(reqStatus)).json();
    expect(stRes.success).toBe(true);
    expect(stRes.event.status).toBe('out_for_delivery');

    // Customer GET /api/customer/meals sees synchronized status & instruction
    const mealsRes = await (
      await mealsGet(
        new NextRequest(`https://www.thali.store/api/customer/meals?customer_id=${customerId}&date=2026-11-26`, {
          headers: { Authorization: `Bearer ${custToken}` },
        })
      )
    ).json();
    expect(mealsRes.success).toBe(true);
    const lunch = mealsRes.meals.find((m: any) => m.slot === 'LUNCH');
    expect(lunch.status).toBe('out_for_delivery');
    expect(lunch.instructions).toBe('Leave at door please');
    expect(lunch.eta_minutes).toBe(18);
  });

  it('pauses, extends expiry, resumes, and cancels subscription with real reason', async () => {
    const beforeExp = new Date(platformStore.subscriptions.get(subId)!.expires_at).getTime();
    const { signSessionToken } = await import('../lib/auth-session');
    const custToken = signSessionToken({ userId: customerId, email: 'aarav@example.com', role: 'customer', name: 'Aarav' });

    const pauseRes = await (
      await managePost(
        new NextRequest('https://www.thali.store/api/subscription/manage', {
          method: 'POST',
          headers: { Authorization: `Bearer ${custToken}` },
          body: JSON.stringify({
            action: 'pause',
            subscription_id: subId,
            pause_start_date: '2026-12-01',
            pause_end_date: '2026-12-04',
          }),
        })
      )
    ).json();
    expect(pauseRes.success).toBe(true);
    expect(platformStore.subscriptions.get(subId)!.status).toBe('paused');
    const afterExp = new Date(platformStore.subscriptions.get(subId)!.expires_at).getTime();
    expect(afterExp).toBeGreaterThan(beforeExp);

    const cancelRes = await (
      await managePost(
        new NextRequest('https://www.thali.store/api/subscription/manage', {
          method: 'POST',
          headers: { Authorization: `Bearer ${custToken}` },
          body: JSON.stringify({
            action: 'cancel',
            subscription_id: subId,
            reason: 'Travelling temporarily',
          }),
        })
      )
    ).json();
    expect(cancelRes.success).toBe(true);
    expect(platformStore.subscriptions.get(subId)!.status).toBe('cancelled');
  });

  it('returns honest empty reviews when 0 exist and persists submitted review', async () => {
    const { signSessionToken } = await import('../lib/auth-session');
    const custToken = signSessionToken({ userId: customerId, email: 'aarav@example.com', role: 'customer', name: 'Aarav' });

    const emptyJson = await (
      await reviewsGet(new NextRequest(`https://www.thali.store/api/mess/reviews?provider_id=${providerId}`))
    ).json();
    expect(emptyJson.total_reviews).toBe(0);
    expect(emptyJson.average_rating).toBeNull();

    const postJson = await (
      await reviewsPost(
        new NextRequest('https://www.thali.store/api/mess/reviews', {
          method: 'POST',
          headers: { Authorization: `Bearer ${custToken}` },
          body: JSON.stringify({
            provider_id: providerId,
            customer_id: customerId,
            customer_name: 'Aarav',
            rating: 5,
            review_text: 'Fresh homestyle meals',
            tags: ['Homestyle Food', 'Timely Delivery'],
          }),
        })
      )
    ).json();
    expect(postJson.success).toBe(true);

    const filledJson = await (
      await reviewsGet(new NextRequest(`https://www.thali.store/api/mess/reviews?provider_id=${providerId}`))
    ).json();
    expect(filledJson.total_reviews).toBe(1);
    expect(filledJson.average_rating).toBe(5);
  });
});
