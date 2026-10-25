import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const customerId = searchParams.get('customer_id');
  const providerId = searchParams.get('provider_id');

  let list = Array.from(platformStore.subscriptions.values());
  if (customerId) {
    list = list.filter((s) => s.customer_id === customerId);
  }
  if (providerId) {
    list = list.filter((s) => s.provider_id === providerId);
  }

  return NextResponse.json({
    success: true,
    total: list.length,
    subscriptions: list,
  });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const customerId = body.customer_id || 'cust-ritik-001';
    const providerId = body.provider_id || 'prov-radhe-001';
    const planType = body.plan_type || 'meal_credits';
    const durationDays = body.duration_days || 30;
    const mealCredits = body.meal_credits || (planType === 'meal_credits' ? 30 : null);
    const pricePaise = body.price_paise || 280000;

    const subId = `sub-${Date.now()}`;
    const newSub = {
      id: subId,
      customer_id: customerId,
      provider_id: providerId,
      plan_id: body.plan_id || 'plan-custom',
      plan_type: planType,
      plan_name: body.plan_name || 'MESS Subscription Plan',
      status: 'active' as const,
      starts_at: new Date().toISOString(),
      expires_at: new Date(Date.now() + durationDays * 24 * 60 * 60 * 1000).toISOString(),
      remaining_meal_credits: mealCredits,
      initial_meal_credits: mealCredits,
      price_paid_paise: pricePaise,
      created_at: new Date().toISOString(),
    };

    platformStore.subscriptions.set(subId, newSub);

    return NextResponse.json({
      success: true,
      subscription: newSub,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message },
      { status: 500 }
    );
  }
}
