import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { addPartnerNotification } from '@/lib/partner-notifications';
import { sendCustomerInvoiceEmail } from '@/lib/notifications';

export const dynamic = 'force-dynamic';

/**
 * Creates a subscription using Counter Cash, Counter UPI, or Direct UPI.
 * Persists to public.subscriptions and platformStore in pending_payment state
 * until confirmed by the mess partner.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const {
      provider_id,
      plan_id,
      customer_id,
      customer_phone,
      customer_name,
      customer_email,
      plan_type,
      duration_days,
      meal_credits,
      price_paise,
      payment_mode = 'counter_cash',
      receipt_url = '',
      utr_reference = '',
      selected_slots = {},
      repeat_days = [1, 2, 3, 4, 5, 6, 7],
      packaging_preference = 'reusable_tiffin',
      fulfillment_mode: requestedFulfillment,
      delivery_address = '',
      delivery_instructions = '',
      promo_code = '',
      discount_paise = 0,
      starts_at: requestedStart,
    } = body;

    if (!provider_id) {
      return NextResponse.json(
        { success: false, error: 'provider_id is required.' },
        { status: 400 }
      );
    }

    const admin = getAdminClient();
    let providerName = 'Mess Partner';
    let providerSupportsDelivery = false;

    // 1. Verify Provider
    if (admin) {
      try {
        const { data: provider } = await admin
          .from('providers')
          .select('id, display_name, status, supports_delivery')
          .eq('id', provider_id)
          .maybeSingle();
        if (provider) {
          providerName = provider.display_name;
          providerSupportsDelivery = provider.supports_delivery === true;
        }
      } catch {}
    } else {
      const storeProv = platformStore.providers.get(provider_id);
      if (storeProv) providerName = storeProv.display_name;
    }
    const effectiveFulfillmentMode: 'pickup' | 'delivery' =
      providerSupportsDelivery && requestedFulfillment === 'delivery'
        ? 'delivery'
        : 'pickup';

    // 2. Resolve Plan
    let plan: any = null;
    if (admin && plan_id) {
      try {
        const { data: p } = await admin
          .from('subscription_plans')
          .select('*')
          .eq('id', plan_id)
          .maybeSingle();
        plan = p;
      } catch {}
    }
    if (!plan) {
      plan = platformStore.plans.get(plan_id);
    }

    const durDays = Number(plan?.duration_days || duration_days) || 30;
    const effectivePlanType = (plan?.plan_type === 'meal_credits' || plan_type === 'meal_credits')
      ? 'meal_credits'
      : 'fixed_period';
    const effectivePlanName = plan?.name || `${durDays}-Day Meal Pass`;
    const effectivePricePaise = Number(plan?.price_paise || price_paise) || 250000;
    const effectivePlanId = plan?.id || plan_id || `plan-${Date.now()}`;
    const initialCredits = effectivePlanType === 'meal_credits'
      ? (Number(plan?.meal_credits || meal_credits) || 60)
      : null;

    // 3. Resolve Customer ID
    let resolvedCustomerId = customer_id || `cust-${Date.now()}`;
    const cleanPhone = (customer_phone || '').replace(/\D/g, '');
    const clientName = (customer_name || '').trim() || 'Customer';

    if (admin) {
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!isUuid.test(resolvedCustomerId)) {
        if (cleanPhone.length >= 10) {
          const { data: existingProfile } = await admin
            .from('profiles')
            .select('id')
            .eq('phone_e164', cleanPhone.slice(-10))
            .maybeSingle();
          if (existingProfile) resolvedCustomerId = existingProfile.id;
        }

        if (!isUuid.test(resolvedCustomerId)) {
          const newId = crypto.randomUUID();
          await admin.from('profiles').insert({
            id: newId,
            display_name: clientName,
            phone_e164: cleanPhone.slice(-10) || null,
          });
          resolvedCustomerId = newId;
        }
      }
    }

    // 4. Create Subscription
    const now = new Date();
    const startDt = requestedStart ? new Date(requestedStart) : now;
    const effectiveStart = isNaN(startDt.getTime()) ? now : startDt;
    const expiresAt = new Date(effectiveStart.getTime() + durDays * 24 * 60 * 60 * 1000);
    const netPayablePaise = Math.max(0, effectivePricePaise - Number(discount_paise || 0));
    const subUuid = (admin && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(resolvedCustomerId))
      ? crypto.randomUUID()
      : `sub-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;

    let createdDbSub: any = null;

    if (admin) {
      const baseInsert = {
        id: subUuid,
        customer_id: resolvedCustomerId,
        provider_id,
        plan_id: effectivePlanId,
        status: 'pending_payment',
        plan_type_snapshot: effectivePlanType,
        plan_name_snapshot: effectivePlanName,
        terms_version_snapshot: 'v2.0-behance',
        price_paid_paise: netPayablePaise,
        initial_meal_credits: initialCredits,
        remaining_meal_credits: initialCredits,
        starts_at: effectiveStart.toISOString(),
        expires_at: expiresAt.toISOString(),
      };
      try {
        const resExt = await admin
          .from('subscriptions')
          .insert({
            ...baseInsert,
            duration_days: durDays,
            selected_slots: selected_slots || {},
            repeat_days: Array.isArray(repeat_days) && repeat_days.length > 0 ? repeat_days : [1, 2, 3, 4, 5, 6, 7],
            packaging_preference: packaging_preference || 'reusable_tiffin',
            fulfillment_mode: effectiveFulfillmentMode,
            delivery_address: delivery_address ? String(delivery_address).trim() : null,
            delivery_instructions: delivery_instructions || null,
            promo_code: promo_code || null,
            discount_paise: Number(discount_paise || 0),
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

    // Always also store in platformStore for immediate synchronization
    platformStore.subscriptions.set(subUuid, {
      id: subUuid,
      customer_id: resolvedCustomerId,
      customer_name: clientName,
      customer_phone: cleanPhone,
      customer_email: customer_email || '',
      provider_id,
      plan_id: effectivePlanId,
      plan_type: effectivePlanType,
      plan_name: effectivePlanName,
      status: 'pending_payment',
      starts_at: effectiveStart.toISOString(),
      expires_at: expiresAt.toISOString(),
      remaining_meal_credits: initialCredits,
      initial_meal_credits: initialCredits,
      price_paid_paise: netPayablePaise,
      payment_mode: 'counter_cash',
      fulfillment_mode: effectiveFulfillmentMode,
      delivery_address: delivery_address ? String(delivery_address).trim() : '',
      created_at: now.toISOString(),
      ...({
        receipt_url,
        utr_reference,
        selected_slots,
        repeat_days,
        packaging_preference,
        delivery_instructions,
        promo_code,
        discount_paise,
      } as any),
    });

    const paymentLabel = 'Pay Cash at Counter';

    // Send notification to Mess Partner
    addPartnerNotification({
      provider_id,
      type: 'pending_payment',
      title: 'New Subscription Payment Pending',
      message: `${clientName} placed an order for ${effectivePlanName} (₹${(netPayablePaise / 100).toFixed(0)}) via ${paymentLabel}. Please verify payment and confirm.`,
      customer_name: clientName,
      customer_phone: cleanPhone,
      amount_inr: netPayablePaise / 100,
      subscription_id: subUuid,
    });

    // Dispatch Customer Invoice Email (counter cash pending confirmation)
    let resolvedCustomerEmail = (customer_email || '').trim();
    if (!resolvedCustomerEmail && admin && resolvedCustomerId) {
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
        discountInr: Number(discount_paise || 0) / 100,
        promoCode: promo_code || undefined,
        paymentMode: 'counter_cash',
        paymentStatus: 'Pending Counter Cash Confirmation',
        startsAtIso: effectiveStart.toISOString(),
        expiresAtIso: expiresAt.toISOString(),
        packagingPreference: packaging_preference,
      }).catch(() => null);
    }

    return NextResponse.json({
      success: true,
      subscription: {
        id: subUuid,
        provider_id,
        plan_id: effectivePlanId,
        status: 'pending_payment',
        plan_type: effectivePlanType,
        plan_name: effectivePlanName,
        price_paise: effectivePricePaise,
        price_inr: effectivePricePaise / 100,
        starts_at: now.toISOString(),
        expires_at: expiresAt.toISOString(),
        remaining_credits: initialCredits,
        payment_mode,
        receipt_url,
        utr_reference,
      },
      payment_method: payment_mode,
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
