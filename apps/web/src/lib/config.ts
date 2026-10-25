// ==============================================================================
// BRAND, MONETIZATION & PLATFORM CONFIGURATION
// Configurable brand name (never hardcoded), Indian localization, commission rules
// ==============================================================================

export const APP_CONFIG = {
  brandName: process.env.NEXT_PUBLIC_BRAND_NAME || 'Thali',
  tagline: process.env.NEXT_PUBLIC_BRAND_TAGLINE || 'Your Meals. Your Choice.',
  currency: {
    symbol: process.env.NEXT_PUBLIC_CURRENCY_SYMBOL || '₹',
    code: 'INR',
    locale: 'en-IN',
  },
  timezone: process.env.NEXT_PUBLIC_TIMEZONE || 'Asia/Kolkata',
  defaultCity: process.env.NEXT_PUBLIC_DEFAULT_CITY || '',
  cities: [] as string[],

  // Per-provider, per-local-day usage fee. Only successful unique redemptions count.
  monetization: {
    feePerStartedBlockInr: 25,
    successfulRedemptionsPerBlock: 90,
  },

  // QR Code Security Rules (Section 6)
  qrSecurity: {
    validityWindowMinutes: 5, // 5-minute strictly timed validity
    refreshIntervalSeconds: 30, // Proactive refresh
  },
} as const;

export function formatCurrency(amount: number): string {
  return `${APP_CONFIG.currency.symbol}${amount.toLocaleString('en-IN', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  })}`;
}

/** ₹25 for 1–90 successful redemptions, ₹50 for 91–180, and so on. */
export function calculateProviderDailyUsageFee(
  successfulUniqueRedemptions: number,
  feePerStartedBlockInr: number = APP_CONFIG.monetization.feePerStartedBlockInr,
): number {
  if (!Number.isInteger(successfulUniqueRedemptions) || successfulUniqueRedemptions < 0) {
    throw new Error('successfulUniqueRedemptions must be a non-negative integer');
  }
  if (!Number.isInteger(feePerStartedBlockInr) || feePerStartedBlockInr < 0) {
    throw new Error('feePerStartedBlockInr must be a non-negative integer');
  }
  if (successfulUniqueRedemptions === 0) return 0;
  return Math.ceil(successfulUniqueRedemptions / APP_CONFIG.monetization.successfulRedemptionsPerBlock)
    * feePerStartedBlockInr;
}

export function isProviderUsageBillable(input: {
  usageBillingEnabled: boolean;
  billingExempt: boolean;
  trialEndsAt: string | Date | null;
  usageAt: string | Date;
}): boolean {
  if (!input.usageBillingEnabled || input.billingExempt || !input.trialEndsAt) return false;
  const trialEnd = new Date(input.trialEndsAt).getTime();
  const usageTime = new Date(input.usageAt).getTime();
  return Number.isFinite(trialEnd) && Number.isFinite(usageTime) && usageTime > trialEnd;
}

export function calculateProviderBillableFee(input: {
  successfulUniqueRedemptions: number;
  usageBillingEnabled: boolean;
  billingExempt: boolean;
  trialEndsAt: string | Date | null;
  usageAt: string | Date;
  feePerStartedBlockInr?: number;
}): number {
  return isProviderUsageBillable(input)
    ? calculateProviderDailyUsageFee(input.successfulUniqueRedemptions, input.feePerStartedBlockInr)
    : 0;
}
