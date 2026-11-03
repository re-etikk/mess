import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { addPartnerNotification } from '@/lib/partner-notifications';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const {
      subscription_id,
      target_plan_id,
      payment_mode = 'counter_cash',
      receipt_url = '',
      utr_reference = '',
    } = body;

    if (!subscription_id || !target_plan_id) {
      return NextResponse.json(
        { success: false, error: 'subscription_id and target_plan_id are required.' },
        { status: 400 }
      );
    }

    let currentSub: any = null;
    let targetPlan: any = null;

    // 1. Fetch from Supabase DB
    const admin = getAdminClient();
    if (admin) {
      try {
        const { data: s } = await admin
          .from('subscriptions')
          .select('*, profiles:customer_id(display_name, phone_e164)')
          .eq('id', subscription_id)
          .maybeSingle();
        if (s) currentSub = s;

        const { data: p } = await admin
          .from('subscription_plans')
          .select('*')
          .eq('id', target_plan_id)
          .maybeSingle();
        if (p) targetPlan = p;
      } catch (e) {
        console.warn('DB error fetching sub or plan for upgrade:', e);
      }
    }

    // 2. Fetch from platformStore
    if (!currentSub) {
      currentSub = platformStore.subscriptions.get(subscription_id);
    }
    if (!targetPlan) {
      targetPlan = platformStore.plans.get(target_plan_id);
    }

    if (!currentSub) {
      return NextResponse.json({ success: false, error: 'Active subscription not found.' }, { status: 404 });
    }
    if (!targetPlan) {
      return NextResponse.json({ success: false, error: 'Target upgrade plan not found.' }, { status: 404 });
    }

    // Pro-rata calculation
    const now = Date.now();
    const expiresAt = new Date(currentSub.expires_at).getTime();
    const remainingMs = Math.max(0, expiresAt - now);
    const remainingDays = Math.ceil(remainingMs / (1000 * 60 * 60 * 24));
    const totalDays = currentSub.duration_days || 30;
    const pricePaidPaise = Number(currentSub.price_paid_paise) || 280000;
    const targetPlanPricePaise = Number(targetPlan.price_paise) || 480000;

    let residualCreditPaise = 0;
    let unusedFraction = 0;

    if (currentSub.plan_type === 'meal_credits' || currentSub.plan_type_snapshot === 'meal_credits') {
      const remainingCredits = currentSub.remaining_meal_credits ?? 0;
      const initialCredits = currentSub.initial_meal_credits ?? 60;
      unusedFraction = initialCredits > 0 ? Math.min(1, Math.max(0, remainingCredits / initialCredits)) : 0;
      residualCreditPaise = Math.round(pricePaidPaise * unusedFraction);
    } else {
      unusedFraction = totalDays > 0 ? Math.min(1, Math.max(0, remainingDays / totalDays)) : 0;
      residualCreditPaise = Math.round(pricePaidPaise * unusedFraction);
    }

    const payablePaise = Math.max(0, targetPlanPricePaise - residualCreditPaise);
    const payableInr = payablePaise / 100;

    const newSubId = `sub-upg-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
    const customerName = currentSub.customer_name || currentSub.profiles?.display_name || 'Customer';
    const customerPhone = currentSub.customer_phone || currentSub.profiles?.phone_e164 || '';
    const providerId = currentSub.provider_id;

    const upgradeDetails = {
      from_subscription_id: subscription_id,
      from_plan_name: currentSub.plan_name || currentSub.plan_name_snapshot,
      to_plan_name: targetPlan.name,
      residual_credit_inr: residualCreditPaise / 100,
      target_plan_price_inr: targetPlanPricePaise / 100,
      net_payable_inr: payableInr,
      days_left_snapshot: remainingDays,
      receipt_url,
      utr_reference,
    };

    // Store in platformStore
    platformStore.subscriptions.set(newSubId, {
      id: newSubId,
      customer_id: currentSub.customer_id,
      customer_name: customerName,
      customer_phone: customerPhone,
      provider_id: providerId,
      plan_id: targetPlan.id,
      plan_type: targetPlan.plan_type,
      plan_name: targetPlan.name,
      status: 'pending_payment',
      starts_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + (targetPlan.duration_days || 30) * 24 * 60 * 60 * 1000).toISOString(),
      remaining_meal_credits: targetPlan.meal_credits || null,
      initial_meal_credits: targetPlan.meal_credits || null,
      price_paid_paise: payablePaise,
      payment_mode,
      created_at: new Date().toISOString(),
      ...({
        receipt_url,
        utr_reference,
        upgrade_from_subscription_id: subscription_id,
        upgrade_details: upgradeDetails,
      } as any),
    });

    // Also insert into Supabase DB if available
    if (admin) {
      try {
        await admin.from('subscriptions').insert({
          id: crypto.randomUUID(),
          customer_id: currentSub.customer_id,
          provider_id: providerId,
          plan_id: targetPlan.id,
          status: 'pending_payment',
          plan_type_snapshot: targetPlan.plan_type,
          plan_name_snapshot: targetPlan.name,
          terms_version_snapshot: 'v1.0-upgrade',
          price_paid_paise: payablePaise,
          initial_meal_credits: targetPlan.meal_credits || null,
          remaining_meal_credits: targetPlan.meal_credits || null,
          starts_at: new Date().toISOString(),
          expires_at: new Date(Date.now() + (targetPlan.duration_days || 30) * 24 * 60 * 60 * 1000).toISOString(),
        });
      } catch (e) {
        console.warn('DB error inserting upgrade sub:', e);
      }
    }

    // Send notification to Mess Partner
    addPartnerNotification({
      provider_id: providerId,
      type: 'plan_upgrade',
      title: 'Plan Upgrade Request',
      message: `${customerName} requested an upgrade from ${currentSub.plan_name || 'Current Pass'} to ${targetPlan.name}. Net payable: ₹${payableInr.toFixed(0)}. Please verify payment and approve.`,
      customer_name: customerName,
      customer_phone: customerPhone,
      amount_inr: payableInr,
      subscription_id: newSubId,
    });

    return NextResponse.json({
      success: true,
      message: `Upgrade request submitted! Please pay ₹${payableInr.toFixed(0)} to activate.`,
      subscription_id: newSubId,
      status: 'pending_payment',
      payable_inr: payableInr,
      upgrade_details: upgradeDetails,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err?.message || 'Server error processing upgrade.' },
      { status: 500 }
    );
  }
}
