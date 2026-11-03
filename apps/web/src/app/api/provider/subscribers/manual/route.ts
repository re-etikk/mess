import { NextRequest, NextResponse } from 'next/server';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

/**
 * Manually enrolls a walk-in member with Cash or UPI collected at the counter.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const {
      provider_id,
      customer_name,
      customer_phone,
      plan_id,
      payment_mode = 'cash',
      amount_paid_inr,
      custom_days,
      custom_credits,
    } = body;

    if (!provider_id) {
      return NextResponse.json(
        { success: false, error: 'provider_id is required.' },
        { status: 400 }
      );
    }

    const auth = await requireProviderOwnership(req, provider_id);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }

    const admin = getAdminClient();
    if (!admin) {
      return NextResponse.json(
        { success: false, error: 'Database service is unavailable.' },
        { status: 503 }
      );
    }

    // 1. Resolve or Create Customer in public.profiles
    const phoneClean = (customer_phone || '').replace(/\D/g, '').slice(-10);
    let customerId: string | null = null;

    if (phoneClean) {
      const { data: existing } = await admin
        .from('profiles')
        .select('id')
        .eq('phone_e164', phoneClean)
        .maybeSingle();

      if (existing) {
        customerId = existing.id;
      }
    }

    if (!customerId) {
      customerId = crypto.randomUUID();
      await admin.from('profiles').insert({
        id: customerId,
        display_name: customer_name?.trim() || 'Counter Member',
        phone_e164: phoneClean || null,
      });
    }

    // 2. Resolve Plan
    let plan: any = null;
    if (plan_id) {
      const { data: p } = await admin
        .from('subscription_plans')
        .select('*')
        .eq('id', plan_id)
        .maybeSingle();
      plan = p;
    }

    if (!plan) {
      const { data: fallbackPlans } = await admin
        .from('subscription_plans')
        .select('*')
        .eq('provider_id', provider_id)
        .eq('active', true)
        .limit(1);
      if (fallbackPlans && fallbackPlans.length > 0) {
        plan = fallbackPlans[0];
      }
    }

    const durDays = Number(custom_days) || plan?.duration_days || 30;
    const planType = plan?.plan_type === 'meal_credits' ? 'meal_credits' : 'fixed_period';
    const credits = planType === 'meal_credits' ? (Number(custom_credits) || plan?.meal_credits || 60) : null;
    const pricePaise = amount_paid_inr ? Number(amount_paid_inr) * 100 : (plan?.price_paise || 250000);

    const now = new Date();
    const expiresAt = new Date(now.getTime() + durDays * 24 * 60 * 60 * 1000);

    // 3. Ensure slots are linked
    if (plan?.id) {
      const { data: slots } = await admin
        .from('meal_slots')
        .select('id')
        .eq('provider_id', provider_id)
        .eq('active', true);

      if (slots && slots.length > 0) {
        await admin.from('plan_meal_slots').upsert(
          slots.map((s) => ({ plan_id: plan.id, meal_slot_id: s.id })),
          { onConflict: 'plan_id,meal_slot_id' }
        );
      }
    }

    // 4. Insert Active Subscription
    const { data: subscription, error: subError } = await admin
      .from('subscriptions')
      .insert({
        customer_id: customerId,
        provider_id: provider_id,
        plan_id: plan?.id || '00000000-0000-0000-0000-000000000001',
        status: 'active',
        plan_type_snapshot: planType,
        plan_name_snapshot: plan?.name || `${durDays}-Day Member Pass`,
        terms_version_snapshot: 'v1.0-counter-manual',
        price_paid_paise: pricePaise,
        initial_meal_credits: credits,
        remaining_meal_credits: credits,
        starts_at: now.toISOString(),
        expires_at: expiresAt.toISOString(),
        activated_at: now.toISOString(),
        payment_verified_at: now.toISOString(),
      })
      .select()
      .single();

    if (subError) {
      console.error('Manual enrollment error:', subError.message);
      return NextResponse.json(
        { success: false, error: 'Could not enroll member: ' + subError.message },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      subscription,
      payment_mode,
      message: `Member enrolled successfully. Collected ₹${(pricePaise / 100).toFixed(0)} via ${payment_mode.toUpperCase()}.`,
    });
  } catch (err: any) {
    console.error('Manual enrollment API error:', err);
    return NextResponse.json(
      { success: false, error: err?.message || 'Server error enrolling subscriber.' },
      { status: 500 }
    );
  }
}
