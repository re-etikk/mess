import { describe, expect, it } from 'vitest';
import { NextRequest } from 'next/server';
import { hasAdminCapability } from '@/lib/admin-rbac';
import { getPlatformAppConfig } from '@/lib/app-config';
import { evaluatePromoCode } from '@/lib/promo-engine';
import { requireAdmin } from '@/lib/supabase/admin';
import { signSessionToken } from '@/lib/auth-session';
import { platformStore } from '@/lib/platform-service';
import { GET as getAppConfig } from '@/app/api/app-config/route';
import { GET as getAnnouncements } from '@/app/api/announcements/route';
import { POST as postSupportTicket } from '@/app/api/support/ticket/route';
import { GET as getCounterOrders, POST as postCounterOrder } from '@/app/api/provider/orders/route';

describe('Admin RBAC, Promo Engine & Partner Parity Suite', () => {
  it('enforces strict capability matrix across Admin roles', () => {
    expect(hasAdminCapability('super_admin', 'access.manage')).toBe(true);
    expect(hasAdminCapability('super_admin', 'finance.manage')).toBe(true);
    expect(hasAdminCapability('operations', 'operations.read')).toBe(true);
    expect(hasAdminCapability('operations', 'access.manage')).toBe(false);
    expect(hasAdminCapability('finance', 'finance.read')).toBe(true);
    expect(hasAdminCapability('finance', 'finance.manage')).toBe(true);
    expect(hasAdminCapability('finance', 'access.manage')).toBe(false);
    expect(hasAdminCapability('support', 'support.read')).toBe(true);
    expect(hasAdminCapability('developer_readonly', 'operations.read')).toBe(true);
    expect(hasAdminCapability('developer_readonly', 'finance.manage')).toBe(false);
  });

  it('rejects unauthenticated admin requests without service/session bypass', async () => {
    const req = new NextRequest('http://localhost:3000/api/admin/metrics');
    const access = await requireAdmin(req, 'operations.read');
    expect(access.ok).toBe(false);
    if (!access.ok) {
      expect([401, 403, 503]).toContain(access.status);
    }
  });

  it('returns default zero-fee & approval-gated app config cleanly', async () => {
    const cfg = await getPlatformAppConfig(null);
    expect(cfg.platform_fee_paise).toBe(0);
    expect(cfg.default_delivery_fee_paise).toBe(0);
    expect(cfg.default_commission_bps).toBe(0);
    expect(cfg.require_provider_approval).toBe(true);

    const res = await getAppConfig();
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.success).toBe(true);
    expect(json.config.platform_fee_paise).toBe(0);
  });

  it('serves announcements feed without 503 stub failure', async () => {
    const req = new NextRequest('http://localhost:3000/api/announcements?audience=customer');
    const res = await getAnnouncements(req);
    expect(res.status).toBe(200);
    const json = await res.json();
    expect(json.success).toBe(true);
    expect(Array.isArray(json.announcements)).toBe(true);
  });

  it('enforces unified promo precedence (flat_discount_paise > 0 else capped percent) and limits', async () => {
    platformStore.promos.set('FLAT100PCT', {
      id: 'promo-test-flat',
      code: 'FLAT100PCT',
      title: 'Flat Priority Test',
      flat_discount_paise: 10000,
      discount_percent: 50,
      min_order_paise: 50000,
      max_discount_paise: 25000,
      applicable_to_plans: true,
      applicable_to_daily: false,
      usage_limit: 5,
      times_used: 1,
      is_active: true,
    });

    // Flat takes precedence when flat_discount_paise > 0 (100 INR = 10000 paise, not 50% of 600 INR = 30000)
    const flatRes = await evaluatePromoCode({
      admin: null,
      code: 'FLAT100PCT',
      orderContext: 'plan',
      orderAmountPaise: 60000,
    });
    expect(flatRes.isValid).toBe(true);
    expect(flatRes.discountPaise).toBe(10000);
    expect(flatRes.finalAmountPaise).toBe(50000);

    // Rejects daily context when applicable_to_daily is false
    const dailyRejected = await evaluatePromoCode({
      admin: null,
      code: 'FLAT100PCT',
      orderContext: 'daily',
      orderAmountPaise: 60000,
    });
    expect(dailyRejected.isValid).toBe(false);

    // Percent capped at max_discount_paise
    platformStore.promos.set('PCTCAP', {
      id: 'promo-test-cap',
      code: 'PCTCAP',
      title: 'Percentage Cap Test',
      flat_discount_paise: 0,
      discount_percent: 50,
      min_order_paise: 10000,
      max_discount_paise: 15000,
      applicable_to_plans: true,
      applicable_to_daily: true,
      is_active: true,
    });
    const capRes = await evaluatePromoCode({
      admin: null,
      code: 'PCTCAP',
      orderContext: 'daily',
      orderAmountPaise: 60000,
    });
    expect(capRes.isValid).toBe(true);
    expect(capRes.discountPaise).toBe(15000);

    // Exceeded usage_limit is rejected
    platformStore.promos.set('EXHAUSTED', {
      id: 'promo-test-exhausted',
      code: 'EXHAUSTED',
      title: 'Exhausted',
      flat_discount_paise: 5000,
      min_order_paise: 0,
      usage_limit: 2,
      times_used: 2,
      is_active: true,
    });
    const exhaustedRes = await evaluatePromoCode({
      admin: null,
      code: 'EXHAUSTED',
      orderAmountPaise: 20000,
    });
    expect(exhaustedRes.isValid).toBe(false);
  });

  it('persists support ticket submissions accepting description or message payload', async () => {
    const req = new NextRequest('http://localhost:3000/api/support/ticket', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-forwarded-for': '203.0.113.77' },
      body: JSON.stringify({
        name: 'Test Student',
        email: 'student@example.com',
        role: 'customer',
        category: 'Payment & Refund',
        subject: 'Double charge check',
        description: 'Need confirmation on my subscription receipt.',
      }),
    });
    const res = await postSupportTicket(req);
    expect([200, 201]).toContain(res.status);
    const json = await res.json();
    expect(json.success).toBe(true);
  });

  it('records and retrieves walk-in counter orders for authenticated partner', async () => {
    const providerId = 'prov-counter-test-1';
    const token = signSessionToken({
      userId: 'owner-counter-1',
      role: 'provider',
      email: 'partner@test.local',
      providerId,
    });

    const postReq = new NextRequest('http://localhost:3000/api/provider/orders', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        provider_id: providerId,
        customer_name: 'Walk-In Diner',
        slot: 'LUNCH',
        items_summary: '2 Special Thalis',
        amount_inr: 160,
        payment_mode: 'counter_cash',
      }),
    });
    const postRes = await postCounterOrder(postReq);
    expect(postRes.status).toBe(201);
    const postJson = await postRes.json();
    expect(postJson.success).toBe(true);
    expect(postJson.order.amount_inr).toBe(160);

    const getReq = new NextRequest(`http://localhost:3000/api/provider/orders?provider_id=${providerId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    const getRes = await getCounterOrders(getReq);
    expect(getRes.status).toBe(200);
    const getJson = await getRes.json();
    expect(getJson.success).toBe(true);
    expect(getJson.orders.some((o: any) => o.customer_name === 'Walk-In Diner')).toBe(true);
  });
});
