import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { addPartnerNotification } from '@/lib/partner-notifications';

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
    } = body;

    if (!provider_id) {
      return NextResponse.json(
        { success: false, error: 'provider_id is required.' },
        { status: 400 }
      );
    }

    const admin = getAdminClient();
    let providerName = 'Mess Partner';

    // 1. Verify Provider
    if (admin) {
      try {
        const { data: provider } = await admin
          .from('providers')
          .select('id, display_name, status')
          .eq('id', provider_id)
          .maybeSingle();
        if (provider) providerName = provider.display_name;
      } catch {}
    } else {
      const storeProv = platformStore.providers.get(provider_id);
      if (storeProv) providerName = storeProv.display_name;
    }

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
    const expiresAt = new Date(now.getTime() + durDays * 24 * 60 * 60 * 1000);
    const subUuid = (admin && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(resolvedCustomerId))
      ? crypto.randomUUID()
      : `sub-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;

    let createdDbSub: any = null;

    if (admin) {
      try {
        const { data: sub, error: subErr } = await admin
          .from('subscriptions')
          .insert({
            id: subUuid,
            customer_id: resolvedCustomerId,
            provider_id,
            plan_id: effectivePlanId,
            status: 'pending_payment',
            plan_type_snapshot: effectivePlanType,
            plan_name_snapshot: effectivePlanName,
            terms_version_snapshot: 'v1.0-counter',
            price_paid_paise: effectivePricePaise,
            initial_meal_credits: initialCredits,
            remaining_meal_credits: initialCredits,
            starts_at: now.toISOString(),
            expires_at: expiresAt.toISOString(),
          })
          .select('*')
          .single();

        if (!subErr && sub) {
          createdDbSub = sub;
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
      starts_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      remaining_meal_credits: initialCredits,
      initial_meal_credits: initialCredits,
      price_paid_paise: effectivePricePaise,
      payment_mode,
      created_at: now.toISOString(),
      ...({
        receipt_url,
        utr_reference,
      } as any),
    });

    const paymentLabel = payment_mode === 'direct_upi'
      ? 'Direct UPI (Scan & Pay)'
      : (payment_mode === 'counter_upi' ? 'Counter UPI QR' : 'Counter Cash');

    // Send notification to Mess Partner
    addPartnerNotification({
      provider_id,
      type: 'pending_payment',
      title: 'New Subscription Payment Pending',
      message: `${clientName} placed an order for ${effectivePlanName} (₹${(effectivePricePaise / 100).toFixed(0)}) via ${paymentLabel}. Please verify payment and confirm.`,
      customer_name: clientName,
      customer_phone: cleanPhone,
      amount_inr: effectivePricePaise / 100,
      subscription_id: subUuid,
    });

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
