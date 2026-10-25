import { describe, expect, it, beforeEach } from 'vitest';
import {
  platformStore,
  validateAndApplyPromo,
  processStudentCheckin,
} from '../lib/platform-service';

describe('Zomato/Swiggy-Level Features Test Suite', () => {
  const providerId = 'prov-radhe-001';
  const customerId = 'cust-ritik-001';

  beforeEach(() => {
    // Reset test subscription
    platformStore.subscriptions.set('sub-test-checkin', {
      id: 'sub-test-checkin',
      customer_id: 'student-101',
      provider_id: providerId,
      plan_id: 'plan-tracker-60m',
      plan_type: 'meal_credits',
      plan_name: '60-Meal Flexi Tracker Pack',
      status: 'active',
      starts_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000).toISOString(),
      remaining_meal_credits: 5,
      initial_meal_credits: 10,
      price_paid_paise: 480000,
      created_at: new Date().toISOString(),
    });

    for (const [id, r] of platformStore.redemptions.entries()) {
      if (r.user_id === 'student-101') {
        platformStore.redemptions.delete(id);
      }
    }
  });

  describe('1. Promo Codes & Discounts Engine', () => {
    it('applies percentage discount correctly with code WELCOME10', () => {
      const orderAmountPaise = 280000; // ₹2,800
      const result = validateAndApplyPromo({
        code: 'WELCOME10',
        orderAmountPaise,
      });

      expect(result.isValid).toBe(true);
      expect(result.code).toBe('WELCOME10');
      expect(result.discountPaise).toBe(28000); // 10% = ₹280 = 28000 paise
      expect(result.finalAmountPaise).toBe(252000); // ₹2,520
    });

    it('applies flat discount correctly with code STUDENT50', () => {
      const orderAmountPaise = 100000; // ₹1,000
      const result = validateAndApplyPromo({
        code: 'STUDENT50',
        orderAmountPaise,
      });

      expect(result.isValid).toBe(true);
      expect(result.code).toBe('STUDENT50');
      expect(result.discountPaise).toBe(5000); // ₹50 flat
      expect(result.finalAmountPaise).toBe(95000); // ₹950
    });

    it('rejects promo code if minimum order amount is not met', () => {
      const orderAmountPaise = 20000; // ₹200 (min is ₹500 for STUDENT50)
      const result = validateAndApplyPromo({
        code: 'STUDENT50',
        orderAmountPaise,
      });

      expect(result.isValid).toBe(false);
      expect(result.message).toContain('Minimum order amount');
    });

    it('rejects non-existent promo codes', () => {
      const result = validateAndApplyPromo({
        code: 'FAKECODE99',
        orderAmountPaise: 100000,
      });

      expect(result.isValid).toBe(false);
      expect(result.message).toContain('Invalid or expired');
    });
  });

  describe('2. Provider Student Check-In Flow', () => {
    it('allows counter staff to verify student and decrement meal credit', () => {
      const result = processStudentCheckin({
        providerId,
        studentIdOrQr: 'student-101',
        slot: 'LUNCH',
      });

      expect(result.success).toBe(true);
      expect(result.student_id).toBe('student-101');
      expect(result.remaining_credits).toBe(4);

      const sub = platformStore.subscriptions.get('sub-test-checkin');
      expect(sub?.remaining_meal_credits).toBe(4);
    });

    it('prevents duplicate staff checkin for the same slot on the same day', () => {
      // First checkin
      processStudentCheckin({
        providerId,
        studentIdOrQr: 'student-101',
        slot: 'DINNER',
      });

      // Second checkin must fail
      const secondCheckin = processStudentCheckin({
        providerId,
        studentIdOrQr: 'student-101',
        slot: 'DINNER',
      });

      expect(secondCheckin.success).toBe(false);
      expect(secondCheckin.message).toContain('already checked in');
    });
  });

  describe('3. Reviews & Ratings', () => {
    it('computes average rating across reviews', () => {
      const reviews = Array.from(platformStore.reviews.values()).filter(
        (r) => r.provider_id === providerId
      );

      expect(reviews.length).toBeGreaterThanOrEqual(1);
      const avg = reviews.reduce((sum, r) => sum + r.rating, 0) / reviews.length;
      expect(avg).toBeGreaterThanOrEqual(1);
      expect(avg).toBeLessThanOrEqual(5);
    });
  });
});
