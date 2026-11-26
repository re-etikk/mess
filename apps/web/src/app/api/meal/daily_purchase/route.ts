import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { addPartnerNotification } from '@/lib/partner-notifications';
import { ensurePlanSlotsLinked, requireCustomerIdentity } from '@/lib/auth-session';

export const dynamic = 'force-dynamic';

/**
 * Registers a single-meal counter-cash request in `pending_payment` status.
 * Authoritative price comes strictly from kitchen plans/menu items; pass only becomes active
 * after partner confirms counter cash collection.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = String(body.provider_id || '').trim();
    const slot = String(body.slot || 'LUNCH').toUpperCase().trim();
    const claimedCustomerId = String(body.customer_id || '').trim();

    if (!providerId) {
      return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
    }

    const auth = await requireCustomerIdentity(req, claimedCustomerId || undefined);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }
    const customerId = auth.userId;

    const admin = getAdminClient();
    if (!admin) {
      return NextResponse.json(
        { success: false, error: 'Database service unavailable for daily meal purchase.' },
        { status: 503 }
      );
    }

    const { data: provider } = await admin
      .from('providers')
      .select('id, display_name, status')
      .eq('id', providerId)
      .maybeSingle();

    if (!provider) {
      return NextResponse.json({ success: false, error: 'Kitchen not found.' }, { status: 404 });
    }

    // Look up authoritative single-meal price from provider's 1-credit plan or active menu items
    let { data: dailyPlan } = await admin
      .from('subscription_plans')
      .select('*')
      .eq('provider_id', providerId)
      .eq('plan_type', 'meal_credits')
      .eq('meal_credits', 1)
      .eq('active', true)
      .maybeSingle();

    if (!dailyPlan) {
      const { data: menuPrices } = await admin
        .from('menu_items')
        .select('price_paise')
        .eq('provider_id', providerId)
        .eq('active', true)
        .eq('is_add_on', false)
        .gt('price_paise', 0)
        .order('price_paise', { ascending: true })
        .limit(1);

      const authoritativePricePaise =
        menuPrices && menuPrices.length > 0 && Number(menuPrices[0].price_paise) >= 1000
          ? Number(menuPrices[0].price_paise)
          : 8000;

      const { data: createdPlan, error: planErr } = await admin
        .from('subscription_plans')
        .insert({
          provider_id: providerId,
          name: `Daily ${slot} Pass`,
          description: 'Single meal coupon for today',
          plan_type: 'meal_credits',
          duration_months: null,
          meal_credits: 1,
          price_paise: authoritativePricePaise,
          daily_meal_limit: 1,
          cancellation_policy: 'Valid for today only.',
          missed_meal_policy: 'Unused daily pass expires after today.',
          published: false,
          active: true,
        })
        .select('*')
        .single();

      if (planErr || !createdPlan) {
        return NextResponse.json({ success: false, error: 'Could not prepare daily meal pass plan.' }, { status: 500 });
      }
      dailyPlan = createdPlan;
    }

    await ensurePlanSlotsLinked(admin, providerId);

    const now = new Date();
    const expiresAt = new Date(now.getTime() + 24 * 60 * 60 * 1000);
    const subId = crypto.randomUUID();
    const pricePaise = Number(dailyPlan.price_paise || 8000);

    const { data: subscription, error: subErr } = await admin
      .from('subscriptions')
      .insert({
        id: subId,
        customer_id: customerId,
        provider_id: providerId,
        plan_id: dailyPlan.id,
        status: 'pending_payment',
        plan_type_snapshot: 'meal_credits',
        plan_name_snapshot: dailyPlan.name || `Daily ${slot} Pass`,
        terms_version_snapshot: String(dailyPlan.terms_version || '1'),
        price_paid_paise: pricePaise,
        initial_meal_credits: 1,
        remaining_meal_credits: 1,
        starts_at: now.toISOString(),
        expires_at: expiresAt.toISOString(),
        payment_mode: 'counter_cash',
      })
      .select('*')
      .single();

    if (subErr || !subscription) {
      return NextResponse.json({ success: false, error: 'Could not register daily pass request.' }, { status: 500 });
    }

    platformStore.subscriptions.set(subId, {
      id: subId,
      customer_id: customerId,
      provider_id: providerId,
      plan_id: dailyPlan.id,
      plan_type: 'meal_credits',
      plan_name: dailyPlan.name,
      status: 'pending_payment',
      starts_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      remaining_meal_credits: 1,
      initial_meal_credits: 1,
      price_paid_paise: pricePaise,
      payment_mode: 'counter_cash',
      created_at: now.toISOString(),
    });

    addPartnerNotification({
      provider_id: providerId,
      type: 'pending_payment',
      title: 'Single Meal Cash Request',
      message: `Customer requested a ₹${Math.round(pricePaise / 100)} ${slot} counter pass. Collect cash and approve before QR scan.`,
      amount_inr: Math.round(pricePaise / 100),
      subscription_id: subId,
    });

    return NextResponse.json({
      success: true,
      entitlement: {
        id: subscription.id,
        provider_id: providerId,
        provider_name: provider.display_name,
        slot,
        payment_method: 'counter_cash',
        status: 'pending_payment',
        amount_inr: Math.round(pricePaise / 100),
        is_paid: false,
      },
      message: `Counter cash pass (₹${Math.round(pricePaise / 100)}) requested. Partner will approve once cash is collected.`,
    });
  } catch (err: any) {
    console.error('Daily purchase API error:', err?.message);
    return NextResponse.json(
      { success: false, error: 'Unable to register daily meal pass.' },
      { status: 500 }
    );
  }
}
