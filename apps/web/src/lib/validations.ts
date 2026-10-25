import { z } from 'zod';

export const BookingCreateSchema = z.object({
  subscription_id: z.string().min(1).optional(),
  provider_id: z.string().min(1, 'Valid provider ID required'),
  meal_slot_id: z.string().min(1, 'Valid meal slot ID required'),
  booking_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Must be YYYY-MM-DD'),
  fulfillment_type: z.enum(['pickup', 'delivery']),
  delivery_address_id: z.string().min(1).optional(),
  notes: z.string().max(250).optional(),
});

export const QRRedemptionSchema = z.object({
  token_payload: z.string().min(10, 'Token payload required'),
  provider_id: z.string().min(1, 'Valid provider ID required'),
});

export const CheckoutSessionSchema = z.object({
  plan_id: z.string().min(1, 'Valid plan ID required'),
  provider_id: z.string().min(1, 'Valid provider ID required'),
  start_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  auto_renew: z.boolean().default(false),
});

export const DeliveryAcceptSchema = z.object({
  assignment_id: z.string().min(1),
});

export const DeliveryCompleteSchema = z.object({
  assignment_id: z.string().min(1),
  delivery_otp: z.string().length(6, 'OTP must be 6 digits'),
});

export const PlanCreateSchema = z.object({
  name: z.string().min(3).max(100),
  description: z.string().min(10),
  plan_type: z.enum(['fixed_period', 'meal_based', 'daily_pay_as_you_eat']),
  duration_days: z.number().int().min(1).max(365),
  total_meals: z.number().int().min(1).nullable().optional(),
  price_inr: z.number().positive(),
  original_price_inr: z.number().positive().optional(),
  allowed_meal_slots: z.array(z.string()).min(1),
  daily_meal_limit: z.number().int().min(1).max(5).default(2),
  delivery_eligible: z.boolean().default(true),
});
