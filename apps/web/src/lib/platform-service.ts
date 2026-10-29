import crypto from 'crypto';
import { APP_CONFIG, calculateProviderDailyUsageFee } from './config';
import { getIndiaDateString, verifyCounterQRToken, verifySignedQRToken } from './crypto';
import { MessReview, PromoCode, Announcement, CustomerNotification } from '@/types';

export interface PlanData {
  id: string;
  provider_id: string;
  name: string;
  description: string;
  plan_type: 'fixed_period' | 'meal_credits' | 'daily';
  duration_days: number;
  price_paise: number;
  currency: string;
  meal_credits?: number | null;
  daily_meal_limit: number;
  discount_percent?: number;
  is_active: boolean;
  created_at: string;
}

export interface MenuData {
  id: string;
  provider_id: string;
  day_of_week: string;
  slot: string;
  items_included: string[];
  items_extra: { name: string; price: number; limit?: number; is_available?: boolean }[];
  items_unavailable?: string[];
  is_active: boolean;
  updated_at: string;
}

export interface SubscriptionData {
  id: string;
  customer_id: string;
  customer_name?: string;
  customer_phone?: string;
  customer_email?: string;
  provider_id: string;
  plan_id: string;
  plan_type: 'fixed_period' | 'meal_credits' | 'daily';
  plan_name: string;
  status: 'active' | 'expired' | 'cancelled' | 'pending_payment';
  starts_at: string;
  expires_at: string;
  remaining_meal_credits?: number | null;
  initial_meal_credits?: number | null;
  price_paid_paise: number;
  razorpay_subscription_id?: string;
  razorpay_payment_id?: string;
  payment_mode?: 'online' | 'cash' | 'counter_upi' | 'complimentary' | string;
  created_at: string;
}

export interface RedemptionData {
  id: string;
  user_id: string;
  customer_name?: string;
  customer_phone?: string;
  plan_name?: string;
  remaining_credits?: number | null;
  time_formatted?: string;
  provider_id: string;
  subscription_id?: string;
  date: string;
  slot: string;
  amount_extra_paise: number;
  extra_items: { name: string; price: number; quantity?: number }[];
  remarks?: string;
  redeemed_at: string;
}

export interface CounterOrderData {
  id: string;
  provider_id: string;
  customer_name: string;
  customer_phone?: string;
  items_summary: string;
  items: { name: string; price: number; quantity: number }[];
  total_amount_inr: number;
  payment_mode: 'cash' | 'counter_upi' | 'online';
  status: 'paid' | 'pending';
  created_at: string;
}

export interface ProviderTimingsData {
  provider_id: string;
  breakfast: { enabled: boolean; start: string; end: string };
  lunch: { enabled: boolean; start: string; end: string };
  dinner: { enabled: boolean; start: string; end: string };
  weekly_off?: string;
  updated_at: string;
}

export interface InvoiceData {
  id: string;
  provider_id: string;
  period_start: string;
  period_end: string;
  total_scans: number;
  total_due_paise: number;
  razorpay_invoice_id?: string;
  status: 'pending' | 'paid' | 'failed' | 'waived';
  paid_at?: string;
  created_at: string;
}

export interface ProviderData {
  id: string;
  owner_user_id: string;
  display_name: string;
  slug: string;
  description: string;
  phone: string;
  email: string;
  address: string;
  locality: string;
  city: string;
  rating: number;
  total_reviews: number;
  cuisines: string[];
  dietary_types: ('veg' | 'non_veg' | 'jain')[];
  distance_km?: number;
  status: 'draft' | 'pending_review' | 'active' | 'rejected' | 'suspended';
  is_open_today?: boolean;
  created_at: string;
}

// In-Memory store for fast, reliable testing & staging execution
class PlatformStore {
  providers: Map<string, ProviderData> = new Map();
  plans: Map<string, PlanData> = new Map();
  menus: Map<string, MenuData> = new Map();
  subscriptions: Map<string, SubscriptionData> = new Map();
  redemptions: Map<string, RedemptionData> = new Map();
  counterOrders: Map<string, CounterOrderData> = new Map();
  timings: Map<string, ProviderTimingsData> = new Map();
  invoices: Map<string, InvoiceData> = new Map();
  providerScanCounts: Map<string, { total: number; unbilled: number }> = new Map();
  reviews: Map<string, MessReview> = new Map();
  promos: Map<string, PromoCode> = new Map();
  announcements: Map<string, Announcement> = new Map();
  notifications: Map<string, CustomerNotification> = new Map();

  constructor() {
    if (process.env.NODE_ENV === 'test') {
      this.seedDemoData();
    }
  }

  seedDemoData() {
    const provId = 'prov-radhe-001';
    this.providers.set(provId, {
      id: provId,
      owner_user_id: 'user-owner-001',
      display_name: 'Radhe Mess & Tiffin Services',
      slug: 'radhe-mess',
      description: 'Pure authentic homely vegetarian thalis and meals for students & professionals.',
      phone: '+91 98765 43210',
      email: 'owner@radhemess.in',
      address: '14, 5th Cross, 1st Main, Marathahalli',
      locality: 'Marathahalli',
      city: 'Bengaluru',
      rating: 4.8,
      total_reviews: 124,
      cuisines: ['North Indian', 'Home Tiffin', 'Gujarati'],
      dietary_types: ['veg', 'jain'],
      distance_km: 0.8,
      status: 'active',
      created_at: new Date().toISOString(),
    });

    const provId2 = 'prov-annapurna-002';
    this.providers.set(provId2, {
      id: provId2,
      owner_user_id: 'user-owner-002',
      display_name: 'Annapurna Student Mess',
      slug: 'annapurna-mess',
      description: 'Budget-friendly unlimited student meals with special Sunday feasts.',
      phone: '+91 98765 43211',
      email: 'contact@annapurnamess.in',
      address: '88, Near BIMS Hostel, BTM 2nd Stage',
      locality: 'BTM Layout',
      city: 'Bengaluru',
      rating: 4.6,
      total_reviews: 89,
      cuisines: ['South Indian', 'North Indian'],
      dietary_types: ['veg'],
      distance_km: 1.4,
      status: 'active',
      created_at: new Date().toISOString(),
    });

    // Plans for Provider 1
    const fixedPlanId = 'plan-fixed-1m';
    this.plans.set(fixedPlanId, {
      id: fixedPlanId,
      provider_id: provId,
      name: 'Monthly Unlimited Fixed Plan',
      description: 'Daily unlimited thali meals for 30 days. No meal credit tracking.',
      plan_type: 'fixed_period',
      duration_days: 30,
      price_paise: 280000, // ₹2,800
      currency: 'INR',
      meal_credits: null,
      daily_meal_limit: 2,
      is_active: true,
      created_at: new Date().toISOString(),
    });

    const trackerPlanId = 'plan-tracker-60m';
    this.plans.set(trackerPlanId, {
      id: trackerPlanId,
      provider_id: provId,
      name: '60-Meal Flexi Tracker Pack',
      description: 'Deducts 1 credit per redemption. Valid for 60 days.',
      plan_type: 'meal_credits',
      duration_days: 60,
      price_paise: 480000, // ₹4,800 (₹80/meal)
      currency: 'INR',
      meal_credits: 60,
      daily_meal_limit: 2,
      is_active: true,
      created_at: new Date().toISOString(),
    });

    const dailyPlanId = 'plan-daily-single';
    this.plans.set(dailyPlanId, {
      id: dailyPlanId,
      provider_id: provId,
      name: 'Single Daily Meal',
      description: 'One-time lunch or dinner thali.',
      plan_type: 'daily',
      duration_days: 1,
      price_paise: 9900, // ₹99
      currency: 'INR',
      meal_credits: 1,
      daily_meal_limit: 1,
      is_active: true,
      created_at: new Date().toISOString(),
    });

    // Menus
    this.menus.set(`${provId}_Daily_LUNCH`, {
      id: `menu-${provId}-lunch`,
      provider_id: provId,
      day_of_week: 'Daily',
      slot: 'LUNCH',
      items_included: ['Dal Tadka', 'Steamed Basmati Rice', '4 Phulka Rotis', 'Seasonal Sabzi', 'Cucumber Salad', 'Papad'],
      items_extra: [
        { name: 'Paneer Butter Masala', price: 40, limit: 2 },
        { name: 'Extra Roti (Set of 2)', price: 15, limit: 4 },
        { name: 'Gulab Jamun (2 pcs)', price: 30, limit: 2 },
        { name: 'Curd / Raita', price: 20, limit: 2 },
      ],
      is_active: true,
      updated_at: new Date().toISOString(),
    });

    this.menus.set(`${provId}_Daily_DINNER`, {
      id: `menu-${provId}-dinner`,
      provider_id: provId,
      day_of_week: 'Daily',
      slot: 'DINNER',
      items_included: ['Mixed Dal', 'Jeera Rice', '4 Rotis', 'Aloo Gobi', 'Pickle'],
      items_extra: [
        { name: 'Shahi Paneer', price: 45, limit: 2 },
        { name: 'Extra Roti (Set of 2)', price: 15, limit: 4 },
        { name: 'Kheer Bowl', price: 35, limit: 1 },
      ],
      is_active: true,
      updated_at: new Date().toISOString(),
    });

    // Platform Promo Codes
    this.promos.set('WELCOME10', {
      id: 'promo-welcome10',
      code: 'WELCOME10',
      title: 'Welcome 10% Off',
      description: 'Get 10% discount on any monthly subscription plan.',
      discount_percent: 10,
      min_order_paise: 100000,
      max_discount_paise: 50000,
      is_active: true,
    });

    this.promos.set('STUDENT50', {
      id: 'promo-student50',
      code: 'STUDENT50',
      title: 'Flat ₹50 Off',
      description: 'Flat ₹50 off on student flexi meal packs.',
      flat_discount_paise: 5000,
      min_order_paise: 50000,
      is_active: true,
    });

    // In automated unit tests only, seed a test review for test assertions
    if (process.env.NODE_ENV === 'test') {
      this.reviews.set('rev-001', {
        id: 'rev-001',
        provider_id: provId,
        customer_id: 'cust-test-001',
        customer_name: 'Test Student',
        rating: 5,
        review_text: 'Test review for rating computation',
        food_quality_score: 5,
        hygiene_score: 5,
        tags: ['Clean'],
        created_at: new Date().toISOString(),
      });
    }
  }
}

export const platformStore = new PlatformStore();

/** Seed standard subscription plans & daily menus for a new or approved provider */
export function seedProviderPlansAndMenu(providerId: string) {
  const fixedPlanId = `plan-${providerId}-fixed`;
  platformStore.plans.set(fixedPlanId, {
    id: fixedPlanId,
    provider_id: providerId,
    name: 'Monthly Unlimited Fixed Plan',
    description: 'Unlimited daily lunch & dinner thali for 30 days.',
    plan_type: 'fixed_period',
    duration_days: 30,
    price_paise: 279900,
    currency: 'INR',
    meal_credits: null,
    daily_meal_limit: 2,
    is_active: true,
    created_at: new Date().toISOString(),
  });

  const flexiPlanId = `plan-${providerId}-flexi`;
  platformStore.plans.set(flexiPlanId, {
    id: flexiPlanId,
    provider_id: providerId,
    name: '30-Meal Flexi Tracker Pack',
    description: 'Deducts 1 meal credit per redemption. Valid for 45 days.',
    plan_type: 'meal_credits',
    duration_days: 45,
    price_paise: 240000,
    currency: 'INR',
    meal_credits: 30,
    daily_meal_limit: 2,
    is_active: true,
    created_at: new Date().toISOString(),
  });

  const dailyMealPlanId = `plan-${providerId}-daily`;
  platformStore.plans.set(dailyMealPlanId, {
    id: dailyMealPlanId,
    provider_id: providerId,
    name: 'Single Daily Thali Pass',
    description: 'One-time meal token for today.',
    plan_type: 'daily',
    duration_days: 1,
    price_paise: 9500,
    currency: 'INR',
    meal_credits: 1,
    daily_meal_limit: 1,
    is_active: true,
    created_at: new Date().toISOString(),
  });

  platformStore.menus.set(`${providerId}_Daily_LUNCH`, {
    id: `menu-${providerId}-lunch`,
    provider_id: providerId,
    day_of_week: 'Daily',
    slot: 'LUNCH',
    items_included: ['Dal Tadka', 'Basmati Rice', '4 Rotis', 'Sabzi of the day', 'Salad', 'Pickle'],
    items_extra: [
      { name: 'Paneer Butter Masala', price: 40, limit: 2 },
      { name: 'Extra Roti (Set of 2)', price: 15, limit: 4 },
      { name: 'Gulab Jamun (2 pcs)', price: 30, limit: 2 },
    ],
    is_active: true,
    updated_at: new Date().toISOString(),
  });

  platformStore.menus.set(`${providerId}_Daily_DINNER`, {
    id: `menu-${providerId}-dinner`,
    provider_id: providerId,
    day_of_week: 'Daily',
    slot: 'DINNER',
    items_included: ['Dal Makhani', 'Jeera Rice', '4 Rotis', 'Mixed Veg', 'Papad'],
    items_extra: [
      { name: 'Shahi Paneer', price: 45, limit: 2 },
      { name: 'Extra Roti (Set of 2)', price: 15, limit: 4 },
    ],
    is_active: true,
    updated_at: new Date().toISOString(),
  });
}

// ==============================================================================
// BUSINESS LOGIC SERVICES
// ==============================================================================

/** Determine current meal slot from current local time in India */
export function getCurrentMealSlot(date: Date = new Date()): 'BREAKFAST' | 'LUNCH' | 'SNACKS' | 'DINNER' {
  const parts = new Intl.DateTimeFormat('en-IN', {
    timeZone: 'Asia/Kolkata',
    hour: 'numeric',
    minute: 'numeric',
    hour12: false,
  }).formatToParts(date);

  const hour = parseInt(parts.find((p) => p.type === 'hour')?.value || '12', 10);
  if (hour >= 6 && hour < 11) return 'BREAKFAST';
  if (hour >= 11 && hour < 16) return 'LUNCH';
  if (hour >= 16 && hour < 19) return 'SNACKS';
  return 'DINNER';
}

/** Verify any QR token format (Pipe or JSON/HMAC) */
export function verifyAnyQRToken(token: string): {
  isValid: boolean;
  isExpired: boolean;
  providerId?: string;
  date?: string;
  slot?: string;
  error?: string;
} {
  if (!token || typeof token !== 'string') {
    return { isValid: false, isExpired: false, error: 'Empty token' };
  }

  const trimmed = token.trim();
  const today = getIndiaDateString();

  // Format 1: MESS_QR|<providerId>|<date>|<slot>|<signature>
  if (trimmed.startsWith('MESS_QR|')) {
    return verifyCounterQRToken(trimmed);
  }

  // Format 2: Base64Url(JSON).Signature (HMAC-SHA256)
  if (trimmed.includes('.')) {
    try {
      const [payloadB64, sig] = trimmed.split('.');
      const payloadStr = Buffer.from(payloadB64, 'base64url').toString('utf-8');
      const payload = JSON.parse(payloadStr);

      const secret = process.env.QR_SIGNING_SECRET || process.env.QR_HMAC_SECRET || 'test-only-qr-signing-secret-not-for-production-0001';
      const expectedSig = crypto.createHmac('sha256', secret).update(payloadStr).digest('hex');

      const sigBuf = Buffer.from(sig, 'hex');
      const expBuf = Buffer.from(expectedSig, 'hex');
      if (sigBuf.length !== expBuf.length || !crypto.timingSafeEqual(sigBuf, expBuf)) {
        return { isValid: false, isExpired: false, error: 'Invalid QR signature' };
      }

      const tokenDate = payload.date || payload.booking_date;
      if (tokenDate && tokenDate !== today) {
        return { isValid: false, isExpired: true, error: `QR expired. Code date: ${tokenDate}, today: ${today}` };
      }

      return {
        isValid: true,
        isExpired: false,
        providerId: payload.provider_id || payload.pid,
        date: tokenDate || today,
        slot: payload.slot || 'ALL',
      };
    } catch (e: any) {
      return { isValid: false, isExpired: false, error: 'Malformed JSON QR token' };
    }
  }

  return { isValid: false, isExpired: false, error: 'Unrecognized QR format' };
}

/** Generate a signed daily QR token for a provider and slot */
export function generateProviderDailyQR(params: {
  providerId: string;
  slot?: string;
  date?: string;
}): {
  token: string;
  jsonToken: string;
  providerId: string;
  date: string;
  slot: string;
} {
  const date = params.date || getIndiaDateString();
  const slot = params.slot || getCurrentMealSlot();
  const secret = process.env.QR_SIGNING_SECRET || process.env.QR_HMAC_SECRET || 'test-only-qr-signing-secret-not-for-production-0001';

  // Format 1: Pipe token
  const pipeToken = `MESS_QR|${params.providerId}|${date}|${slot}|${crypto.createHmac('sha256', secret).update(`${params.providerId}:${date}:${slot}`).digest('hex')}`;

  // Format 2: JSON HMAC token
  const payload = { provider_id: params.providerId, date, slot };
  const payloadStr = JSON.stringify(payload);
  const jsonToken = `${Buffer.from(payloadStr).toString('base64url')}.${crypto.createHmac('sha256', secret).update(payloadStr).digest('hex')}`;

  return {
    token: pipeToken,
    jsonToken,
    providerId: params.providerId,
    date,
    slot,
  };
}

/** Atomic meal redemption logic */
export function updateProviderStatus(providerId: string, isOpen: boolean): boolean {
  const provider = platformStore.providers.get(providerId);
  if (provider) {
    provider.is_open_today = isOpen;
    return true;
  }
  return false;
}

export function processMealRedemption(params: {
  userId: string;
  token: string;
  extras?: { name: string; price: number; quantity?: number }[];
}): {
  success: boolean;
  slot?: string;
  remaining_credits?: number | null;
  amount_extra?: number;
  message: string;
  redemption_id?: string;
  error?: string;
} {
  const { isValid, isExpired, providerId, date, slot: tokenSlot, error } = verifyAnyQRToken(params.token);

  if (!isValid || !providerId) {
    return { success: false, message: error || 'Invalid QR code signature.' };
  }
  if (isExpired) {
    return { success: false, message: error || 'QR code is expired for today. Please scan today\'s fresh counter QR.' };
  }

  // Check if Mess is marked Closed / OFF Today
  const provider = platformStore.providers.get(providerId);
  if (provider && provider.is_open_today === false) {
    return {
      success: false,
      message: `❌ Mess Closed Today: "${provider.display_name}" is marked CLOSED / OFF today by the kitchen owner. No meals can be redeemed today.`,
    };
  }

  const today = getIndiaDateString();
  const activeSlot = (tokenSlot && tokenSlot !== 'ALL') ? tokenSlot : getCurrentMealSlot();

  // 1. Idempotency Check: Customer cannot redeem same slot on same day twice
  const existingRedemption = Array.from(platformStore.redemptions.values()).find(
    (r) => r.user_id === params.userId && r.provider_id === providerId && r.date === today && r.slot === activeSlot
  );

  if (existingRedemption) {
    return {
      success: false,
      slot: activeSlot,
      message: `Meal already redeemed for ${activeSlot} today (${today}).`,
    };
  }

  // 2. Check Customer Entitlement (Active Subscription or Daily Purchase)
  const activeSub = Array.from(platformStore.subscriptions.values()).find(
    (s) => s.customer_id === params.userId && s.provider_id === providerId && s.status === 'active'
  );

  if (!activeSub) {
    return {
      success: false,
      slot: activeSlot,
      message: 'No active subscription or daily meal pass found for this mess.',
    };
  }

  // 3. Deduct credit if Meal Tracker Plan
  let newCredits: number | null = null;
  if (activeSub.plan_type === 'meal_credits') {
    const currentCredits = activeSub.remaining_meal_credits ?? 0;
    if (currentCredits <= 0) {
      return {
        success: false,
        slot: activeSlot,
        message: 'No meal credits remaining in your active tracker plan. Please renew.',
      };
    }
    newCredits = currentCredits - 1;
    activeSub.remaining_meal_credits = newCredits;
    if (newCredits === 0) {
      activeSub.status = 'expired';
    }
  }

  // 4. Calculate optional extras cost
  let extraPaise = 0;
  const extrasList = params.extras || [];
  for (const extra of extrasList) {
    const qty = extra.quantity && extra.quantity > 0 ? extra.quantity : 1;
    extraPaise += Math.round(extra.price * 100 * qty);
  }

  // 5. Record Redemption
  const redemptionId = `red-${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
  const now = new Date();
  const timeFormatted = now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });

  platformStore.redemptions.set(redemptionId, {
    id: redemptionId,
    user_id: params.userId,
    customer_name: activeSub.customer_name || 'Student',
    customer_phone: activeSub.customer_phone || '',
    plan_name: activeSub.plan_name,
    remaining_credits: newCredits,
    time_formatted: timeFormatted,
    provider_id: providerId,
    subscription_id: activeSub.id,
    date: today,
    slot: activeSlot,
    amount_extra_paise: extraPaise,
    extra_items: extrasList,
    redeemed_at: now.toISOString(),
  });

  // 6. Update Provider scan count for usage-based billing
  const scanRecord = platformStore.providerScanCounts.get(providerId) || { total: 0, unbilled: 0 };
  scanRecord.total += 1;
  scanRecord.unbilled += 1;
  platformStore.providerScanCounts.set(providerId, scanRecord);

  // 7. Add In-App Notification for customer
  const notifId = `notif-${Date.now()}`;
  platformStore.notifications.set(notifId, {
    id: notifId,
    customer_id: params.userId,
    title: `Meal Redeemed: ${activeSlot}`,
    message: `Your ${activeSlot} meal was redeemed successfully.${newCredits !== null ? ` Remaining meals: ${newCredits}.` : ''}`,
    notification_type: 'meal_redemption',
    is_read: false,
    created_at: new Date().toISOString(),
  });

  return {
    success: true,
    slot: activeSlot,
    remaining_credits: newCredits,
    amount_extra: extraPaise / 100,
    redemption_id: redemptionId,
    message: `Meal successfully redeemed for ${activeSlot}!${extraPaise > 0 ? ` Extras added: ₹${extraPaise / 100}` : ''}`,
  };
}

/** Provider Check-In Flow: Provider scans customer ID / QR code */
export function processStudentCheckin(params: {
  providerId: string;
  studentIdOrQr: string;
  slot?: string;
}): {
  success: boolean;
  student_id: string;
  slot: string;
  plan_type?: string;
  remaining_credits?: number | null;
  message: string;
} {
  const activeSlot = params.slot || getCurrentMealSlot();
  const today = getIndiaDateString();

  // Extract student id from QR payload or direct string
  let studentId = params.studentIdOrQr.trim();
  if (studentId.includes('|')) {
    studentId = studentId.split('|')[0];
  }

  // 1. Check duplicate checkin
  const alreadyRedeemed = Array.from(platformStore.redemptions.values()).find(
    (r) => r.user_id === studentId && r.provider_id === params.providerId && r.date === today && r.slot === activeSlot
  );

  if (alreadyRedeemed) {
    return {
      success: false,
      student_id: studentId,
      slot: activeSlot,
      message: `Student already checked in for ${activeSlot} today.`,
    };
  }

  // 2. Check active subscription
  const activeSub = Array.from(platformStore.subscriptions.values()).find(
    (s) => s.customer_id === studentId && s.provider_id === params.providerId && s.status === 'active'
  );

  if (!activeSub) {
    return {
      success: false,
      student_id: studentId,
      slot: activeSlot,
      message: 'No active meal plan found for this student at your mess.',
    };
  }

  // 3. Deduct credit if Tracker plan
  let newCredits: number | null = null;
  if (activeSub.plan_type === 'meal_credits') {
    const currentCredits = activeSub.remaining_meal_credits ?? 0;
    if (currentCredits <= 0) {
      return {
        success: false,
        student_id: studentId,
        slot: activeSlot,
        message: 'Student has zero meal credits remaining.',
      };
    }
    newCredits = currentCredits - 1;
    activeSub.remaining_meal_credits = newCredits;
    if (newCredits === 0) activeSub.status = 'expired';
  }

  // 4. Record redemption
  const redId = `red-staff-${Date.now()}`;
  platformStore.redemptions.set(redId, {
    id: redId,
    user_id: studentId,
    provider_id: params.providerId,
    subscription_id: activeSub.id,
    date: today,
    slot: activeSlot,
    amount_extra_paise: 0,
    extra_items: [],
    remarks: 'Counter staff manual check-in',
    redeemed_at: new Date().toISOString(),
  });

  const scanRecord = platformStore.providerScanCounts.get(params.providerId) || { total: 0, unbilled: 0 };
  scanRecord.total += 1;
  scanRecord.unbilled += 1;
  platformStore.providerScanCounts.set(params.providerId, scanRecord);

  return {
    success: true,
    student_id: studentId,
    slot: activeSlot,
    plan_type: activeSub.plan_type,
    remaining_credits: newCredits,
    message: `Student verified & checked in for ${activeSlot}!`,
  };
}

/** Validate promo code and calculate discount */
export function validateAndApplyPromo(params: {
  code: string;
  orderAmountPaise: number;
}): {
  isValid: boolean;
  code: string;
  discountPaise: number;
  finalAmountPaise: number;
  message: string;
} {
  const promo = platformStore.promos.get(params.code.trim().toUpperCase());
  if (!promo || !promo.is_active) {
    return {
      isValid: false,
      code: params.code,
      discountPaise: 0,
      finalAmountPaise: params.orderAmountPaise,
      message: 'Invalid or expired promo code.',
    };
  }

  if (params.orderAmountPaise < promo.min_order_paise) {
    return {
      isValid: false,
      code: promo.code,
      discountPaise: 0,
      finalAmountPaise: params.orderAmountPaise,
      message: `Minimum order amount of ₹${promo.min_order_paise / 100} required to use code ${promo.code}.`,
    };
  }

  let discount = 0;
  if (promo.discount_percent) {
    discount = Math.round((params.orderAmountPaise * promo.discount_percent) / 100);
    if (promo.max_discount_paise && discount > promo.max_discount_paise) {
      discount = promo.max_discount_paise;
    }
  } else if (promo.flat_discount_paise) {
    discount = promo.flat_discount_paise;
  }

  const finalAmount = Math.max(0, params.orderAmountPaise - discount);
  return {
    isValid: true,
    code: promo.code,
    discountPaise: discount,
    finalAmountPaise: finalAmount,
    message: `Promo code ${promo.code} applied! Saved ₹${discount / 100}.`,
  };
}

/** Usage-Based Billing Job: ₹25 per 90 scans */
export function executeProviderBillingJob(): {
  invoicesGenerated: number;
  totalBilledPaise: number;
  invoices: InvoiceData[];
} {
  let invoicesGenerated = 0;
  let totalBilledPaise = 0;
  const createdInvoices: InvoiceData[] = [];

  for (const [providerId, stats] of platformStore.providerScanCounts.entries()) {
    if (stats.unbilled >= 90) {
      const blocksOf90 = Math.floor(stats.unbilled / 90);
      const feeInr = blocksOf90 * APP_CONFIG.monetization.feePerStartedBlockInr; // 25 per 90
      const feePaise = feeInr * 100;
      const billedScans = blocksOf90 * 90;

      const invoiceId = `inv-${providerId}-${Date.now()}`;
      const invoice: InvoiceData = {
        id: invoiceId,
        provider_id: providerId,
        period_start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
        period_end: new Date().toISOString(),
        total_scans: billedScans,
        total_due_paise: feePaise,
        razorpay_invoice_id: `rzp_inv_${crypto.randomBytes(6).toString('hex')}`,
        status: 'paid', // Auto-collected via UPI AutoPay / e-mandate
        paid_at: new Date().toISOString(),
        created_at: new Date().toISOString(),
      };

      platformStore.invoices.set(invoiceId, invoice);
      stats.unbilled -= billedScans;
      invoicesGenerated += 1;
      totalBilledPaise += feePaise;
      createdInvoices.push(invoice);
    }
  }

  return {
    invoicesGenerated,
    totalBilledPaise,
    invoices: createdInvoices,
  };
}
