import type { SupabaseClient } from '@supabase/supabase-js';
import { platformStore, validateAndApplyPromo } from './platform-service';

export interface PromoEvaluationResult {
  isValid: boolean;
  code: string;
  title?: string;
  promoId?: string | null;
  discountPaise: number;
  finalAmountPaise: number;
  message: string;
}

export interface EvaluatePromoParams {
  admin: SupabaseClient<any> | null;
  code: string;
  orderAmountPaise: number;
  providerId?: string;
  customerId?: string;
  orderContext?: 'plan' | 'daily';
}

export async function evaluatePromoCode(params: EvaluatePromoParams): Promise<PromoEvaluationResult> {
  const cleanCode = String(params.code || '').trim().toUpperCase();
  const orderAmountPaise = Math.max(0, Math.round(Number(params.orderAmountPaise || 0)));

  if (!cleanCode) {
    return {
      isValid: false,
      code: '',
      discountPaise: 0,
      finalAmountPaise: orderAmountPaise,
      message: 'Promo code is required.',
    };
  }

  let promo: any = null;
  if (params.admin) {
    try {
      const { data } = await params.admin
        .from('promo_codes')
        .select('*')
        .eq('code', cleanCode)
        .eq('is_active', true)
        .maybeSingle();
      if (data) promo = data;
    } catch {}
  }

  if (!promo) {
    const storePromo = platformStore.promos.get(cleanCode);
    if (storePromo && storePromo.is_active) {
      promo = storePromo;
    }
  }

  if (!promo) {
    const fallback = validateAndApplyPromo({ code: cleanCode, orderAmountPaise });
    return {
      isValid: fallback.isValid,
      code: fallback.code,
      discountPaise: fallback.discountPaise,
      finalAmountPaise: fallback.finalAmountPaise,
      message: fallback.message,
    };
  }

  if (promo.provider_id && params.providerId && promo.provider_id !== params.providerId) {
    return {
      isValid: false,
      code: cleanCode,
      discountPaise: 0,
      finalAmountPaise: orderAmountPaise,
      message: 'Promo code is valid for another mess kitchen only.',
    };
  }

  if (params.orderContext === 'plan' && promo.applicable_to_plans === false) {
    return {
      isValid: false,
      code: cleanCode,
      discountPaise: 0,
      finalAmountPaise: orderAmountPaise,
      message: 'This promo code applies only to single-meal orders.',
    };
  }
  if (params.orderContext === 'daily' && promo.applicable_to_daily === false) {
    return {
      isValid: false,
      code: cleanCode,
      discountPaise: 0,
      finalAmountPaise: orderAmountPaise,
      message: 'This promo code applies only to subscription plans.',
    };
  }

  const now = Date.now();
  if (promo.valid_from && new Date(promo.valid_from).getTime() > now) {
    return {
      isValid: false,
      code: cleanCode,
      discountPaise: 0,
      finalAmountPaise: orderAmountPaise,
      message: 'This promo offer has not started yet.',
    };
  }
  if (promo.valid_until && new Date(promo.valid_until).getTime() < now) {
    return {
      isValid: false,
      code: cleanCode,
      discountPaise: 0,
      finalAmountPaise: orderAmountPaise,
      message: 'This promo code has expired.',
    };
  }

  if (promo.usage_limit && Number(promo.times_used || 0) >= Number(promo.usage_limit)) {
    return {
      isValid: false,
      code: cleanCode,
      discountPaise: 0,
      finalAmountPaise: orderAmountPaise,
      message: 'Promo code redemption limit has been reached.',
    };
  }

  if (params.admin && params.customerId) {
    if (promo.first_order_only === true) {
      try {
        const { count } = await params.admin
          .from('subscriptions')
          .select('id', { count: 'exact', head: true })
          .eq('customer_id', params.customerId)
          .in('status', ['active', 'paused', 'expired', 'pending_payment']);
        if ((count ?? 0) > 0) {
          return {
            isValid: false,
            code: cleanCode,
            discountPaise: 0,
            finalAmountPaise: orderAmountPaise,
            message: 'This promo code is valid on your first order only.',
          };
        }
      } catch {}
    }

    if (promo.max_uses_per_user && Number(promo.max_uses_per_user) > 0) {
      try {
        const { count } = await params.admin
          .from('promo_redemptions')
          .select('id', { count: 'exact', head: true })
          .eq('code', cleanCode)
          .eq('customer_id', params.customerId);
        if ((count ?? 0) >= Number(promo.max_uses_per_user)) {
          return {
            isValid: false,
            code: cleanCode,
            discountPaise: 0,
            finalAmountPaise: orderAmountPaise,
            message: 'You have already used this promo code the maximum number of times.',
          };
        }
      } catch {}
    }
  }

  const minOrderPaise = Number(promo.min_order_paise || 0);
  if (orderAmountPaise < minOrderPaise) {
    return {
      isValid: false,
      code: cleanCode,
      discountPaise: 0,
      finalAmountPaise: orderAmountPaise,
      message: `Minimum order amount of ₹${Math.round(minOrderPaise / 100)} required to use code ${cleanCode}.`,
    };
  }

  // Unified discount precedence across validation and checkout
  let discountPaise = 0;
  if (Number(promo.flat_discount_paise || 0) > 0) {
    discountPaise = Math.round(Number(promo.flat_discount_paise));
  } else if (Number(promo.discount_percent || 0) > 0) {
    discountPaise = Math.round((orderAmountPaise * Number(promo.discount_percent)) / 100);
    if (promo.max_discount_paise && Number(promo.max_discount_paise) > 0) {
      discountPaise = Math.min(discountPaise, Math.round(Number(promo.max_discount_paise)));
    }
  }

  discountPaise = Math.max(0, Math.min(orderAmountPaise, discountPaise));
  const finalAmountPaise = Math.max(0, orderAmountPaise - discountPaise);

  return {
    isValid: discountPaise > 0,
    code: String(promo.code || cleanCode),
    title: promo.title ? String(promo.title) : undefined,
    promoId: promo.id ? String(promo.id) : null,
    discountPaise,
    finalAmountPaise,
    message: discountPaise > 0 ? `Saved ₹${Math.round(discountPaise / 100)} with ${cleanCode}!` : 'Promo code is not applicable.',
  };
}

export async function recordPromoRedemption(params: {
  admin: SupabaseClient<any> | null;
  code?: string | null;
  customerId: string;
  providerId?: string | null;
  subscriptionId?: string | null;
  discountPaise: number;
}): Promise<void> {
  const cleanCode = String(params.code || '').trim().toUpperCase();
  if (!cleanCode || params.discountPaise <= 0) return;

  const storePromo = platformStore.promos.get(cleanCode);
  if (storePromo) {
    storePromo.times_used = Number((storePromo as any).times_used || 0) + 1;
    platformStore.promos.set(cleanCode, storePromo);
  }

  if (!params.admin) return;
  try {
    const { data: promo } = await params.admin
      .from('promo_codes')
      .select('id,times_used')
      .eq('code', cleanCode)
      .maybeSingle();

    if (promo?.id) {
      await params.admin
        .from('promo_codes')
        .update({ times_used: Number(promo.times_used || 0) + 1 })
        .eq('id', promo.id);
    }

    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (isUuid.test(params.customerId)) {
      await params.admin.from('promo_redemptions').insert({
        promo_code_id: promo?.id || null,
        code: cleanCode,
        customer_id: params.customerId,
        provider_id: params.providerId && isUuid.test(params.providerId) ? params.providerId : null,
        subscription_id: params.subscriptionId && isUuid.test(params.subscriptionId) ? params.subscriptionId : null,
        discount_paise: Math.max(0, Math.round(params.discountPaise)),
      });
    }
  } catch {}
}
