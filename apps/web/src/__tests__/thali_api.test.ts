import { describe, expect, it, beforeEach } from 'vitest';
import {
  platformStore,
  generateProviderDailyQR,
  processMealRedemption,
  executeProviderBillingJob,
  getCurrentMealSlot,
} from '../lib/platform-service';
import {
  getIndiaDateString,
  verifyCounterQRToken,
  verifySignedQRToken,
  generateSignedQRToken,
  verifyWebhookSignature,
} from '../lib/crypto';
import crypto from 'crypto';

describe('Thali Platform Master Flow Test Suite', () => {
  const providerId = 'prov-radhe-001';
  const customerId = 'cust-test-user-001';

  beforeEach(() => {
    // Reset test subscriptions
    platformStore.subscriptions.set('sub-test-tracker', {
      id: 'sub-test-tracker',
      customer_id: customerId,
      provider_id: providerId,
      plan_id: 'plan-tracker-60m',
      plan_type: 'meal_credits',
      plan_name: '60-Meal Flexi Tracker Pack',
      status: 'active',
      starts_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000).toISOString(),
      remaining_meal_credits: 10,
      initial_meal_credits: 10,
      price_paid_paise: 480000,
      created_at: new Date().toISOString(),
    });

    // Clear redemptions for this test user
    for (const [id, r] of platformStore.redemptions.entries()) {
      if (r.user_id === customerId) {
        platformStore.redemptions.delete(id);
      }
    }
  });

  describe('1. QR Code Issuance & Cryptographic Integrity', () => {
    it('generates a signed daily QR code token valid for today', () => {
      const qrData = generateProviderDailyQR({
        providerId,
        slot: 'LUNCH',
      });

      expect(qrData.token).toContain('MESS_QR|');
      expect(qrData.providerId).toBe(providerId);
      expect(qrData.slot).toBe('LUNCH');
      expect(qrData.date).toBe(getIndiaDateString());

      const verified = verifyCounterQRToken(qrData.token);
      expect(verified.isValid).toBe(true);
      expect(verified.isExpired).toBe(false);
      expect(verified.providerId).toBe(providerId);
    });

    it('rejects tampered or forged QR tokens', () => {
      const qrData = generateProviderDailyQR({ providerId, slot: 'LUNCH' });
      const tampered = qrData.token.slice(0, -4) + 'abcd';
      const verified = verifyCounterQRToken(tampered);
      expect(verified.isValid).toBe(false);
    });

    it('rejects expired QR tokens from past dates', () => {
      const pastQr = `MESS_QR|${providerId}|2025-01-01|LUNCH|fake_sig`;
      const verified = verifyCounterQRToken(pastQr);
      expect(verified.isExpired).toBe(true);
      expect(verified.isValid).toBe(false);
    });
  });

  describe('2. Meal-Tracker Subscription & Credit Decrement', () => {
    it('successfully redeems meal and decrements exactly 1 credit', () => {
      const qrData = generateProviderDailyQR({ providerId, slot: 'LUNCH' });
      const beforeCredits = platformStore.subscriptions.get('sub-test-tracker')?.remaining_meal_credits;
      expect(beforeCredits).toBe(10);

      const result = processMealRedemption({
        userId: customerId,
        token: qrData.token,
      });

      expect(result.success).toBe(true);
      expect(result.slot).toBe('LUNCH');
      expect(result.remaining_credits).toBe(9);

      const afterCredits = platformStore.subscriptions.get('sub-test-tracker')?.remaining_meal_credits;
      expect(afterCredits).toBe(9);
    });

    it('prevents double-scanning for the same slot on the same day (Idempotency)', () => {
      const qrData = generateProviderDailyQR({ providerId, slot: 'LUNCH' });

      // First scan passes
      const firstScan = processMealRedemption({
        userId: customerId,
        token: qrData.token,
      });
      expect(firstScan.success).toBe(true);

      // Second scan must be rejected with duplicate message
      const secondScan = processMealRedemption({
        userId: customerId,
        token: qrData.token,
      });
      expect(secondScan.success).toBe(false);
      expect(secondScan.message).toContain('already redeemed');
    });

    it('correctly calculates optional extras and records them', () => {
      // Clear redemption for dinner
      const qrData = generateProviderDailyQR({ providerId, slot: 'DINNER' });

      const result = processMealRedemption({
        userId: customerId,
        token: qrData.token,
        extras: [
          { name: 'Paneer Butter Masala', price: 40, quantity: 1 },
          { name: 'Extra Roti', price: 15, quantity: 2 },
        ],
      });

      expect(result.success).toBe(true);
      expect(result.amount_extra).toBe(70); // 40 + 15*2 = 70
      expect(result.message).toContain('Extras added: ₹70');
    });

    it('blocks redemption when tracker balance reaches zero', () => {
      const sub = platformStore.subscriptions.get('sub-test-tracker');
      if (sub) sub.remaining_meal_credits = 0;

      const qrData = generateProviderDailyQR({ providerId, slot: 'SNACKS' });
      const result = processMealRedemption({
        userId: customerId,
        token: qrData.token,
      });

      expect(result.success).toBe(false);
      expect(result.message).toContain('No meal credits remaining');
    });
  });

  describe('3. Fixed-Period Subscription Entitlement', () => {
    it('allows redemptions without decrementing credit count', () => {
      const fixedCustId = 'cust-fixed-user-999';
      platformStore.subscriptions.set('sub-test-fixed', {
        id: 'sub-test-fixed',
        customer_id: fixedCustId,
        provider_id: providerId,
        plan_id: 'plan-fixed-1m',
        plan_type: 'fixed_period',
        plan_name: 'Monthly Unlimited Fixed Plan',
        status: 'active',
        starts_at: new Date().toISOString(),
        expires_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
        price_paid_paise: 280000,
        created_at: new Date().toISOString(),
      });

      const qrData = generateProviderDailyQR({ providerId, slot: 'BREAKFAST' });
      const result = processMealRedemption({
        userId: fixedCustId,
        token: qrData.token,
      });

      expect(result.success).toBe(true);
      expect(result.remaining_credits).toBe(null); // No credit count on fixed plan
    });
  });

  describe('4. Provider Usage-Based Billing Job (₹25 per 90 scans)', () => {
    it('generates an invoice and collects ₹25 for every slab of 90 successful scans', () => {
      const testProvId = 'prov-billing-test';
      platformStore.providerScanCounts.set(testProvId, { total: 185, unbilled: 180 });

      const billingResult = executeProviderBillingJob();
      expect(billingResult.invoicesGenerated).toBeGreaterThanOrEqual(1);

      const matchingInvoice = billingResult.invoices.find((i) => i.provider_id === testProvId);
      expect(matchingInvoice).toBeDefined();
      expect(matchingInvoice?.total_scans).toBe(180);
      expect(matchingInvoice?.total_due_paise).toBe(5000); // 2 blocks of 90 * ₹25 = ₹50 = 5000 paise
      expect(matchingInvoice?.status).toBe('paid');

      const remainingUnbilled = platformStore.providerScanCounts.get(testProvId)?.unbilled;
      expect(remainingUnbilled).toBe(0);
    });
  });

  describe('5. Razorpay Webhook Signature Verification', () => {
    it('verifies valid HMAC webhook signatures', () => {
      const secret = 'rzp_test_secret_12345';
      const body = JSON.stringify({ event: 'payment.captured', id: 'pay_xyz' });
      const signature = crypto.createHmac('sha256', secret).update(body).digest('hex');

      expect(verifyWebhookSignature(body, signature, secret)).toBe(true);
      expect(verifyWebhookSignature(body, 'invalid_sig', secret)).toBe(false);
    });
  });
});
