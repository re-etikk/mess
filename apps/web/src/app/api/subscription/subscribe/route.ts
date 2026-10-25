import { NextRequest, NextResponse } from 'next/server';
import { platformStore, SubscriptionData } from '@/lib/platform-service';
import crypto from 'crypto';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const customerId = body.customer_id || body.userId || 'cust-ritik-001';
    const providerId = body.provider_id || 'prov-radhe-001';
    const planId = body.plan_id;
    const planType = body.plan_type || 'meal_credits'; // 'fixed_period' | 'meal_credits' | 'daily'
    const durationDays = body.duration_days || (planType === 'fixed_period' ? 30 : 60);
    const mealCredits = body.meal_credits !== undefined ? body.meal_credits : (planType === 'meal_credits' ? 60 : null);
    const pricePaise = body.price_paise || (planType === 'fixed_period' ? 280000 : 480000);
    const paymentId = body.payment_id || `pay_${crypto.randomBytes(6).toString('hex')}`;

    const plan = planId ? platformStore.plans.get(planId) : null;
    const planName = plan ? plan.name : (planType === 'fixed_period' ? 'Fixed-Period Plan' : 'Meal-Tracker Plan');

    const subId = `sub-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
    const newSub: SubscriptionData = {
      id: subId,
      customer_id: customerId,
      provider_id: providerId,
      plan_id: planId || 'plan-custom',
      plan_type: planType,
      plan_name: planName,
      status: 'active',
      starts_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString(),
      remaining_meal_credits: mealCredits,
      initial_meal_credits: mealCredits,
      price_paid_paise: pricePaise,
      razorpay_payment_id: paymentId,
      created_at: new Date().toISOString(),
    };

    platformStore.subscriptions.set(subId, newSub);

    return NextResponse.json({
      success: true,
      subscription: newSub,
      message: `Successfully subscribed to ${planName}!`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to create subscription' },
      { status: 500 }
    );
  }
}
