import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

/**
 * Creates or activates a subscription using Pay on Counter (Cash / UPI).
 * Persists directly to public.subscriptions so mobile and web customers
 * can subscribe and redeem meals immediately without payment gateway blockers.
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
    } = body;

    if (!provider_id) {
      return NextResponse.json(
        { success: false, error: 'provider_id is required.' },
        { status: 400 }
      );
    }

    const admin = getAdminClient();
    if (!admin) {
      return NextResponse.json(
        { success: false, error: 'Database service is unavailable.' },
        { status: 503 }
      );
    }

    // 1. Verify Provider
    const { data: provider, error: provError } = await admin
      .from('providers')
      .select('id, display_name, status, timezone')
      .eq('id', provider_id)
      .maybeSingle();

    if (provError || !provider) {
      return NextResponse.json(
        { success: false, error: 'Kitchen partner not found.' },
        { status: 404 }
      );
    }

    // 2. Resolve or Fallback Subscription Plan
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
      const { data: plans } = await admin
        .from('subscription_plans')
        .select('*')
        .eq('provider_id', provider_id)
        .eq('active', true)
        .limit(1);
      if (plans && plans.length > 0) {
        plan = plans[0];
      }
    }

    // If still no plan in DB, create one on the fly for this provider
    if (!plan) {
      const pType = plan_type === 'meal_credits' ? 'meal_credits' : 'fixed_period';
      const dur = Number(duration_days) || 30;
      const price = Number(price_paise) || 250000;
      const credits = pType === 'meal_credits' ? Number(meal_credits) || 60 : null;

      const { data: newPlan, error: newPlanErr } = await admin
        .from('subscription_plans')
        .insert({
          provider_id: provider.id,
          name: `${dur}-Day Meal Pass`,
          description: 'Standard nutritious daily meal plan',
          plan_type: pType,
          duration_days: dur,
          price_paise: price,
          meal_credits: credits,
          daily_meal_limit: 2,
          active: true,
        })
        .select()
        .single();

      if (!newPlanErr && newPlan) {
        plan = newPlan;
      }
    }

    const effectivePlanId = plan?.id || plan_id || '00000000-0000-0000-0000-000000000001';
    const effectivePlanType = (plan?.plan_type === 'meal_credits' || plan_type === 'meal_credits')
      ? 'meal_credits'
      : 'fixed_period';
    const effectivePlanName = plan?.name || `${duration_days || 30}-Day Meal Plan`;
    const effectivePricePaise = plan?.price_paise || Number(price_paise) || 250000;
    const durDays = plan?.duration_days || Number(duration_days) || 30;
    const initialCredits = effectivePlanType === 'meal_credits'
      ? (plan?.meal_credits || Number(meal_credits) || 60)
      : null;

    // 3. Resolve Customer Profile
    let resolvedCustomerId = customer_id;
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    if (!resolvedCustomerId || !isUuid.test(resolvedCustomerId)) {
      // Check phone or email
      const phoneClean = (customer_phone || '').replace(/\D/g, '');
      if (phoneClean.length >= 10) {
        const { data: existingProfile } = await admin
          .from('profiles')
          .select('id')
          .eq('phone_e164', phoneClean.slice(-10))
          .maybeSingle();

        if (existingProfile) {
          resolvedCustomerId = existingProfile.id;
        }
      }

      if (!resolvedCustomerId) {
        // Create new profile record
        const newId = crypto.randomUUID();
        const { data: createdProfile } = await admin
          .from('profiles')
          .insert({
            id: newId,
            display_name: customer_name?.trim() || 'Guest Customer',
            phone_e164: (customer_phone || '').replace(/\D/g, '').slice(-10) || null,
          })
          .select('id')
          .single();

        resolvedCustomerId = createdProfile?.id || newId;
      }
    } else {
      // Ensure the UUID exists in public.profiles to satisfy FK
      const { data: prof } = await admin
        .from('profiles')
        .select('id')
        .eq('id', resolvedCustomerId)
        .maybeSingle();

      if (!prof) {
        await admin.from('profiles').insert({
          id: resolvedCustomerId,
          display_name: customer_name?.trim() || 'Customer',
          phone_e164: (customer_phone || '').replace(/\D/g, '').slice(-10) || null,
        });
      }
    }

    // 4. Ensure meal slots are linked for this plan so redeem_meal_atomic succeeds
    if (plan?.id) {
      const { data: existingSlots } = await admin
        .from('plan_meal_slots')
        .select('meal_slot_id')
        .eq('plan_id', plan.id);

      if (!existingSlots || existingSlots.length === 0) {
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
    }

    // 5. Insert Active Subscription
    const now = new Date();
    const expiresAt = new Date(now.getTime() + durDays * 24 * 60 * 60 * 1000);

    const { data: subscription, error: subError } = await admin
      .from('subscriptions')
      .insert({
        customer_id: resolvedCustomerId,
        provider_id: provider.id,
        plan_id: effectivePlanId,
        status: 'active',
        plan_type_snapshot: effectivePlanType,
        plan_name_snapshot: effectivePlanName,
        terms_version_snapshot: 'v1.0-counter',
        price_paid_paise: effectivePricePaise,
        initial_meal_credits: initialCredits,
        remaining_meal_credits: initialCredits,
        starts_at: now.toISOString(),
        expires_at: expiresAt.toISOString(),
        activated_at: now.toISOString(),
        payment_verified_at: now.toISOString(),
      })
      .select('*')
      .single();

    if (subError) {
      console.error('Subscription insert error:', subError.message);
      return NextResponse.json(
        { success: false, error: 'Could not create subscription: ' + subError.message },
        { status: 500 }
      );
    }

    return NextResponse.json({
      success: true,
      subscription: {
        id: subscription.id,
        provider_id: subscription.provider_id,
        plan_id: subscription.plan_id,
        status: subscription.status,
        plan_type: subscription.plan_type_snapshot,
        plan_name: subscription.plan_name_snapshot,
        price_paise: subscription.price_paid_paise,
        starts_at: subscription.starts_at,
        expires_at: subscription.expires_at,
        remaining_credits: subscription.remaining_meal_credits,
        payment_mode: 'pay_on_counter',
      },
      payment_method: 'pay_on_counter',
      message: `Pass activated! Please pay ₹${(effectivePricePaise / 100).toFixed(0)} on counter via Cash or UPI.`,
    });
  } catch (err: any) {
    console.error('Subscription API fatal error:', err);
    return NextResponse.json(
      { success: false, error: err?.message || 'Server error creating subscription.' },
      { status: 500 }
    );
  }
}
