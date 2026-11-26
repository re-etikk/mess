import { NextRequest, NextResponse } from 'next/server';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { ensurePlanSlotsLinked } from '@/lib/auth-session';
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

    // 1. Resolve or Create Customer in auth.users + public.profiles
    const phoneClean = (customer_phone || '').replace(/\D/g, '').slice(-10);
    const phoneE164 = phoneClean.length === 10 ? `+91${phoneClean}` : null;
    let customerId: string | null = null;

    if (phoneE164) {
      const { data: existing } = await admin
        .from('profiles')
        .select('id')
        .or(`phone_e164.eq.${phoneE164},phone_e164.eq.${phoneClean}`)
        .limit(1)
        .maybeSingle();

      if (existing) {
        customerId = existing.id;
      }
    }

    if (!customerId) {
      const placeholderEmail = `walkin.${phoneClean || Date.now()}@counter.thali.local`;
      const { data: createdUser } = await admin.auth.admin
        .createUser({
          email: placeholderEmail,
          phone: phoneE164 || undefined,
          email_confirm: true,
          user_metadata: { display_name: customer_name?.trim() || 'Counter Member', role: 'customer', walkin: true },
        })
        .catch(() => ({ data: null as any }));
      customerId = createdUser?.user?.id || null;
      if (customerId) {
        await admin.from('profiles').upsert({
          id: customerId,
          display_name: customer_name?.trim() || 'Counter Member',
          phone_e164: phoneE164,
        });
      }
    }

    if (!customerId) {
      return NextResponse.json(
        { success: false, error: 'Could not register member account. Provide a valid 10-digit phone number.' },
        { status: 400 }
      );
    }

    // 2. Resolve Plan belonging to this provider
    let plan: any = null;
    if (plan_id) {
      const { data: p } = await admin
        .from('subscription_plans')
        .select('*')
        .eq('id', plan_id)
        .eq('provider_id', provider_id)
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

    if (!plan) {
      return NextResponse.json(
        { success: false, error: 'Create at least one subscription plan before enrolling a walk-in member.' },
        { status: 400 }
      );
    }

    const durDays = Math.max(1, Number(custom_days) || plan.duration_days || (plan.duration_months ? Number(plan.duration_months) * 30 : 30));
    const planType = plan.plan_type === 'meal_credits' ? 'meal_credits' : 'fixed_period';
    const credits = planType === 'meal_credits' ? (Number(custom_credits) || plan.meal_credits || 60) : null;
    const rawInr = amount_paid_inr != null && amount_paid_inr !== '' ? Number(amount_paid_inr) : null;
    const pricePaise = rawInr != null && Number.isFinite(rawInr) && rawInr >= 10 ? Math.round(rawInr * 100) : Number(plan.price_paise || 0);
    if (pricePaise < 100) {
      return NextResponse.json({ success: false, error: 'Collected amount must be at least ₹1.' }, { status: 400 });
    }
    const normalizedMode = String(payment_mode).toLowerCase().includes('upi') ? 'counter_upi' : 'counter_cash';

    const now = new Date();
    const expiresAt = new Date(now.getTime() + durDays * 24 * 60 * 60 * 1000);

    await ensurePlanSlotsLinked(admin, provider_id);

    // 4. Insert Active Subscription
    const { data: subscription, error: subError } = await admin
      .from('subscriptions')
      .insert({
        customer_id: customerId,
        provider_id: provider_id,
        plan_id: plan.id,
        status: 'active',
        payment_mode: normalizedMode,
        plan_type_snapshot: planType,
        plan_name_snapshot: plan.name || `${durDays}-Day Member Pass`,
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
