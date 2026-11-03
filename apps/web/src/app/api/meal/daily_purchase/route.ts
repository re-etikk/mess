import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

/**
 * Creates a single-meal entitlement for Pay on Counter (Cash / Counter UPI).
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { provider_id, slot, customer_id, price_paise } = body;

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

    // Verify provider
    const { data: provider, error: provError } = await admin
      .from('providers')
      .select('id, display_name, status')
      .eq('id', provider_id)
      .maybeSingle();

    if (provError || !provider) {
      return NextResponse.json(
        { success: false, error: 'Kitchen partner not found.' },
        { status: 404 }
      );
    }

    // Resolve or find/create customer profile
    let resolvedCustomerId = customer_id;
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!resolvedCustomerId || !isUuid.test(resolvedCustomerId)) {
      resolvedCustomerId = crypto.randomUUID();
      await admin.from('profiles').insert({
        id: resolvedCustomerId,
        display_name: 'Walk-in Customer',
      });
    } else {
      const { data: prof } = await admin
        .from('profiles')
        .select('id')
        .eq('id', resolvedCustomerId)
        .maybeSingle();

      if (!prof) {
        await admin.from('profiles').insert({
          id: resolvedCustomerId,
          display_name: 'Customer',
        });
      }
    }

    // Find or create a single-day plan
    let { data: dailyPlan } = await admin
      .from('subscription_plans')
      .select('*')
      .eq('provider_id', provider_id)
      .eq('plan_type', 'meal_credits')
      .eq('duration_days', 1)
      .maybeSingle();

    if (!dailyPlan) {
      const { data: createdPlan } = await admin
        .from('subscription_plans')
        .insert({
          provider_id: provider.id,
          name: `Daily ${slot || 'Meal'} Pass`,
          description: 'Single meal coupon for today',
          plan_type: 'meal_credits',
          duration_days: 1,
          price_paise: Number(price_paise) || 8000,
          meal_credits: 1,
          daily_meal_limit: 1,
          active: true,
        })
        .select()
        .single();
      dailyPlan = createdPlan;
    }

    // Ensure slot is linked to plan
    if (dailyPlan?.id) {
      const { data: slots } = await admin
        .from('meal_slots')
        .select('id')
        .eq('provider_id', provider_id);

      if (slots && slots.length > 0) {
        await admin.from('plan_meal_slots').upsert(
          slots.map((s) => ({ plan_id: dailyPlan.id, meal_slot_id: s.id })),
          { onConflict: 'plan_id,meal_slot_id' }
        );
      }
    }

    // Insert 1-day subscription with 1 credit so scanning works
    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const { data: subscription } = await admin
      .from('subscriptions')
      .insert({
        customer_id: resolvedCustomerId,
        provider_id: provider.id,
        plan_id: dailyPlan?.id || '00000000-0000-0000-0000-000000000001',
        status: 'active',
        plan_type_snapshot: 'meal_credits',
        plan_name_snapshot: dailyPlan?.name || `Daily ${slot || 'Meal'} Pass`,
        terms_version_snapshot: 'v1.0-counter',
        price_paid_paise: Number(price_paise) || 8000,
        initial_meal_credits: 1,
        remaining_meal_credits: 1,
        starts_at: now.toISOString(),
        expires_at: expiresAt.toISOString(),
        activated_at: now.toISOString(),
        payment_verified_at: now.toISOString(),
      })
      .select()
      .single();

    return NextResponse.json({
      success: true,
      entitlement: {
        id: subscription?.id || `daily-${Date.now()}`,
        provider_id: provider.id,
        slot: slot || 'LUNCH',
        payment_method: 'pay_on_counter',
        is_paid: true,
      },
      message: 'Daily meal pass activated! Please pay on counter via Cash or UPI.',
    });
  } catch (err: any) {
    console.error('Daily purchase API fatal error:', err);
    return NextResponse.json(
      { success: false, error: err?.message || 'Server error creating daily pass.' },
      { status: 500 }
    );
  }
}
