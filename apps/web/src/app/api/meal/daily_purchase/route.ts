import { NextRequest, NextResponse } from 'next/server';
import { platformStore, SubscriptionData, getCurrentMealSlot } from '@/lib/platform-service';
import crypto from 'crypto';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const customerId = body.customer_id || body.userId || 'cust-ritik-001';
    const providerId = body.provider_id || 'prov-radhe-001';
    const slot = body.slot || getCurrentMealSlot();
    const pricePaise = body.price_paise || 9900; // ₹99
    const paymentId = body.payment_id || `pay_${crypto.randomBytes(6).toString('hex')}`;

    const subId = `daily-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
    const dailyPass: SubscriptionData = {
      id: subId,
      customer_id: customerId,
      provider_id: providerId,
      plan_id: 'plan-daily-single',
      plan_type: 'daily',
      plan_name: `Single Daily Meal (${slot})`,
      status: 'active',
      starts_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
      remaining_meal_credits: 1,
      initial_meal_credits: 1,
      price_paid_paise: pricePaise,
      razorpay_payment_id: paymentId,
      created_at: new Date().toISOString(),
    };

    platformStore.subscriptions.set(subId, dailyPass);

    return NextResponse.json({
      success: true,
      daily_pass: dailyPass,
      message: `Daily meal pass purchased for ${slot}! Ready to scan at the counter.`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to purchase daily meal' },
      { status: 500 }
    );
  }
}
