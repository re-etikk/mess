import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { addPartnerNotification } from '@/lib/partner-notifications';
import { sendCustomerInvoiceEmail } from '@/lib/notifications';
import { isAllowedMediaUrl, requireCustomerIdentity } from '@/lib/auth-session';
import {
  resolveAuthoritativeDiscountPaise,
  resolveAuthoritativePlan,
} from '@/lib/checkout-pricing';
import { getPlatformAppConfig } from '@/lib/app-config';
import { recordPromoRedemption } from '@/lib/promo-engine';

export const dynamic = 'force-dynamic';

/**
 * Creates a subscription using Counter Cash or Direct Counter UPI.
 * Enforces caller authentication and authoritative server-side plan & discount pricing.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = String(body.provider_id || '').trim();
    const planId = String(body.plan_id || '').trim();
    const claimedCustomerId = String(body.customer_id || '').trim();
    const receiptUrl = String(body.receipt_url || '').trim();
    const utrReference = String(body.utr_reference || '').trim().slice(0, 80);
    const selectedSlots = body.selected_slots && typeof body.selected_slots === 'object' ? body.selected_slots : {};
    const repeatDays =
      Array.isArray(body.repeat_days) && body.repeat_days.length > 0
        ? body.repeat_days.map((d: any) => Number(d)).filter((d: number) => d >= 1 && d <= 7)
        : [1, 2, 3, 4, 5, 6, 7];
    const packagingPreference = String(body.packaging_preference || 'reusable_tiffin').trim();
    const requestedFulfillment = String(body.fulfillment_mode || '').trim();
    const deliveryAddress = String(body.delivery_address || '').trim().slice(0, 300);
    const deliveryInstructions = String(body.delivery_instructions || '').trim().slice(0, 500);
    const promoCode = String(body.promo_code || '').trim();
    const requestedStart = body.starts_at;

    if (!providerId || !planId) {
      return NextResponse.json(
        { success: false, error: 'provider_id and plan_id are required.' },
        { status: 400 }
      );
    }

    if (receiptUrl && !isAllowedMediaUrl(receiptUrl)) {
      return NextResponse.json({ success: false, error: 'Invalid receipt attachment URL.' }, { status: 400 });
    }

    const auth = await requireCustomerIdentity(req, claimedCustomerId || undefined);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }
    const resolvedCustomerId = auth.userId;

    const admin = getAdminClient();
    let providerName = 'Mess Partner';
    let providerSupportsDelivery = false;
    let disposableFeePaise = 500;

    if (admin) {
      try {
        const { data: provider } = await admin
          .from('providers')
          .select('id, display_name, status, supports_delivery, disposable_fee_paise')
          .eq('id', providerId)
          .maybeSingle();
        if (provider) {
          if (provider.status === 'suspended' || provider.status === 'rejected') {
            return NextResponse.json({ success: false, error: 'This kitchen is currently unavailable for new orders.' }, { status: 403 });
          }
          providerName = provider.display_name;
          providerSupportsDelivery = provider.supports_delivery === true;
          disposableFeePaise = Math.max(0, Number(provider.disposable_fee_paise ?? 500));
        }
      } catch {}
    } else {
      const storeProv = platformStore.providers.get(providerId);
      if (storeProv) {
        providerName = storeProv.display_name;
      }
    }

    const effectiveFulfillmentMode: 'pickup' | 'delivery' =
      providerSupportsDelivery && requestedFulfillment === 'delivery' ? 'delivery' : 'pickup';

    const plan = await resolveAuthoritativePlan({
      admin,
      providerId,
      planId,
    });
    if (!plan) {
      return NextResponse.json({ success: false, error: 'Selected plan was not found for this kitchen.' }, { status: 404 });
    }

    const durDays = plan.duration_days;
    const effectivePlanType = plan.plan_type;
    const effectivePlanName = plan.name;
    const effectivePricePaise = plan.price_paise;
    const appCfg = await getPlatformAppConfig(admin);
    const packagingFeePaise =
      effectiveFulfillmentMode === 'delivery' && packagingPreference === 'disposable'
        ? disposableFeePaise * durDays
        : 0;
    const addOnsPaise = Math.max(0, Math.min(200_000, Math.round(Number(body.add_ons_paise || 0))));
    const baseSubGross = effectivePricePaise + packagingFeePaise + addOnsPaise;
    const deliveryFeePaise =
      effectiveFulfillmentMode === 'delivery' &&
      appCfg.default_delivery_fee_paise > 0 &&
      (appCfg.free_delivery_above_paise <= 0 || baseSubGross < appCfg.free_delivery_above_paise)
        ? appCfg.default_delivery_fee_paise
        : 0;
    const platformFeePaise = appCfg.platform_fee_paise > 0 ? appCfg.platform_fee_paise : 0;
    const grossPaise = baseSubGross + deliveryFeePaise + platformFeePaise;

    const promoResult = await resolveAuthoritativeDiscountPaise({
      admin,
      providerId,
      promoCode,
      orderAmountPaise: grossPaise,
      customerId: resolvedCustomerId,
      orderContext: 'plan',
    });
    const verifiedDiscountPaise = promoResult.discountPaise;
    const netPayablePaise = Math.max(0, grossPaise - verifiedDiscountPaise);

    const cleanPhone = String(body.customer_phone || '').replace(/\D/g, '').slice(-10);
    const clientName = String(body.customer_name || '').trim().slice(0, 80) || 'Customer';

    const now = new Date();
    const startDt = requestedStart ? new Date(requestedStart) : now;
    const effectiveStart = isNaN(startDt.getTime()) || startDt.getTime() < now.getTime() ? now : startDt;
    const expiresAt = new Date(effectiveStart.getTime() + durDays * 24 * 60 * 60 * 1000);

    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const subUuid =
      admin && isUuid.test(resolvedCustomerId) && isUuid.test(plan.id)
        ? crypto.randomUUID()
        : `sub-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;

    let createdDbSub: any = null;

    if (admin && isUuid.test(resolvedCustomerId) && isUuid.test(providerId) && isUuid.test(plan.id)) {
      const baseInsert = {
        id: subUuid,
        customer_id: resolvedCustomerId,
        provider_id: providerId,
        plan_id: plan.id,
        status: 'pending_payment',
        plan_type_snapshot: effectivePlanType,
        plan_name_snapshot: effectivePlanName,
        terms_version_snapshot: plan.terms_version,
        price_paid_paise: netPayablePaise,
        initial_meal_credits: plan.meal_credits,
        remaining_meal_credits: plan.meal_credits,
        starts_at: effectiveStart.toISOString(),
        expires_at: expiresAt.toISOString(),
      };
      try {
        const resExt = await admin
          .from('subscriptions')
          .insert({
            ...baseInsert,
            duration_days: durDays,
            selected_slots: selectedSlots,
            repeat_days: repeatDays.length > 0 ? repeatDays : [1, 2, 3, 4, 5, 6, 7],
            packaging_preference: packagingPreference || 'reusable_tiffin',
            fulfillment_mode: effectiveFulfillmentMode,
            delivery_address: deliveryAddress || null,
            delivery_instructions: deliveryInstructions || null,
            promo_code: promoResult.code || null,
            discount_paise: verifiedDiscountPaise,
            payment_mode: 'counter_cash',
          })
          .select('*')
          .single();

        if (!resExt.error && resExt.data) {
          createdDbSub = resExt.data;
        } else {
          const { data: sub } = await admin.from('subscriptions').insert(baseInsert).select('*').single();
          if (sub) createdDbSub = sub;
        }
      } catch (e) {
        console.warn('DB error inserting subscription:', e);
      }
    }

    platformStore.subscriptions.set(subUuid, {
      id: subUuid,
      customer_id: resolvedCustomerId,
      customer_name: clientName,
      customer_phone: cleanPhone,
      customer_email: auth.email || String(body.customer_email || '').trim(),
      provider_id: providerId,
      plan_id: plan.id,
      plan_type: effectivePlanType,
      plan_name: effectivePlanName,
      status: 'pending_payment',
      starts_at: effectiveStart.toISOString(),
      expires_at: expiresAt.toISOString(),
      remaining_meal_credits: plan.meal_credits,
      initial_meal_credits: plan.meal_credits,
      price_paid_paise: netPayablePaise,
      payment_mode: 'counter_cash',
      fulfillment_mode: effectiveFulfillmentMode,
      delivery_address: deliveryAddress,
      created_at: now.toISOString(),
      ...({
        receipt_url: receiptUrl,
        utr_reference: utrReference,
        selected_slots: selectedSlots,
        repeat_days: repeatDays,
        packaging_preference: packagingPreference,
        delivery_instructions: deliveryInstructions,
        promo_code: promoResult.code,
        discount_paise: verifiedDiscountPaise,
      } as any),
    });

    addPartnerNotification({
      provider_id: providerId,
      type: 'pending_payment',
      title: 'New Subscription Payment Pending',
      message: `${clientName} placed an order for ${effectivePlanName} (₹${(netPayablePaise / 100).toFixed(0)}) via Pay Cash at Counter. Verify payment to activate.`,
      customer_name: clientName,
      customer_phone: cleanPhone,
      amount_inr: netPayablePaise / 100,
      subscription_id: subUuid,
    });

    if (promoResult.code && verifiedDiscountPaise > 0) {
      await recordPromoRedemption({
        admin,
        code: promoResult.code,
        customerId: resolvedCustomerId,
        providerId,
        subscriptionId: subUuid,
        discountPaise: verifiedDiscountPaise,
      });
    }

    let resolvedCustomerEmail = String(auth.email || body.customer_email || '').trim();
    if (!resolvedCustomerEmail && admin && isUuid.test(resolvedCustomerId)) {
      try {
        const { data: prof } = await admin.from('profiles').select('email').eq('id', resolvedCustomerId).maybeSingle();
        if (prof?.email) resolvedCustomerEmail = prof.email;
      } catch {}
    }
    if (resolvedCustomerEmail && resolvedCustomerEmail.includes('@')) {
      await sendCustomerInvoiceEmail({
        to: resolvedCustomerEmail,
        customerName: clientName,
        providerName,
        planName: effectivePlanName,
        subscriptionId: subUuid,
        amountInr: netPayablePaise / 100,
        discountInr: verifiedDiscountPaise / 100,
        promoCode: promoResult.code || undefined,
        paymentMode: 'counter_cash',
        paymentStatus: 'Pending Counter Cash Confirmation',
        startsAtIso: effectiveStart.toISOString(),
        expiresAtIso: expiresAt.toISOString(),
        packagingPreference,
      }).catch(() => null);
    }

    return NextResponse.json({
      success: true,
      subscription: {
        id: createdDbSub?.id || subUuid,
        provider_id: providerId,
        plan_id: plan.id,
        status: 'pending_payment',
        plan_type: effectivePlanType,
        plan_name: effectivePlanName,
        price_paise: netPayablePaise,
        price_inr: Math.round(netPayablePaise / 100),
        starts_at: effectiveStart.toISOString(),
        expires_at: expiresAt.toISOString(),
        remaining_credits: plan.meal_credits,
        payment_mode: 'counter_cash',
        receipt_url: receiptUrl,
        utr_reference: utrReference,
      },
      payment_method: 'counter_cash',
      message: `Pass order submitted! Status is pending payment confirmation at ${providerName}.`,
    });
  } catch (err: any) {
    console.error('Subscription API fatal error:', err);
    return NextResponse.json(
      { success: false, error: err?.message || 'Server error creating subscription.' },
      { status: 500 }
    );
  }
}
