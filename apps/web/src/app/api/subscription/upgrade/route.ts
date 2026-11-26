import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { addPartnerNotification } from '@/lib/partner-notifications';
import { isAllowedMediaUrl, requireCustomerIdentity } from '@/lib/auth-session';
import {
  resolveAuthoritativePlan,
  resolveVerifiedUpgradeQuote,
} from '@/lib/checkout-pricing';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const subscriptionId = String(body.subscription_id || '').trim();
    const targetPlanId = String(body.target_plan_id || '').trim();
    const paymentMode = body.payment_mode === 'direct_upi' ? 'direct_upi' : 'counter_cash';
    const receiptUrl = String(body.receipt_url || '').trim();
    const utrReference = String(body.utr_reference || '').trim().slice(0, 80);

    if (!subscriptionId || !targetPlanId) {
      return NextResponse.json(
        { success: false, error: 'subscription_id and target_plan_id are required.' },
        { status: 400 }
      );
    }

    if (receiptUrl && !isAllowedMediaUrl(receiptUrl)) {
      return NextResponse.json({ success: false, error: 'Invalid receipt URL.' }, { status: 400 });
    }

    const auth = await requireCustomerIdentity(req, body.customer_id ? String(body.customer_id) : undefined);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }

    const admin = getAdminClient();
    const targetPlan = await resolveAuthoritativePlan({
      admin,
      providerId: String(body.provider_id || '').trim(),
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
    const payableInr = payablePaise / 100;
    const providerId = currentSub.provider_id || targetPlan.provider_id;
    const customerId = currentSub.customer_id || auth.userId;

    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const newSubId =
      admin && isUuid.test(customerId) && isUuid.test(targetPlan.id)
        ? crypto.randomUUID()
        : `sub-upg-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;

    const customerName = currentSub.customer_name || currentSub.profiles?.display_name || 'Customer';
    const customerPhone = currentSub.customer_phone || currentSub.profiles?.phone_e164 || '';

    const upgradeDetails = {
      from_subscription_id: subscriptionId,
      from_plan_name: currentSub.plan_name || currentSub.plan_name_snapshot,
      to_plan_name: targetPlan.name,
      residual_credit_inr: residualCreditPaise / 100,
      target_plan_price_inr: targetPlan.price_paise / 100,
      net_payable_inr: payableInr,
      days_left_snapshot: remainingDays,
      receipt_url: receiptUrl,
      utr_reference: utrReference,
    };

    const now = new Date();
    const expiresIso = new Date(now.getTime() + targetPlan.duration_days * 86400000).toISOString();

    platformStore.subscriptions.set(newSubId, {
      id: newSubId,
      customer_id: customerId,
      customer_name: customerName,
      customer_phone: customerPhone,
      provider_id: providerId,
      plan_id: targetPlan.id,
      plan_type: targetPlan.plan_type,
      plan_name: targetPlan.name,
      status: 'pending_payment',
      starts_at: now.toISOString(),
      expires_at: expiresIso,
      remaining_meal_credits: targetPlan.meal_credits,
      initial_meal_credits: targetPlan.meal_credits,
      price_paid_paise: payablePaise,
      payment_mode: paymentMode,
      created_at: now.toISOString(),
      ...({
        receipt_url: receiptUrl,
        utr_reference: utrReference,
        upgrade_from_subscription_id: subscriptionId,
        upgrade_details: upgradeDetails,
      } as any),
    });

    if (admin && isUuid.test(customerId) && isUuid.test(targetPlan.id)) {
      try {
        await admin.from('subscriptions').insert({
          id: newSubId,
          customer_id: customerId,
          provider_id: providerId,
          plan_id: targetPlan.id,
          status: 'pending_payment',
          plan_type_snapshot: targetPlan.plan_type,
          plan_name_snapshot: targetPlan.name,
          terms_version_snapshot: targetPlan.terms_version,
          price_paid_paise: payablePaise,
          initial_meal_credits: targetPlan.meal_credits,
          remaining_meal_credits: targetPlan.meal_credits,
          starts_at: now.toISOString(),
          expires_at: expiresIso,
          payment_mode: paymentMode,
          delivery_instructions: currentSub.delivery_instructions || null,
        });
      } catch (e) {
        console.warn('DB error inserting upgrade sub:', e);
      }
    }

    addPartnerNotification({
      provider_id: providerId,
      type: 'plan_upgrade',
      title: 'Plan Upgrade Request',
      message: `${customerName} requested an upgrade from ${currentSub.plan_name || currentSub.plan_name_snapshot || 'Current Pass'} to ${targetPlan.name}. Net payable: ₹${payableInr.toFixed(0)}.`,
      customer_name: customerName,
      customer_phone: customerPhone,
      amount_inr: payableInr,
      subscription_id: newSubId,
    });

    return NextResponse.json({
      success: true,
      message: `Upgrade request submitted. Pay ₹${payableInr.toFixed(0)} at counter for approval.`,
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
