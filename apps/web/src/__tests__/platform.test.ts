import { describe, expect, it } from 'vitest';
import {
  calculateProviderDailyUsageFee,
  calculateProviderBillableFee,
  APP_CONFIG,
} from '../lib/config';
import {
  generateCounterQRToken,
  generateSignedQRToken,
  getIndiaDateString,
  verifyCounterQRToken,
  verifySignedQRToken,
  verifyWebhookSignature,
} from '../lib/crypto';
import crypto from 'crypto';

describe('Thali configuration and cryptographic primitives', () => {
  it.each([[0, 0], [1, 25], [90, 25], [91, 50], [180, 50], [181, 75]])(
    'calculates the configured usage fee for %i successful redemptions',
    (count, expected) => expect(calculateProviderDailyUsageFee(count)).toBe(expected),
  );

  it('rejects negative and fractional redemption counts', () => {
    expect(() => calculateProviderDailyUsageFee(-1)).toThrow();
    expect(() => calculateProviderDailyUsageFee(1.5)).toThrow();
  });

  it('keeps the specified INR 25 per started block of 90', () => {
    expect(APP_CONFIG.monetization.feePerStartedBlockInr).toBe(25);
    expect(APP_CONFIG.monetization.successfulRedemptionsPerBlock).toBe(90);
  });

  it('waives all usage fees during the trial, when exempt, or when billing is disabled', () => {
    const afterTrial = { successfulUniqueRedemptions: 91, trialEndsAt: '2026-01-01T00:00:00.000Z', usageAt: '2026-02-01T00:00:00.000Z' };
    expect(calculateProviderBillableFee({ ...afterTrial, usageBillingEnabled: false, billingExempt: false })).toBe(0);
    expect(calculateProviderBillableFee({ ...afterTrial, usageBillingEnabled: true, billingExempt: true })).toBe(0);
    expect(calculateProviderBillableFee({ ...afterTrial, successfulUniqueRedemptions: 91, trialEndsAt: '2026-02-02T00:00:00.000Z', usageBillingEnabled: true, billingExempt: false })).toBe(0);
  });

  it('accrues the configured usage fee only after an eligible trial ends', () => {
    expect(calculateProviderBillableFee({ successfulUniqueRedemptions: 91, trialEndsAt: '2026-01-01T00:00:00.000Z', usageAt: '2026-02-01T00:00:00.000Z', usageBillingEnabled: true, billingExempt: false })).toBe(50);
  });

  it('signs and verifies short-lived redemption tokens', () => {
    const token = generateSignedQRToken({
      bookingId: 'test-booking-id', customerId: 'test-customer-id',
      providerId: 'test-provider-id', mealSlotId: 'test-meal-slot-id',
      bookingDate: getIndiaDateString(),
    });
    expect(verifySignedQRToken(token.encodedString).isValid).toBe(true);
    const altered = token.encodedString.endsWith('0')
      ? `${token.encodedString.slice(0, -1)}1`
      : `${token.encodedString.slice(0, -1)}0`;
    expect(verifySignedQRToken(altered).isValid).toBe(false);
  });

  it('rejects unsigned and unknown QR values', () => {
    const result = verifyCounterQRToken(`UNSIGNED|test-provider|${getIndiaDateString()}|lunch`);
    expect(result.isValid).toBe(false);
  });

  it('validates webhook HMAC signatures with constant-time comparison', () => {
    const secret = 'test-only-webhook-secret';
    const body = JSON.stringify({ event: 'payment.captured', id: 'test-event' });
    const signature = crypto.createHmac('sha256', secret).update(body).digest('hex');
    expect(verifyWebhookSignature(body, signature, secret)).toBe(true);
    expect(verifyWebhookSignature(body, 'invalid', secret)).toBe(false);
  });
});
