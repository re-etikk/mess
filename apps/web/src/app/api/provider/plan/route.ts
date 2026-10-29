import { NextRequest, NextResponse } from 'next/server';
import { platformStore, PlanData } from '@/lib/platform-service';
import { requireProviderOwnership } from '@/lib/provider-auth';
import crypto from 'crypto';

export const dynamic = 'force-dynamic';

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

    // Enforce Tenant Authorization / IDOR Protection
    const auth = await requireProviderOwnership(req, providerId);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }

    const planIdParam = body.id || body.plan_id;
    const name = body.name?.trim();
    const planType = body.plan_type || 'fixed_period'; // 'fixed_period' | 'meal_credits' | 'daily'
    const durationDays = Number(body.duration_days) || 30;
    const pricePaise = Number(body.price_paise) || (Number(body.price_inr) * 100) || 280000;
    const mealCredits = body.meal_credits !== undefined && body.meal_credits !== null ? Number(body.meal_credits) : (planType === 'meal_credits' ? 60 : null);
    const discountPercent = body.discount_percent !== undefined ? Number(body.discount_percent) : 0;
    const description = body.description || `${durationDays}-day ${name || 'Meal Plan'}`;

    if (!name && !planIdParam) {
      return NextResponse.json(
        { success: false, error: 'Plan name is required.' },
        { status: 400 }
      );
    }

    if (planIdParam && platformStore.plans.has(planIdParam)) {
      // Edit existing plan
      const existing = platformStore.plans.get(planIdParam)!;
      if (name) existing.name = name;
      existing.plan_type = planType;
      existing.duration_days = durationDays;
      existing.price_paise = pricePaise;
      existing.meal_credits = mealCredits;
      existing.discount_percent = discountPercent;
      existing.description = description;
      if (body.is_active !== undefined) existing.is_active = Boolean(body.is_active);

      return NextResponse.json({
        success: true,
        plan: existing,
        message: `Plan "${existing.name}" updated successfully.`,
      });
    }

    const planId = planIdParam || `plan-${Date.now()}-${crypto.randomBytes(3).toString('hex')}`;
    const newPlan: PlanData = {
      id: planId,
      provider_id: providerId,
      name: name || 'Custom Meal Plan',
      description,
      plan_type: planType,
      duration_days: durationDays,
      price_paise: pricePaise,
      currency: 'INR',
      meal_credits: mealCredits,
      daily_meal_limit: Number(body.daily_meal_limit) || 2,
      discount_percent: discountPercent,
      is_active: true,
      created_at: new Date().toISOString(),
    };

    platformStore.plans.set(planId, newPlan);

    return NextResponse.json({
      success: true,
      plan: newPlan,
      message: `Plan "${newPlan.name}" created successfully!`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to create plan' },
      { status: 500 }
    );
  }
}

export async function DELETE(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const planId = searchParams.get('plan_id') || searchParams.get('id');
  const providerId = searchParams.get('provider_id') || searchParams.get('providerId') || 'prov-radhe-001';

  if (!planId) {
    return NextResponse.json({ success: false, error: 'Plan ID is required.' }, { status: 400 });
  }

  // Enforce Tenant Authorization / IDOR Protection
  const auth = await requireProviderOwnership(req, providerId);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  if (platformStore.plans.has(planId)) {
    platformStore.plans.delete(planId);
    return NextResponse.json({ success: true, message: 'Plan deleted successfully.' });
  }

  return NextResponse.json({ success: false, error: 'Plan not found.' }, { status: 404 });
}
