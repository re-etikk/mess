import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';
import { createCashfreeOrder, cashfreeOrderStore, getCashfreeConfig } from '@/lib/cashfree';
import { platformStore } from '@/lib/platform-service';
import { ensurePlanSlotsLinked, requireCustomerIdentity } from '@/lib/auth-session';
import {
  resolveAuthoritativeDiscountPaise,
  resolveAuthoritativePlan,
  resolveAuthoritativeSingleMealOrder,
  resolveVerifiedUpgradeQuote,
} from '@/lib/checkout-pricing';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const cfg = getCashfreeConfig();
    if (!cfg.configured) {
      return NextResponse.json(
        {
          success: false,
          code: 'cashfree_not_configured',
          error: 'Cashfree Payment Gateway is not configured on the server.',
        },
        { status: 503 }
      );
    }

    const body = await req.json().catch(() => ({}));
    type CashfreePurpose = 'subscription_purchase' | 'plan_upgrade' | 'single_meal_purchase' | 'add_ons';
    const rawPurpose = String(body.purpose || 'subscription_purchase').trim();
    const purpose: CashfreePurpose =
      rawPurpose === 'plan_upgrade' || rawPurpose === 'single_meal_purchase' || rawPurpose === 'add_ons'
        ? rawPurpose
        : 'subscription_purchase';
    const providerIdParam = String(body.provider_id || '').trim();
    const planIdParam = String(body.target_plan_id || body.plan_id || '').trim();
    const subscriptionIdParam = String(body.subscription_id || '').trim();
    const claimedCustomerId = String(body.customer_id || '').trim();
    const customerName = String(body.customer_name || '').trim().slice(0, 80) || 'Thali Customer';
    const customerEmail = String(body.customer_email || '').trim();
    const customerPhone = String(body.customer_phone || '').replace(/\D/g, '').slice(-10);
    const slot = String(body.slot || 'LUNCH').toUpperCase().trim();
    const promoCode = String(body.promo_code || '').trim();
    const selectedSlots = body.selected_slots && typeof body.selected_slots === 'object' ? body.selected_slots : {};
    const repeatDays =
      Array.isArray(body.repeat_days) && body.repeat_days.length > 0
        ? body.repeat_days.map((d: any) => Number(d)).filter((d: number) => d >= 1 && d <= 7)
        : [1, 2, 3, 4, 5, 6, 7];
    const packagingPreference = String(body.packaging_preference || 'reusable_tiffin').trim();
    const requestedFulfillment = String(body.fulfillment_mode || '').trim();
    const deliveryAddress = String(body.delivery_address || '').trim().slice(0, 300);
    const deliveryInstructions = String(body.delivery_instructions || '').trim().slice(0, 500);
    const requestedStart = body.starts_at;

    const auth = await requireCustomerIdentity(req, claimedCustomerId || undefined);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }
    const resolvedCustomerId = auth.userId;

    if (!providerIdParam && purpose !== 'plan_upgrade') {
      return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
    }

    const admin = getAdminClient();
    const now = new Date();
    const siteBase = (process.env.NEXT_PUBLIC_SITE_URL || 'https://www.thali.store').replace(/\/$/, '');

    let resolvedProviderId = providerIdParam;
    let providerName = 'Mess Partner';
    let providerSupportsDelivery = false;
    let disposableFeePaise = 500;

    if (admin && resolvedProviderId) {
      try {
        const { data: prov } = await admin
          .from('providers')
          .select('id, display_name, supports_delivery, disposable_fee_paise')
          .eq('id', resolvedProviderId)
          .maybeSingle();
        if (prov) {
          providerName = prov.display_name;
          providerSupportsDelivery = prov.supports_delivery === true;
          disposableFeePaise = Math.max(0, Number(prov.disposable_fee_paise ?? 500));
        }
      } catch {}
    } else if (resolvedProviderId) {
      const sp = platformStore.providers.get(resolvedProviderId);
      if (sp) providerName = sp.display_name;
    }

    const effectiveFulfillmentMode: 'pickup' | 'delivery' =
      providerSupportsDelivery && requestedFulfillment === 'delivery' ? 'delivery' : 'pickup';

    let durDays = 30;
    let effectivePlanType: 'fixed_period' | 'meal_credits' = 'fixed_period';
    let effectivePlanName = 'Meal Pass';
    let effectivePlanId = planIdParam;
    let initialCredits: number | null = null;
    let basePlanPricePaise = 0;
    let upgradeFromSubId = '';

    let extraAddOnsPaise = Math.max(0, Math.min(200_000, Math.round(Number(body.add_ons_paise || 0))));
    let normalizedSlotsPayload: Record<string, any> = selectedSlots;

    if (purpose === 'single_meal_purchase') {
      const singleRes = await resolveAuthoritativeSingleMealOrder({
        admin,
        providerId: resolvedProviderId,
        selectedSlots,
        fallbackSlot: slot,
      });
      if (!singleRes.ok) {
        return NextResponse.json({ success: false, error: singleRes.error }, { status: singleRes.status });
      }
      durDays = 1;
      effectivePlanType = 'meal_credits';
      initialCredits = singleRes.totalMealsCount;
      effectivePlanName = `Single Order (${singleRes.itemsSummary})`.slice(0, 120);
      basePlanPricePaise = singleRes.baseMealsPaise;
      extraAddOnsPaise = singleRes.verifiedAddOnsPaise;
      normalizedSlotsPayload = singleRes.normalizedSelectedSlots;

      if (admin && resolvedProviderId) {
        const { data: dailyPlan } = await admin
          .from('subscription_plans')
          .select('id')
          .eq('provider_id', resolvedProviderId)
          .eq('plan_type', 'meal_credits')
          .eq('meal_credits', 1)
          .eq('published', false)
          .eq('active', true)
          .maybeSingle();

        if (dailyPlan) {
          effectivePlanId = dailyPlan.id;
        } else {
          const { data: createdDaily } = await admin
            .from('subscription_plans')
            .insert({
              provider_id: resolvedProviderId,
              name: 'Pay-Per-Meal Single Order',
              description: 'Single meal order for today',
              plan_type: 'meal_credits',
              duration_months: null,
              meal_credits: 1,
              price_paise: Math.max(100, singleRes.baseMealsPaise),
              daily_meal_limit: 5,
              cancellation_policy: 'Valid for today only.',
              missed_meal_policy: 'Unused single order expires at end of day.',
              published: false,
              active: true,
            })
            .select('id')
            .single();
          if (createdDaily) effectivePlanId = createdDaily.id;
        }
        await ensurePlanSlotsLinked(admin, resolvedProviderId);
      }
      if (!effectivePlanId) effectivePlanId = `single-${slot.toLowerCase()}`;
    } else {
      const plan = await resolveAuthoritativePlan({
        admin,
        providerId: resolvedProviderId,
        planId: planIdParam,
      });

      if (!plan) {
        return NextResponse.json(
          { success: false, error: 'Selected plan was not found for this kitchen.' },
          { status: 404 }
        );
      }

      resolvedProviderId = plan.provider_id || resolvedProviderId;
      durDays = plan.duration_days;
      effectivePlanType = plan.plan_type;
      effectivePlanName = plan.name;
      effectivePlanId = plan.id;
      initialCredits = plan.meal_credits;
      basePlanPricePaise = plan.price_paise;

      if (purpose === 'plan_upgrade') {
        const quote = await resolveVerifiedUpgradeQuote({
          admin,
          subscriptionId: subscriptionIdParam,
          customerId: resolvedCustomerId,
          isAdmin: auth.isAdmin,
          targetPlan: plan,
        });
        if (!quote.ok) {
          return NextResponse.json({ success: false, error: quote.error }, { status: quote.status });
        }
        upgradeFromSubId = subscriptionIdParam;
        basePlanPricePaise = quote.payablePaise;
      }
    }

    const packagingFeePaise =
      (purpose === 'subscription_purchase' || purpose === 'single_meal_purchase') &&
      effectiveFulfillmentMode === 'delivery' &&
      packagingPreference === 'disposable'
        ? disposableFeePaise * (purpose === 'single_meal_purchase' ? (initialCredits || 1) : durDays)
        : 0;

    const grossPaise = basePlanPricePaise + packagingFeePaise + extraAddOnsPaise;

    const promoResult = await resolveAuthoritativeDiscountPaise({
      admin,
      providerId: resolvedProviderId,
      promoCode,
      orderAmountPaise: grossPaise,
    });
    const verifiedDiscountPaise = promoResult.discountPaise;
    const payablePaise = Math.max(100, grossPaise - verifiedDiscountPaise);

    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const createdSubId =
      admin && isUuid.test(resolvedCustomerId) && isUuid.test(effectivePlanId)
        ? crypto.randomUUID()
        : `sub-cf-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;

    const requestedStartDt = requestedStart ? new Date(requestedStart) : now;
    const effectiveStart =
      isNaN(requestedStartDt.getTime()) || requestedStartDt.getTime() < now.getTime() ? now : requestedStartDt;
    const expiresAt = new Date(effectiveStart.getTime() + durDays * 24 * 60 * 60 * 1000);

    if (admin && isUuid.test(resolvedCustomerId) && isUuid.test(resolvedProviderId) && isUuid.test(effectivePlanId)) {
      const baseSubRow = {
        id: createdSubId,
        customer_id: resolvedCustomerId,
        provider_id: resolvedProviderId,
        plan_id: effectivePlanId,
        status: 'pending_payment',
        plan_type_snapshot: effectivePlanType,
        plan_name_snapshot: effectivePlanName,
        terms_version_snapshot: 'v2.0-cashfree',
        price_paid_paise: payablePaise,
        initial_meal_credits: initialCredits,
        remaining_meal_credits: initialCredits,
        starts_at: effectiveStart.toISOString(),
        expires_at: expiresAt.toISOString(),
      };
      try {
        const resExt = await admin.from('subscriptions').insert({
          ...baseSubRow,
          duration_days: durDays,
          selected_slots: normalizedSlotsPayload,
          repeat_days: repeatDays.length > 0 ? repeatDays : [1, 2, 3, 4, 5, 6, 7],
          packaging_preference: packagingPreference || 'reusable_tiffin',
          fulfillment_mode: effectiveFulfillmentMode,
          delivery_address: deliveryAddress || null,
          delivery_instructions: deliveryInstructions || null,
          promo_code: promoResult.code || null,
          discount_paise: verifiedDiscountPaise,
          payment_mode: 'cashfree_online',
        });
        if (resExt.error) {
          await admin.from('subscriptions').insert(baseSubRow);
        }
      } catch (err) {
        console.warn('DB error creating pending subscription for Cashfree:', err);
      }
    }

    platformStore.subscriptions.set(createdSubId, {
      id: createdSubId,
      customer_id: resolvedCustomerId,
      customer_name: customerName,
      customer_phone: customerPhone,
      customer_email: auth.email || customerEmail,
      provider_id: resolvedProviderId,
      plan_id: effectivePlanId,
      plan_type: effectivePlanType,
      plan_name: effectivePlanName,
      status: 'pending_payment',
      starts_at: effectiveStart.toISOString(),
      expires_at: expiresAt.toISOString(),
      remaining_meal_credits: initialCredits,
      initial_meal_credits: initialCredits,
      price_paid_paise: payablePaise,
      payment_mode: 'online',
      fulfillment_mode: effectiveFulfillmentMode,
      delivery_address: deliveryAddress,
      created_at: now.toISOString(),
      ...(upgradeFromSubId ? ({ upgrade_from_subscription_id: upgradeFromSubId } as any) : {}),
    });

    const orderId = `cf_thali_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`;
    const amountInr = Number((payablePaise / 100).toFixed(2));
    const returnUrl = `${siteBase}/payment/cashfree/return?order_id=${encodeURIComponent(orderId)}`;
    const notifyUrl = `${siteBase}/api/payments/cashfree/webhook`;

    const { order, env } = await createCashfreeOrder({
      orderId,
      orderAmountInr: amountInr,
      customerId: resolvedCustomerId,
      customerName,
      customerEmail: auth.email || customerEmail,
      customerPhone: customerPhone || '9999999999',
      returnUrl,
      notifyUrl,
      orderNote: `${effectivePlanName} - ${providerName}`,
      idempotencyKey: orderId,
      orderTags: {
        purpose: purpose === 'single_meal_purchase' ? 'subscription_purchase' : String(purpose).slice(0, 40),
        prov_id: String(resolvedProviderId).slice(0, 64),
        cust_id: String(resolvedCustomerId).slice(0, 64),
        sub_id: String(createdSubId).slice(0, 64),
        plan_id: String(effectivePlanId).slice(0, 64),
        plan_name: String(effectivePlanName).slice(0, 64),
        cust_name: String(customerName).slice(0, 64),
        duration_days: String(durDays),
        ...(upgradeFromSubId ? { upgrade_from: String(upgradeFromSubId).slice(0, 64) } : {}),
      },
    });

    cashfreeOrderStore.set(orderId, {
      order_id: orderId,
      cf_order_id: order.cf_order_id ? String(order.cf_order_id) : undefined,
      payment_session_id: order.payment_session_id,
      purpose: purpose === 'single_meal_purchase' ? 'subscription_purchase' : purpose,
      subscription_id: createdSubId,
      upgrade_from_subscription_id: upgradeFromSubId || undefined,
      customer_id: resolvedCustomerId,
      customer_name: customerName,
      customer_phone: customerPhone,
      customer_email: auth.email || customerEmail,
      provider_id: resolvedProviderId,
      provider_name: providerName,
      plan_id: effectivePlanId,
      plan_name: effectivePlanName,
      plan_type: effectivePlanType,
      duration_days: durDays,
      meal_credits: initialCredits,
      slot,
      amount_paise: payablePaise,
      status: 'created',
      created_at: now.toISOString(),
    });

    if (admin && isUuid.test(resolvedCustomerId) && isUuid.test(createdSubId)) {
      try {
        await admin.from('payment_transactions').insert({
          customer_id: resolvedCustomerId,
          subscription_id: createdSubId,
          booking_id: null,
          purpose: 'subscription_purchase',
          gateway_name: 'cashfree',
          gateway_order_id: orderId,
          amount_paise: payablePaise,
          currency: 'INR',
          status: 'created',
          idempotency_key: orderId,
          sanitized_gateway_metadata: {
            cf_order_id: order.cf_order_id || null,
            env,
            purpose,
            upgrade_from_subscription_id: upgradeFromSubId || null,
          },
        });
      } catch (err) {
        console.warn('Non-fatal payment_transactions insert error:', err);
      }
    }

    return NextResponse.json({
      success: true,
      order_id: order.order_id,
      cf_order_id: order.cf_order_id || null,
      payment_session_id: order.payment_session_id,
      environment: env,
      amount_inr: amountInr,
      subscription_id: createdSubId,
      purpose,
      return_url: returnUrl,
    });
  } catch (err: any) {
    console.error('Cashfree create-order error:', err);
    return NextResponse.json(
      {
        success: false,
        error: err?.message || 'Unable to initiate Cashfree payment order.',
      },
      { status: 500 }
    );
  }
}
