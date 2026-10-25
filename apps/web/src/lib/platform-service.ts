import crypto from 'crypto';
import { APP_CONFIG, calculateProviderDailyUsageFee } from './config';
import { getIndiaDateString, verifyCounterQRToken, verifySignedQRToken } from './crypto';

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
  is_active: boolean;
  created_at: string;
}

export interface MenuData {
  id: string;
  provider_id: string;
  day_of_week: string;
  slot: string;
  items_included: string[];
  items_extra: { name: string; price: number; limit?: number }[];
  is_active: boolean;
  updated_at: string;
}

export interface SubscriptionData {
  id: string;
  customer_id: string;
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
  created_at: string;
}

export interface RedemptionData {
  id: string;
  user_id: string;
  provider_id: string;
  subscription_id?: string;
  date: string;
  slot: string;
  amount_extra_paise: number;
  extra_items: { name: string; price: number; quantity?: number }[];
  remarks?: string;
  redeemed_at: string;
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
  status: 'draft' | 'pending_review' | 'active' | 'rejected' | 'suspended';
  created_at: string;
}

// In-Memory store for fast, reliable testing & staging execution
class PlatformStore {
  providers: Map<string, ProviderData> = new Map();
  plans: Map<string, PlanData> = new Map();
  menus: Map<string, MenuData> = new Map();
  subscriptions: Map<string, SubscriptionData> = new Map();
  redemptions: Map<string, RedemptionData> = new Map();
  invoices: Map<string, InvoiceData> = new Map();
  providerScanCounts: Map<string, { total: number; unbilled: number }> = new Map();

  constructor() {
    this.seedDemoData();
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
      status: 'active',
      created_at: new Date().toISOString(),
    });

    // Plans
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
      price_paise: 480000, // ₹4,800
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

    // Demo Subscription for customer
    const demoSubId = 'sub-cust-001';
    this.subscriptions.set(demoSubId, {
      id: demoSubId,
      customer_id: 'cust-ritik-001',
      provider_id: provId,
      plan_id: trackerPlanId,
      plan_type: 'meal_credits',
      plan_name: '60-Meal Flexi Tracker Pack',
      status: 'active',
      starts_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 60 * 24 * 60 * 60 * 1000).toISOString(),
      remaining_meal_credits: 42,
      initial_meal_credits: 60,
      price_paid_paise: 480000,
      created_at: new Date().toISOString(),
    });

    this.providerScanCounts.set(provId, { total: 185, unbilled: 95 });
  }
}

export const platformStore = new PlatformStore();

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
    return { success: false, message: error || 'QR code is expired for today.' };
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
  platformStore.redemptions.set(redemptionId, {
    id: redemptionId,
    user_id: params.userId,
    provider_id: providerId,
    subscription_id: activeSub.id,
    date: today,
    slot: activeSlot,
    amount_extra_paise: extraPaise,
    extra_items: extrasList,
    redeemed_at: new Date().toISOString(),
  });

  // 6. Update Provider scan count for usage-based billing
  const scanRecord = platformStore.providerScanCounts.get(providerId) || { total: 0, unbilled: 0 };
  scanRecord.total += 1;
  scanRecord.unbilled += 1;
  platformStore.providerScanCounts.set(providerId, scanRecord);

  return {
    success: true,
    slot: activeSlot,
    remaining_credits: newCredits,
    amount_extra: extraPaise / 100,
    redemption_id: redemptionId,
    message: `Meal successfully redeemed for ${activeSlot}!${extraPaise > 0 ? ` Extras added: ₹${extraPaise / 100}` : ''}`,
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
