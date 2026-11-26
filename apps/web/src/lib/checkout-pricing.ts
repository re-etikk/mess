import { platformStore, validateAndApplyPromo } from './platform-service';
import type { getAdminClient } from './supabase/admin';

type AdminClient = NonNullable<ReturnType<typeof getAdminClient>>;

export interface AuthoritativePlan {
  id: string;
  provider_id: string;
  name: string;
  plan_type: 'fixed_period' | 'meal_credits';
  duration_days: number;
  meal_credits: number | null;
  price_paise: number;
  terms_version: string;
}

export async function resolveAuthoritativePlan({
  admin,
  providerId,
  planId,
}: {
  admin: AdminClient | null;
  providerId: string;
  planId: string;
}): Promise<AuthoritativePlan | null> {
  let plan: any = null;
  if (admin && planId) {
    try {
      const { data } = await admin
        .from('subscription_plans')
        .select('*')
        .eq('id', planId)
        .eq('provider_id', providerId)
        .maybeSingle();
      if (data) plan = data;
    } catch {}
  }

  if (!plan && planId) {
    const storePlan = platformStore.plans.get(planId);
    if (storePlan && (!providerId || storePlan.provider_id === providerId)) {
      plan = storePlan;
    }
  }

  if (!plan) return null;

  const isCredits = plan.plan_type === 'meal_credits';
  const durationDays = isCredits
    ? Math.max(30, Number(plan.duration_days || plan.meal_credits || 30))
    : Math.max(1, Number(plan.duration_days || 0) || Math.max(1, Number(plan.duration_months || 1)) * 30);

  const basePrice = Number(plan.price_paise || 0);
  const promoPrice = Number(plan.promo_price_paise || 0);
  const pricePaise = promoPrice > 0 && promoPrice <= basePrice ? promoPrice : basePrice;

  return {
    id: plan.id,
    provider_id: plan.provider_id || providerId,
    name: plan.name || `${durationDays}-Day Meal Pass`,
    plan_type: isCredits ? 'meal_credits' : 'fixed_period',
    duration_days: durationDays,
    meal_credits: isCredits ? Math.max(1, Number(plan.meal_credits || 30)) : null,
    price_paise: Math.max(0, pricePaise),
    terms_version: String(plan.terms_version || '1'),
  };
}

export async function resolveAuthoritativeDiscountPaise({
  admin,
  providerId,
  promoCode,
  orderAmountPaise,
}: {
  admin: AdminClient | null;
  providerId: string;
  promoCode?: string | null;
  orderAmountPaise: number;
}): Promise<{ code: string; discountPaise: number; valid: boolean }> {
  const cleanCode = String(promoCode || '').trim().toUpperCase();
  if (!cleanCode || orderAmountPaise <= 0) {
    return { code: '', discountPaise: 0, valid: true };
  }

  if (admin) {
    try {
      const { data: promo } = await admin
        .from('promo_codes')
        .select('*')
        .eq('code', cleanCode)
        .eq('is_active', true)
        .maybeSingle();

      if (promo) {
        if (promo.provider_id && promo.provider_id !== providerId) {
          return { code: cleanCode, discountPaise: 0, valid: false };
        }
        const now = Date.now();
        if (promo.valid_until && new Date(promo.valid_until).getTime() < now) {
          return { code: cleanCode, discountPaise: 0, valid: false };
        }
        if (promo.min_order_paise && orderAmountPaise < Number(promo.min_order_paise)) {
          return { code: cleanCode, discountPaise: 0, valid: false };
        }
        let disc = 0;
        if (promo.flat_discount_paise) {
          disc = Number(promo.flat_discount_paise);
        } else if (promo.discount_percent) {
          disc = Math.round((orderAmountPaise * Number(promo.discount_percent)) / 100);
          if (promo.max_discount_paise) {
            disc = Math.min(disc, Number(promo.max_discount_paise));
          }
        }
        return {
          code: cleanCode,
          discountPaise: Math.min(orderAmountPaise, Math.max(0, disc)),
          valid: disc > 0,
        };
      }
    } catch {}
  }

  const fallback = validateAndApplyPromo({ code: cleanCode, orderAmountPaise });
  return {
    code: cleanCode,
    discountPaise: fallback.isValid ? Math.min(orderAmountPaise, fallback.discountPaise) : 0,
    valid: fallback.isValid,
  };
}

export async function resolveVerifiedUpgradeQuote({
  admin,
  subscriptionId,
  customerId,
  isAdmin,
  targetPlan,
}: {
  admin: AdminClient | null;
  subscriptionId: string;
  customerId: string;
  isAdmin: boolean;
  targetPlan: AuthoritativePlan;
}) {
  let currentSub: any = null;
  if (admin && subscriptionId) {
    try {
      const { data } = await admin
        .from('subscriptions')
        .select('*, profiles:customer_id(display_name, phone_e164)')
        .eq('id', subscriptionId)
        .maybeSingle();
      if (data) currentSub = data;
    } catch {}
  }
  if (!currentSub && subscriptionId) {
    currentSub = platformStore.subscriptions.get(subscriptionId);
  }

  if (!currentSub) {
    return { ok: false as const, status: 404 as const, error: 'Active subscription to upgrade was not found.' };
  }
  if (!isAdmin && currentSub.customer_id !== customerId) {
    return { ok: false as const, status: 403 as const, error: 'You cannot upgrade another user subscription.' };
  }
  if (currentSub.status !== 'active') {
    return { ok: false as const, status: 400 as const, error: 'Only active subscriptions can be upgraded.' };
  }

  const now = Date.now();
  const expiresMs = currentSub.expires_at ? new Date(currentSub.expires_at).getTime() : now;
  const startsMs = currentSub.starts_at ? new Date(currentSub.starts_at).getTime() : now - 30 * 86400000;
  const remainingMs = Math.max(0, expiresMs - now);
  const remainingDays = Math.ceil(remainingMs / 86400000);
  const totalDays = Math.max(1, Number(currentSub.duration_days || 0) || Math.ceil((expiresMs - startsMs) / 86400000));
  const pricePaidPaise = Math.max(0, Number(currentSub.price_paid_paise || 0));

  let unusedFraction = 0;
  const pType = currentSub.plan_type || currentSub.plan_type_snapshot;
  if (pType === 'meal_credits') {
    const remainingCredits = Number(currentSub.remaining_meal_credits ?? 0);
    const initialCredits = Math.max(1, Number(currentSub.initial_meal_credits ?? 30));
    unusedFraction = Math.min(1, Math.max(0, remainingCredits / initialCredits));
  } else {
    unusedFraction = Math.min(1, Math.max(0, remainingDays / totalDays));
  }

  const residualCreditPaise = Math.round(pricePaidPaise * unusedFraction);
  const payablePaise = Math.max(0, targetPlan.price_paise - residualCreditPaise);

  return {
    ok: true as const,
    currentSub,
    remainingDays,
    residualCreditPaise,
    payablePaise,
  };
}
