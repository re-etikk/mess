import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { addPartnerNotification } from '@/lib/partner-notifications';
import { ensurePlanSlotsLinked, requireCustomerIdentity } from '@/lib/auth-session';
import {
  resolveAuthoritativeDiscountPaise,
  resolveAuthoritativeSingleMealOrder,
} from '@/lib/checkout-pricing';
import { getPlatformAppConfig } from '@/lib/app-config';
import { recordPromoRedemption } from '@/lib/promo-engine';

export const dynamic = 'force-dynamic';

/**
 * Registers a single-meal counter-cash / pay-on-delivery order in `pending_payment` status.
 * Authoritative price comes strictly from kitchen per-meal slot pricing + verified menu items/add-ons.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = String(body.provider_id || '').trim();
    const slot = String(body.slot || 'LUNCH').toUpperCase().trim();
    const claimedCustomerId = String(body.customer_id || '').trim();
    const customerName = String(body.customer_name || '').trim().slice(0, 80) || 'Customer';
    const customerPhone = String(body.customer_phone || '').replace(/\D/g, '').slice(-10);
    const selectedSlots = body.selected_slots && typeof body.selected_slots === 'object' ? body.selected_slots : null;
    const requestedFulfillment = String(body.fulfillment_mode || '').trim();
    const packagingPreference = String(body.packaging_preference || 'reusable_tiffin').trim();
    const deliveryAddress = String(body.delivery_address || '').trim().slice(0, 300);
    const deliveryInstructions = String(body.delivery_instructions || '').trim().slice(0, 500);
    const promoCode = String(body.promo_code || '').trim();

    if (!providerId) {
      return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
    }

    const auth = await requireCustomerIdentity(req, claimedCustomerId || undefined);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }
    const customerId = auth.userId;

    const admin = getAdminClient();
    let providerDisplayName = 'Mess Partner';
    let providerSupportsDelivery = false;
    let disposableFeePaise = 500;

    if (admin) {
      const { data: provider } = await admin
        .from('providers')
        .select('id, display_name, status, supports_delivery, disposable_fee_paise')
        .eq('id', providerId)
        .maybeSingle();

      if (!provider) {
        return NextResponse.json({ success: false, error: 'Kitchen not found.' }, { status: 404 });
      }
      if (provider.status === 'suspended' || provider.status === 'rejected') {
        return NextResponse.json({ success: false, error: 'This kitchen is currently unavailable for new orders.' }, { status: 403 });
      }
      providerDisplayName = provider.display_name || 'Mess Partner';
      providerSupportsDelivery = provider.supports_delivery === true;
      disposableFeePaise = Math.max(0, Number(provider.disposable_fee_paise ?? 500));
    } else {
      const storeProv = platformStore.providers.get(providerId);
      if (storeProv) {
        providerDisplayName = storeProv.display_name;
        providerSupportsDelivery = (storeProv as any).supports_delivery === true;
      }
    }

    const effectiveFulfillmentMode: 'pickup' | 'delivery' =
      providerSupportsDelivery && requestedFulfillment === 'delivery' ? 'delivery' : 'pickup';

    const resolved = await resolveAuthoritativeSingleMealOrder({
      admin,
      providerId,
      selectedSlots,
      fallbackSlot: slot,
    });
    if (!resolved.ok) {
      return NextResponse.json({ success: false, error: resolved.error }, { status: resolved.status });
    }

    const appCfg = await getPlatformAppConfig(admin);
    const packagingFeePaise =
      effectiveFulfillmentMode === 'delivery' && packagingPreference === 'disposable'
        ? disposableFeePaise * resolved.totalMealsCount
        : 0;
    const baseMealGross = resolved.baseMealsPaise + resolved.verifiedAddOnsPaise + packagingFeePaise;
    const deliveryFeePaise =
      effectiveFulfillmentMode === 'delivery' &&
      appCfg.default_delivery_fee_paise > 0 &&
      (appCfg.free_delivery_above_paise <= 0 || baseMealGross < appCfg.free_delivery_above_paise)
        ? appCfg.default_delivery_fee_paise
        : 0;
    const platformFeePaise = appCfg.platform_fee_paise > 0 ? appCfg.platform_fee_paise : 0;
    const grossPaise = baseMealGross + deliveryFeePaise + platformFeePaise;
    const promoRes = await resolveAuthoritativeDiscountPaise({
      admin,
      providerId,
      promoCode,
      orderAmountPaise: grossPaise,
      customerId,
      orderContext: 'daily',
    });
    const finalPricePaise = Math.max(0, grossPaise - promoRes.discountPaise);
    const planDisplayName = `Single Order (${resolved.itemsSummary})`;

    let dailyPlanId: string | null = null;
    if (admin) {
      const { data: dailyPlan } = await admin
        .from('subscription_plans')
        .select('id, terms_version')
        .eq('provider_id', providerId)
        .eq('plan_type', 'meal_credits')
        .eq('meal_credits', 1)
        .eq('published', false)
        .eq('active', true)
        .maybeSingle();

      if (dailyPlan) {
        dailyPlanId = dailyPlan.id;
      } else {
        const { data: createdPlan, error: planErr } = await admin
          .from('subscription_plans')
          .insert({
            provider_id: providerId,
            name: 'Pay-Per-Meal Single Order',
            description: 'Single meal order for today',
            plan_type: 'meal_credits',
            duration_months: null,
            meal_credits: 1,
            price_paise: Math.max(100, resolved.baseMealsPaise),
            daily_meal_limit: 5,
            cancellation_policy: 'Valid for today only.',
            missed_meal_policy: 'Unused single order expires after today.',
            published: false,
            active: true,
          })
          .select('id')
          .single();

        if (planErr || !createdPlan) {
          return NextResponse.json({ success: false, error: 'Could not register single meal order.' }, { status: 500 });
        }
        dailyPlanId = createdPlan.id;
      }
      await ensurePlanSlotsLinked(admin, providerId);
    }

    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const subId = admin && isUuid.test(customerId) && dailyPlanId ? crypto.randomUUID() : `single-${Date.now()}-${crypto.randomBytes(2).toString('hex')}`;

    if (admin && isUuid.test(customerId) && dailyPlanId) {
      const baseInsert = {
        id: subId,
        customer_id: customerId,
        provider_id: providerId,
        plan_id: dailyPlanId,
        status: 'pending_payment',
        plan_type_snapshot: 'meal_credits',
        plan_name_snapshot: planDisplayName.slice(0, 120),
        terms_version_snapshot: '1',
        price_paid_paise: finalPricePaise,
        initial_meal_credits: resolved.totalMealsCount,
        remaining_meal_credits: resolved.totalMealsCount,
        starts_at: now.toISOString(),
        expires_at: expiresAt.toISOString(),
        payment_mode: 'counter_cash',
      };
      const extRes = await admin
        .from('subscriptions')
        .insert({
          ...baseInsert,
          duration_days: 1,
          selected_slots: resolved.normalizedSelectedSlots,
          fulfillment_mode: effectiveFulfillmentMode,
          packaging_preference: packagingPreference,
          delivery_address: deliveryAddress || null,
          delivery_instructions: deliveryInstructions || null,
          promo_code: promoRes.code || null,
          discount_paise: promoRes.discountPaise,
        })
        .select('*')
        .single();

      if (extRes.error) {
        const fbRes = await admin.from('subscriptions').insert(baseInsert).select('*').single();
        if (fbRes.error || !fbRes.data) {
          return NextResponse.json({ success: false, error: 'Could not register single meal order.' }, { status: 500 });
        }
      }
    }

    platformStore.subscriptions.set(subId, {
      id: subId,
      customer_id: customerId,
      customer_name: customerName,
      customer_phone: customerPhone,
      provider_id: providerId,
      plan_id: dailyPlanId || 'single-meal-pass',
      plan_type: 'meal_credits',
      plan_name: planDisplayName,
      status: 'pending_payment',
      starts_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      remaining_meal_credits: resolved.totalMealsCount,
      initial_meal_credits: resolved.totalMealsCount,
      price_paid_paise: finalPricePaise,
      payment_mode: 'counter_cash',
      fulfillment_mode: effectiveFulfillmentMode,
      delivery_address: deliveryAddress,
      created_at: now.toISOString(),
      ...({
        duration_days: 1,
        selected_slots: resolved.normalizedSelectedSlots,
        packaging_preference: packagingPreference,
        delivery_instructions: deliveryInstructions,
      } as any),
    });

    const amountInr = Math.round(finalPricePaise / 100);
    addPartnerNotification({
      provider_id: providerId,
      type: 'pending_payment',
      title: 'Single Meal Cash Order',
      message: `${customerName} ordered ${resolved.itemsSummary} (₹${amountInr}) via Counter Cash. Collect cash and approve.`,
      customer_name: customerName,
      customer_phone: customerPhone,
      amount_inr: amountInr,
      subscription_id: subId,
    });

    if (promoRes.code && promoRes.discountPaise > 0) {
      await recordPromoRedemption({
        admin,
        code: promoRes.code,
        customerId,
        providerId,
        subscriptionId: subId,
        discountPaise: promoRes.discountPaise,
      });
    }

    return NextResponse.json({
      success: true,
      entitlement: {
        id: subId,
        provider_id: providerId,
        provider_name: providerDisplayName,
        plan_name: planDisplayName,
        slot,
        items_summary: resolved.itemsSummary,
        payment_method: 'counter_cash',
        status: 'pending_payment',
        amount_inr: amountInr,
        is_paid: false,
      },
      message: `Single meal order (₹${amountInr}) submitted. Pay at counter/delivery once confirmed.`,
    });
  } catch (err: any) {
    console.error('Daily purchase API error:', err?.message);
    return NextResponse.json(
      { success: false, error: 'Unable to submit single meal order right now.' },
      { status: 500 }
    );
  }
}
