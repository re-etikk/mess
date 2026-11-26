import { describe, it, expect, beforeEach } from 'vitest';
import { NextRequest } from 'next/server';
import {
  signSessionToken,
  signRiderToken,
  verifySignedSessionToken,
  escapeHtml,
  sanitizePostgrestSearch,
  isAllowedMediaUrl,
} from '../lib/auth-session';
import { platformStore } from '../lib/platform-service';
import { GET as customerDashboardGet } from '../app/api/customer/dashboard/route';
import { POST as providerPlansPost } from '../app/api/provider/plans/route';
import { POST as providerMenuPost } from '../app/api/provider/menu/route';
import {
  GET as providerPaymentGet,
  POST as providerPaymentPost,
} from '../app/api/provider/payment-settings/route';
import { POST as providerStatusPost } from '../app/api/provider/status/route';
import { GET as providerQueueGet } from '../app/api/provider/kitchen-queue/route';
import { POST as providerApprovePost } from '../app/api/provider/subscriptions/approve/route';
import { GET as providerNotifGet } from '../app/api/provider/notifications/route';
import { GET as kitchenForecastGet } from '../app/api/ai/kitchen-forecast/route';
import { POST as loginPost } from '../app/api/auth/login/route';
import { POST as subscribePost } from '../app/api/subscription/subscribe/route';
import { GET as riderOrdersGet } from '../app/api/rider/orders/route';
import { GET as deliveryRidersGet } from '../app/api/delivery/riders/route';
import { POST as cronPost } from '../app/api/billing/cron/route';

describe('Security Hardening & Vulnerability Regression Suite', () => {
  beforeEach(() => {
    process.env.SESSION_SIGNING_SECRET = 'test-only-thali-session-secret-0001';
  });

  it('rejects unsigned jwt_session_* and tampered HMAC tokens', () => {
    expect(verifySignedSessionToken('jwt_session_eyJ1c2VySWQiOiJhdHRhY2tlciIsInJvbGUiOiJwcm92aWRlciJ9')).toBeNull();
    expect(verifySignedSessionToken('jwt_mock_abc')).toBeNull();

    const valid = signSessionToken({
      userId: 'cust-1',
      email: 'cust1@example.com',
      role: 'customer',
      name: 'Customer One',
    });
    expect(verifySignedSessionToken(valid, 'thali_tok_')?.userId).toBe('cust-1');

    const tampered = `${valid.slice(0, -1)}${valid.endsWith('a') ? 'b' : 'a'}`;
    expect(verifySignedSessionToken(tampered, 'thali_tok_')).toBeNull();
  });

  it('blocks unauthenticated and cross-customer dashboard reads (IDOR)', async () => {
    const unauth = await customerDashboardGet(
      new NextRequest('https://www.thali.store/api/customer/dashboard?customer_id=cust-a')
    );
    expect(unauth.status).toBe(401);

    const tokenB = signSessionToken({ userId: 'cust-b', email: 'b@example.com', role: 'customer' });
    const crossCust = await customerDashboardGet(
      new NextRequest('https://www.thali.store/api/customer/dashboard?customer_id=cust-a', {
        headers: { Authorization: `Bearer ${tokenB}` },
      })
    );
    expect(crossCust.status).toBe(403);
  });

  it('rejects unauthenticated requests on all partner API routes (no 401 bypass)', async () => {
    const reqs = await Promise.all([
      providerPlansPost(
        new NextRequest('https://www.thali.store/api/provider/plans', {
          method: 'POST',
          body: JSON.stringify({ provider_id: 'prov-sec-1', name: 'Test Plan', price_inr: 2500 }),
        })
      ),
      providerMenuPost(
        new NextRequest('https://www.thali.store/api/provider/menu', {
          method: 'POST',
          body: JSON.stringify({ provider_id: 'prov-sec-1', action: 'add_item', name: 'Dal' }),
        })
      ),
      providerPaymentGet(
        new NextRequest('https://www.thali.store/api/provider/payment-settings?provider_id=prov-sec-1')
      ),
      providerPaymentPost(
        new NextRequest('https://www.thali.store/api/provider/payment-settings', {
          method: 'POST',
          body: JSON.stringify({ provider_id: 'prov-sec-1', upi_id: 'hack@upi' }),
        })
      ),
      providerStatusPost(
        new NextRequest('https://www.thali.store/api/provider/status', {
          method: 'POST',
          body: JSON.stringify({ provider_id: 'prov-sec-1', is_open: false }),
        })
      ),
      providerQueueGet(
        new NextRequest('https://www.thali.store/api/provider/kitchen-queue?provider_id=prov-sec-1')
      ),
      providerApprovePost(
        new NextRequest('https://www.thali.store/api/provider/subscriptions/approve', {
          method: 'POST',
          body: JSON.stringify({ provider_id: 'prov-sec-1', subscription_id: 'sub-1' }),
        })
      ),
      providerNotifGet(
        new NextRequest('https://www.thali.store/api/provider/notifications?provider_id=prov-sec-1')
      ),
      kitchenForecastGet(
        new NextRequest('https://www.thali.store/api/ai/kitchen-forecast?provider_id=prov-sec-1')
      ),
    ]);

    for (const res of reqs) {
      expect(res.status).toBe(401);
    }
  });

  it('rejects hardcoded backdoor passwords on /api/auth/login', async () => {
    for (const pw of ['MessOwner@2026', 'admin123', 'admin@123', 'Ritik@2026']) {
      const res = await loginPost(
        new NextRequest('https://www.thali.store/api/auth/login', {
          method: 'POST',
          body: JSON.stringify({ email: 'owner@mess.in', password: pw }),
        })
      );
      expect(res.status).toBeGreaterThanOrEqual(400);
    }
  });

  it('ignores client-tampered amount_paise during subscription creation', async () => {
    const provId = `prov-price-${Date.now()}`;
    const planId = `plan-price-${Date.now()}`;
    const custId = `cust-price-${Date.now()}`;
    platformStore.plans.set(planId, {
      id: planId,
      provider_id: provId,
      name: 'Standard Monthly',
      description: 'Monthly plan',
      plan_type: 'fixed_period',
      duration_days: 30,
      price_paise: 300000,
      currency: 'INR',
      daily_meal_limit: 1,
      is_active: true,
      created_at: new Date().toISOString(),
    });

    const token = signSessionToken({ userId: custId, email: 'custprice@example.com', role: 'customer', name: 'Buyer' });
    const res = await subscribePost(
      new NextRequest('https://www.thali.store/api/subscription/subscribe', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        body: JSON.stringify({
          provider_id: provId,
          plan_id: planId,
          customer_id: custId,
          payment_mode: 'counter_cash',
          amount_paise: 100,
        }),
      })
    );
    const data = await res.json();
    expect(res.status).toBe(200);
    expect(data.subscription.price_paise).toBe(300000);
    expect(platformStore.subscriptions.get(data.subscription.id)?.price_paid_paise).toBe(300000);
  });

  it('enforces rider session auth & prevents PIN leaks on /api/delivery/riders', async () => {
    const unauthOrders = await riderOrdersGet(
      new NextRequest('https://www.thali.store/api/rider/orders?slot=LUNCH')
    );
    expect(unauthOrders.status).toBe(401);

    const unauthRiders = await deliveryRidersGet(
      new NextRequest('https://www.thali.store/api/delivery/riders?provider_id=prov-1')
    );
    expect(unauthRiders.status).toBe(401);

    const riderTok = signRiderToken({
      riderId: 'rider-1',
      providerId: 'prov-kitchen-a',
      phone: '9876543210',
      name: 'Ramesh',
    });
    const payload = verifySignedSessionToken(riderTok, 'thali_rider_');
    expect(payload?.providerId).toBe('prov-kitchen-a');
  });

  it('blocks cron trigger without CRON_SECRET and sanitizes HTML, media URLs, and PostgREST filters', async () => {
    const cronRes = await cronPost(
      new NextRequest('https://www.thali.store/api/billing/cron', { method: 'POST' })
    );
    expect([401, 503]).toContain(cronRes.status);

    expect(escapeHtml('<script>alert("xss")</script>')).not.toContain('<script>');
    expect(sanitizePostgrestSearch('a%,b.or.(id.eq.1)')).not.toMatch(/[,().%]/);
    expect(isAllowedMediaUrl('javascript:alert(1)')).toBe(false);
    expect(isAllowedMediaUrl('https://cdn.thali.store/photo.jpg')).toBe(true);
  });
});
