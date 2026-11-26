import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireCustomerIdentity } from '@/lib/auth-session';
import {
  resolveAuthoritativePlan,
  resolveVerifiedUpgradeQuote,
} from '@/lib/checkout-pricing';

export const dynamic = 'force-dynamic';

/**
 * Calculates pro-rata upgrade difference strictly from authoritative database records.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const subscriptionId = String(body.subscription_id || body.subscriptionId || '').trim();
    const targetPlanId = String(body.target_plan_id || body.targetPlanId || '').trim();
    const claimedCustomerId = String(body.customer_id || '').trim();

    if (!subscriptionId || !targetPlanId) {
      return NextResponse.json(
        { success: false, error: 'subscription_id and target_plan_id are required.' },
        { status: 400 }
      );
    }

    const auth = await requireCustomerIdentity(req, claimedCustomerId || undefined);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }

    const admin = getAdminClient();
    const providerHint = String(body.provider_id || '').trim();
    const targetPlan = await resolveAuthoritativePlan({
      admin,
      providerId: providerHint,
      planId: targetPlanId,
    });

    if (!targetPlan) {
      return NextResponse.json({ success: false, error: 'Target upgrade plan was not found.' }, { status: 404 });
    }

    const quoteRes = await resolveVerifiedUpgradeQuote({
      admin,
      subscriptionId,
      customerId: auth.userId,
      isAdmin: auth.isAdmin,
      targetPlan,
    });

    if (!quoteRes.ok) {
      return NextResponse.json({ success: false, error: quoteRes.error }, { status: quoteRes.status });
    }

    const { currentSub, remainingDays, residualCreditPaise, payablePaise } = quoteRes;

    return NextResponse.json({
      success: true,
      quote: {
        current_plan_name: currentSub.plan_name || currentSub.plan_name_snapshot || 'Current Pass',
        target_plan_name: targetPlan.name,
        days_remaining: remainingDays,
        current_price_inr: Math.round(Number(currentSub.price_paid_paise || 0) / 100),
        target_price_inr: Math.round(targetPlan.price_paise / 100),
        residual_credit_inr: Math.round(residualCreditPaise / 100),
        payable_inr: Math.round(payablePaise / 100),
        payable_paise: payablePaise,
      },
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err?.message || 'Unable to compute upgrade quote.' },
      { status: 500 }
    );
  }
}
