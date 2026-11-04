import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

/**
 * Calculates OTT-style (Hotstar/Netflix) pro-rata upgrade difference.
 * - Deducts unused days or meal credits value from current active subscription.
 * - Net payable = max(0, targetPlanPrice - residualCreditValue).
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const subscriptionId = body.subscription_id || body.subscriptionId;
    const targetPlanId = body.target_plan_id || body.targetPlanId;

    if (!subscriptionId || !targetPlanId) {
      return NextResponse.json(
        { success: false, error: 'subscription_id and target_plan_id are required.' },
        { status: 400 }
      );
    }

    let currentSub: any = null;
    let targetPlan: any = null;

    // 1. Fetch from Supabase DB if available
    const admin = getAdminClient();
    if (admin) {
      try {
        const { data: s } = await admin
          .from('subscriptions')
          .select('*')
          .eq('id', subscriptionId)
          .maybeSingle();
        if (s) currentSub = s;

        const { data: p } = await admin
          .from('subscription_plans')
          .select('*')
          .eq('id', targetPlanId)
          .maybeSingle();
        if (p) targetPlan = p;
      } catch (e) {
        console.warn('DB error fetching sub or plan for upgrade quote:', e);
      }
    }

    // 2. Fetch from platformStore
    if (!currentSub) {
      currentSub = platformStore.subscriptions.get(subscriptionId);
    }
    if (!targetPlan) {
      targetPlan = platformStore.plans.get(targetPlanId);
    }

    if (!currentSub) {
      return NextResponse.json({ success: false, error: 'Active subscription not found.' }, { status: 404 });
    }
    if (!targetPlan) {
      return NextResponse.json({ success: false, error: 'Target upgrade plan not found.' }, { status: 404 });
    }

    // Ensure current subscription is active
    if (currentSub.status !== 'active') {
      return NextResponse.json(
        { success: false, error: `Only active passes can be upgraded. Current status: ${currentSub.status}` },
        { status: 400 }
      );
    }

    const now = Date.now();
    const expiresAt = new Date(currentSub.expires_at).getTime();
    const remainingMs = Math.max(0, expiresAt - now);
    const remainingDays = Math.ceil(remainingMs / (1000 * 60 * 60 * 24));
    const totalDays = currentSub.duration_days || (currentSub.plan_type === 'meal_credits' ? 45 : 30);
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

    // Upgrade payable amount
    const payablePaise = Math.max(0, targetPlanPricePaise - residualCreditPaise);

    return NextResponse.json({
      success: true,
      quote: {
        current_subscription_id: currentSub.id,
        current_plan_name: currentSub.plan_name || currentSub.plan_name_snapshot || 'Current Pass',
        current_plan_type: currentSub.plan_type || currentSub.plan_type_snapshot,
        current_plan_paid_inr: (pricePaidPaise / 100),
        days_remaining: remainingDays,
        credits_remaining: currentSub.remaining_meal_credits ?? null,
        unused_percentage: Math.round(unusedFraction * 100),
        residual_credit_inr: (residualCreditPaise / 100),
        residual_credit_paise: residualCreditPaise,
        target_plan_id: targetPlan.id,
        target_plan_name: targetPlan.name,
        target_plan_type: targetPlan.plan_type,
        target_plan_price_inr: (targetPlanPricePaise / 100),
        target_plan_price_paise: targetPlanPricePaise,
        upgrade_payable_inr: (payablePaise / 100),
        upgrade_payable_paise: payablePaise,
        savings_message: residualCreditPaise > 0
          ? `Saved ₹${(residualCreditPaise / 100).toFixed(0)} from your current remaining validity!`
          : 'Full upgrade price applies.',
      },
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err?.message || 'Server error calculating upgrade quote.' },
      { status: 500 }
    );
  }
}
