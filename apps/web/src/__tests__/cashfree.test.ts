import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import crypto from 'crypto';
import {
  getCashfreeConfig,
  verifyCashfreeWebhookSignature,
  cashfreeOrderStore,
} from '../lib/cashfree';
import { fulfillCashfreePaidOrder } from '../lib/cashfree-fulfillment';
import { platformStore } from '../lib/platform-service';

describe('Cashfree Payment Gateway integration', () => {
  const originalAppId = process.env.CASHFREE_APP_ID;
  const originalSecret = process.env.CASHFREE_SECRET_KEY;
  const originalEnv = process.env.CASHFREE_ENV;

  beforeEach(() => {
    process.env.CASHFREE_APP_ID = 'TEST_APP_ID';
    process.env.CASHFREE_SECRET_KEY = 'test_secret_key_for_hmac';
    process.env.CASHFREE_ENV = 'sandbox';
  });

  afterEach(() => {
    process.env.CASHFREE_APP_ID = originalAppId;
    process.env.CASHFREE_SECRET_KEY = originalSecret;
    process.env.CASHFREE_ENV = originalEnv;
  });

  it('reads sandbox/production Cashfree config safely', () => {
    const cfg = getCashfreeConfig();
    expect(cfg.configured).toBe(true);
    expect(cfg.env).toBe('sandbox');
    expect(cfg.apiBase).toBe('https://sandbox.cashfree.com/pg');

    process.env.CASHFREE_ENV = 'production';
    const prodCfg = getCashfreeConfig();
    expect(prodCfg.env).toBe('production');
    expect(prodCfg.apiBase).toBe('https://api.cashfree.com/pg');
  });

  it('verifies valid Cashfree HMAC-SHA256 webhook signature and rejects tampered body', () => {
    const rawBody = JSON.stringify({
      type: 'PAYMENT_SUCCESS_WEBHOOK',
      data: { order: { order_id: 'cf_thali_123', order_amount: 2500 } },
    });
    const timestamp = '1732531200';
    const validSig = crypto
      .createHmac('sha256', 'test_secret_key_for_hmac')
      .update(`${timestamp}${rawBody}`)
      .digest('base64');

    expect(verifyCashfreeWebhookSignature(rawBody, validSig, timestamp)).toBe(true);
    expect(verifyCashfreeWebhookSignature(`${rawBody} `, validSig, timestamp)).toBe(false);
    expect(verifyCashfreeWebhookSignature(rawBody, 'bad-sig', timestamp)).toBe(false);
  });

  it('activates pending subscription idempotently when Cashfree order is paid', async () => {
    const subId = 'sub-cf-test-1';
    const orderId = 'cf_thali_test_1';

    platformStore.subscriptions.set(subId, {
      id: subId,
      customer_id: 'cust-1',
      customer_name: 'Test Student',
      provider_id: 'prov-1',
      plan_id: 'plan-1',
      plan_type: 'fixed_period',
      plan_name: 'Monthly Unlimited',
      status: 'pending_payment',
      starts_at: new Date().toISOString(),
      expires_at: new Date().toISOString(),
      price_paid_paise: 250000,
      created_at: new Date().toISOString(),
    });

    cashfreeOrderStore.set(orderId, {
      order_id: orderId,
      payment_session_id: 'session_test_1',
      purpose: 'subscription_purchase',
      subscription_id: subId,
      customer_id: 'cust-1',
      customer_name: 'Test Student',
      customer_phone: '9999999999',
      customer_email: 'student@example.com',
      provider_id: 'prov-1',
      provider_name: 'Test Mess',
      plan_name: 'Monthly Unlimited',
      duration_days: 30,
      amount_paise: 250000,
      status: 'created',
      created_at: new Date().toISOString(),
    });

    const first = await fulfillCashfreePaidOrder({
      orderId,
      cfPaymentId: 'cf_pay_1',
      orderAmountInr: 2500,
    });
    expect(first.alreadyProcessed).toBe(false);
    expect(platformStore.subscriptions.get(subId)?.status).toBe('active');

    const second = await fulfillCashfreePaidOrder({
      orderId,
      cfPaymentId: 'cf_pay_1',
      orderAmountInr: 2500,
    });
    expect(second.alreadyProcessed).toBe(true);

    cashfreeOrderStore.delete(orderId);
    platformStore.subscriptions.delete(subId);
  });
});
