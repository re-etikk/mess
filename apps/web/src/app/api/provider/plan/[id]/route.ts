import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function PUT(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const planId = params.id;
    const plan = platformStore.plans.get(planId);
    if (!plan) {
      return NextResponse.json({ success: false, error: 'Plan not found.' }, { status: 404 });
    }

    const body = await req.json().catch(() => ({}));
    if (body.name !== undefined) plan.name = body.name;
    if (body.description !== undefined) plan.description = body.description;
    if (body.price_paise !== undefined) plan.price_paise = Number(body.price_paise);
    if (body.duration_days !== undefined) plan.duration_days = Number(body.duration_days);
    if (body.meal_credits !== undefined) plan.meal_credits = Number(body.meal_credits);
    if (body.is_active !== undefined) plan.is_active = Boolean(body.is_active);

    return NextResponse.json({
      success: true,
      plan,
      message: 'Plan updated successfully.',
    });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err.message }, { status: 500 });
  }
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const planId = params.id;
  platformStore.plans.delete(planId);
  return NextResponse.json({ success: true, message: 'Plan deleted.' });
}
