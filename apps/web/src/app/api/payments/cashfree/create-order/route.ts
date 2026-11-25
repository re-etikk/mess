import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import {
  cashfreeOrderStore,
  createCashfreeOrder,
  getCashfreeConfig,
} from '@/lib/cashfree';

export const dynamic = 'force-dynamic';

export async function GET() {
  const cfg = getCashfreeConfig();
  return NextResponse.json(
    {
      success: true,
      configured: cfg.configured,
      env: cfg.env,
    },
    { headers: { 'Cache-Control': 'private, no-store' } },
  );
}

export async function POST(req: NextRequest) {
  try {
    const cfg = getCashfreeConfig();
    if (!cfg.configured) {
      return NextResponse.json(
        {
          success: false,
          code: 'cashfree_not_configured',
          error:
            'Cashfree Payment Gateway is not configured on the server yet. Please set CASHFREE_APP_ID and CASHFREE_SECRET_KEY in environment variables.',
        },
        { status: 503 },
      );
    }

    const body = await req.json().catch(() => ({}));
    const {
      purpose = 'subscription_purchase',
      provider_id,
      plan_id,
      subscription_id,
      target_plan_id,
      customer_id,
      customer_name,
      customer_phone,
      customer_email,
      plan_type,
      plan_name,
      duration_days,
      meal_credits,
      price_paise,
      add_ons_paise = 0,
      slot = 'LUNCH',
      current_subscription,
    } = body;

    if (!provider_id && purpose !== 'plan_upgrade') {
      return NextResponse.json(
        { success: false, error: 'provider_id is required.' },
        { status: 400 },
      );
    }

    const admin = getAdminClient();
    const now = new Date();
    const origin =
      process.env.NEXT_PUBLIC_SITE_URL ||
      req.nextUrl.origin ||
      'https://www.thali.store';

    let resolvedProviderId = provider_id || current_subscription?.providerId || '';
    let providerName = 'Mess Partner';

    if (admin && resolvedProviderId) {
      try {
        const { data: prov } = await admin
          .from('providers')
          .select('id, display_name')
          .eq('id', resolvedProviderId)
          .maybeSingle();
        if (prov) providerName = prov.display_name;
      } catch {}
    } else if (resolvedProviderId) {
      const sp = platformStore.providers.get(resolvedProviderId);
      if (sp) providerName = sp.display_name;
    }

    // Resolve Plan
    const effectiveTargetPlanId =
      purpose === 'plan_upgrade' ? target_plan_id || plan_id : plan_id;
    let plan: any = null;
    if (admin && effectiveTargetPlanId) {
      try {
        const { data: p } = await admin
          .from('subscription_plans')
          .select('*')
          .eq('id', effectiveTargetPlanId)
          .maybeSingle();
        plan = p;
      } catch {}
    }
    if (!plan && effectiveTargetPlanId) {
      plan = platformStore.plans.get(effectiveTargetPlanId);
    }

    let durDays = Number(plan?.duration_days || duration_days) || 30;
    let effectivePlanType: 'fixed_period' | 'meal_credits' | 'daily' =
      plan?.plan_type === 'meal_credits' || plan_type === 'meal_credits'
        ? 'meal_credits'
        : plan?.plan_type === 'daily' || plan_type === 'daily'
          ? 'daily'
          : 'fixed_period';
    let effectivePlanName =
      plan?.name || plan_name || `${durDays}-Day Meal Pass`;
    let effectivePlanId =
      plan?.id || effectiveTargetPlanId || `plan-${Date.now()}`;
    let initialCredits =
      effectivePlanType === 'meal_credits'
        ? Number(plan?.meal_credits || meal_credits) || 60
        : effectivePlanType === 'daily'
          ? 1
          : null;

    let payablePaise =
      (Number(plan?.price_paise || price_paise) || 0) +
      (Number(add_ons_paise) || 0);

    // Handle OTT pro-rata upgrade calculation if purpose === 'plan_upgrade'
    let upgradeFromSubId = '';
    if (purpose === 'plan_upgrade') {
      upgradeFromSubId = subscription_id || '';
      let currentSub: any = null;
      if (admin && upgradeFromSubId) {
        try {
          const { data: s } = await admin
            .from('subscriptions')
            .select('*')
            .eq('id', upgradeFromSubId)
            .maybeSingle();
          if (s) currentSub = s;
        } catch {}
      }
      if (!currentSub && upgradeFromSubId) {
        currentSub = platformStore.subscriptions.get(upgradeFromSubId);
      }
      if (!currentSub && current_subscription) {
        currentSub = {
          id: upgradeFromSubId,
          customer_id: customer_id || current_subscription.customerId,
          provider_id: current_subscription.providerId || resolvedProviderId,
          plan_name: current_subscription.planName || 'Current Pass',
          plan_type: current_subscription.type || 'fixed_period',
          expires_at:
            current_subscription.endDate ||
            new Date(Date.now() + 25 * 86400000).toISOString(),
          duration_days: current_subscription.durationDays || 30,
          price_paid_paise: Number(current_subscription.price || 2400) * 100,
          remaining_meal_credits: current_subscription.mealsRemaining ?? null,
          initial_meal_credits: current_subscription.totalMeals ?? null,
        };
      }

      if (currentSub) {
        if (!resolvedProviderId) resolvedProviderId = currentSub.provider_id || '';
        const expiresAtMs = new Date(currentSub.expires_at).getTime();
        const remainingMs = Math.max(0, expiresAtMs - Date.now());
        const remainingDays = Math.ceil(remainingMs / (1000 * 60 * 60 * 24));
        const totalDays = currentSub.duration_days || 30;
        const paidPaise = Number(currentSub.price_paid_paise) || 240000;
        const targetPaise =
          Number(plan?.price_paise || body.target_plan_price_paise || price_paise) ||
          210000;

        let unusedFraction = 0;
        if (
          currentSub.plan_type === 'meal_credits' ||
          currentSub.plan_type_snapshot === 'meal_credits'
        ) {
          const remC = currentSub.remaining_meal_credits ?? 0;
          const initC = currentSub.initial_meal_credits ?? 60;
          unusedFraction =
            initC > 0 ? Math.min(1, Math.max(0, remC / initC)) : 0;
        } else {
          unusedFraction =
            totalDays > 0 ? Math.min(1, Math.max(0, remainingDays / totalDays)) : 0;
        }
        const residualCreditPaise = Math.round(paidPaise * unusedFraction);
        payablePaise = Math.max(100, targetPaise - residualCreditPaise);
      }
    }

    if (payablePaise < 100) {
      // Cashfree requires >= ₹1.00 (100 paise)
      payablePaise = Math.max(100, payablePaise);
    }

    // Resolve Customer UUID
    let resolvedCustomerId = customer_id || `cust-${Date.now()}`;
    const cleanPhone = (customer_phone || '').replace(/\D/g, '');
    const clientName = (customer_name || '').trim() || 'Thali Customer';
    const isUuid =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    if (admin) {
      try {
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
              phone_e164: cleanPhone.length >= 7 ? cleanPhone.slice(-10) : null,
            });
            resolvedCustomerId = newId;
          }
        }
      } catch (e) {
        console.warn('Profile resolution error:', e);
      }
    }

    // Create pending subscription when purchasing a pass or upgrade
    let createdSubId = '';
    if (
      purpose === 'subscription_purchase' ||
      purpose === 'plan_upgrade'
    ) {
      createdSubId =
        admin && isUuid.test(resolvedCustomerId)
          ? crypto.randomUUID()
          : `sub-cf-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
      const expiresAt = new Date(
        now.getTime() + durDays * 24 * 60 * 60 * 1000,
      );

      if (admin && isUuid.test(resolvedCustomerId) && isUuid.test(resolvedProviderId) && isUuid.test(effectivePlanId)) {
        try {
          await admin.from('subscriptions').insert({
            id: createdSubId,
            customer_id: resolvedCustomerId,
            provider_id: resolvedProviderId,
            plan_id: effectivePlanId,
            status: 'pending_payment',
            plan_type_snapshot:
              effectivePlanType === 'meal_credits' ? 'meal_credits' : 'fixed_period',
            plan_name_snapshot: effectivePlanName,
            terms_version_snapshot: 'v1.0-cashfree',
            price_paid_paise: payablePaise,
            initial_meal_credits: initialCredits,
            remaining_meal_credits: initialCredits,
            starts_at: now.toISOString(),
            expires_at: expiresAt.toISOString(),
          });
        } catch (err) {
          console.warn('DB error creating pending subscription for Cashfree:', err);
        }
      }

      platformStore.subscriptions.set(createdSubId, {
        id: createdSubId,
        customer_id: resolvedCustomerId,
        customer_name: clientName,
        customer_phone: cleanPhone,
        customer_email: customer_email || '',
        provider_id: resolvedProviderId,
        plan_id: effectivePlanId,
        plan_type: effectivePlanType,
        plan_name: effectivePlanName,
        status: 'pending_payment',
        starts_at: now.toISOString(),
        expires_at: expiresAt.toISOString(),
        remaining_meal_credits: initialCredits,
        initial_meal_credits: initialCredits,
        price_paid_paise: payablePaise,
        payment_mode: 'online',
        created_at: now.toISOString(),
        ...(upgradeFromSubId
          ? ({ upgrade_from_subscription_id: upgradeFromSubId } as any)
          : {}),
      });
    }

    const orderId = `cf_thali_${Date.now()}_${crypto.randomBytes(3).toString('hex')}`;
    const amountInr = Number((payablePaise / 100).toFixed(2));
    const returnUrl = `${origin}/payment/cashfree/return?order_id=${encodeURIComponent(orderId)}`;
    const notifyUrl = `${origin}/api/payments/cashfree/webhook`;

    const { order, env } = await createCashfreeOrder({
      orderId,
      orderAmountInr: amountInr,
      customerId: resolvedCustomerId,
      customerName: clientName,
      customerEmail: customer_email || '',
      customerPhone: cleanPhone || '9999999999',
      returnUrl,
      notifyUrl,
      orderNote: `${effectivePlanName} - ${providerName}`,
      idempotencyKey: orderId,
      orderTags: {
        purpose: String(purpose).slice(0, 40),
        prov_id: String(resolvedProviderId).slice(0, 64),
        cust_id: String(resolvedCustomerId).slice(0, 64),
        sub_id: String(createdSubId).slice(0, 64),
        plan_id: String(effectivePlanId).slice(0, 64),
        plan_name: String(effectivePlanName).slice(0, 64),
        cust_name: String(clientName).slice(0, 64),
        duration_days: String(durDays),
        ...(upgradeFromSubId
          ? { upgrade_from: String(upgradeFromSubId).slice(0, 64) }
          : {}),
      },
    });

    // Save in memory store
    cashfreeOrderStore.set(orderId, {
      order_id: orderId,
      cf_order_id: order.cf_order_id ? String(order.cf_order_id) : undefined,
      payment_session_id: order.payment_session_id,
      purpose,
      subscription_id: createdSubId || undefined,
      upgrade_from_subscription_id: upgradeFromSubId || undefined,
      customer_id: resolvedCustomerId,
      customer_name: clientName,
      customer_phone: cleanPhone,
      customer_email: customer_email || '',
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

    // Persist payment_transactions row if valid DB UUIDs exist
    if (
      admin &&
      isUuid.test(resolvedCustomerId) &&
      createdSubId &&
      isUuid.test(createdSubId)
    ) {
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
          },
        });
      } catch (err) {
        console.warn('Non-fatal payment_transactions insert error:', err);
      }
    }

    return NextResponse.json({
      success: true,
      order_id: order.order_id,
      cf_order_id: order.cf_order_id,
      payment_session_id: order.payment_session_id,
      environment: env,
      amount_inr: amountInr,
      amount_paise: payablePaise,
      subscription_id: createdSubId || null,
      provider_name: providerName,
      plan_name: effectivePlanName,
    });
  } catch (err: any) {
    console.error('Cashfree create-order error:', err);
    return NextResponse.json(
      {
        success: false,
        error: err?.message || 'Unable to initiate Cashfree payment order.',
      },
      { status: 500 },
    );
  }
}
