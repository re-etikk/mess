import { NextRequest, NextResponse } from 'next/server';
import { platformStore, PlanData } from '@/lib/platform-service';
import crypto from 'crypto';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';

  const plans = Array.from(platformStore.plans.values()).filter(
    (p) => p.provider_id === providerId
  );

  return NextResponse.json({
    success: true,
    plans,
  });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || 'prov-radhe-001';
    const name = body.name;
    const planType = body.plan_type || 'fixed_period'; // 'fixed_period' | 'meal_credits' | 'daily'
    const durationDays = Number(body.duration_days) || 30;
    const pricePaise = Number(body.price_paise) || 280000;
    const mealCredits = body.meal_credits !== undefined ? Number(body.meal_credits) : (planType === 'meal_credits' ? 60 : null);
    const description = body.description || `${durationDays}-day ${name}`;

    if (!name) {
      return NextResponse.json(
        { success: false, error: 'Plan name is required.' },
        { status: 400 }
      );
    }

    const planId = `plan-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
    const newPlan: PlanData = {
      id: planId,
      provider_id: providerId,
      name,
      description,
      plan_type: planType,
      duration_days: durationDays,
      price_paise: pricePaise,
      currency: 'INR',
      meal_credits: mealCredits,
      daily_meal_limit: Number(body.daily_meal_limit) || 2,
      is_active: true,
      created_at: new Date().toISOString(),
    };

    platformStore.plans.set(planId, newPlan);

    return NextResponse.json({
      success: true,
      plan: newPlan,
      message: `Plan "${name}" created successfully.`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to create plan' },
      { status: 500 }
    );
  }
}
