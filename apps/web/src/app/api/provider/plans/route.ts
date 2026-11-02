import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || params.get('providerId') || '';
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });

  const access = await requireProviderOwnership(req, providerId);
  const db = getAdminClient();

  try {
    const client = db || (await createClient());
    let query = client
      .from('subscription_plans')
      .select('*')
      .eq('provider_id', providerId);

    if (!access.ok) {
      query = query.eq('active', true);
    }

    const { data: rawPlans, error } = await query.order('created_at', { ascending: false });
    if (error) {
      console.error('Error fetching plans:', error.message);
      return NextResponse.json({ success: true, plans: [] });
    }

    const plans = (rawPlans ?? []).map((p) => {
      const durMonths = p.duration_months || 1;
      const durDays = durMonths * 30;
      const pricePaise = Number(p.price_paise || 0);
      const promoPaise = p.promo_price_paise ? Number(p.promo_price_paise) : null;
      const discount = promoPaise && pricePaise > 0
        ? Math.round(((pricePaise - promoPaise) / pricePaise) * 100)
        : null;

      return {
        ...p,
        duration_days: durDays,
        price: pricePaise / 100,
        price_inr: pricePaise / 100,
        discount_percent: discount,
      };
    });

    return NextResponse.json({ success: true, plans }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (err) {
    console.error('Provider plans GET error:', err);
    return NextResponse.json({ success: true, plans: [] });
  }
}

const CreatePlanInput = z.object({
  provider_id: z.string().min(1),
  id: z.string().optional(),
  name: z.string().trim().min(1).max(100),
  description: z.string().trim().max(1000).optional().default(''),
  plan_type: z.string().default('fixed_period'),
  duration_months: z.number().optional(),
  duration_days: z.number().optional(),
  meal_credits: z.number().optional(),
  price_paise: z.number().optional(),
  price_inr: z.number().optional(),
  discount_percent: z.number().optional(),
  daily_meal_limit: z.number().default(1),
  meal_slot_ids: z.array(z.string()).default([]),
  published: z.boolean().default(true),
});

export async function POST(req: NextRequest) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }

  const parsed = CreatePlanInput.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ success: false, error: 'Invalid plan details.', details: parsed.error.flatten() }, { status: 400 });
  }

  const input = parsed.data;
  const access = await requireProviderOwnership(req, input.provider_id);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const db = getAdminClient();
  if (!db) {
    return NextResponse.json({ success: false, error: 'Plan data service is not configured.' }, { status: 503 });
  }

  const planType = input.plan_type === 'meal_credits' ? 'meal_credits' : 'fixed_period';
  const durationDays = input.duration_days || (input.duration_months ? input.duration_months * 30 : 30);
  const durationMonths = Math.max(1, Math.round(durationDays / 30));
  const pricePaise = input.price_paise ?? Math.round((input.price_inr || 0) * 100);
  const promoPricePaise = input.discount_percent && input.discount_percent > 0
    ? Math.round(pricePaise * (1 - input.discount_percent / 100))
    : null;

  try {
    // If updating existing plan
    if (input.id) {
      const { data: updated, error: updateError } = await db
        .from('subscription_plans')
        .update({
          name: input.name,
          description: input.description,
          plan_type: planType,
          duration_months: planType === 'fixed_period' ? durationMonths : null,
          meal_credits: planType === 'meal_credits' ? (input.meal_credits || 60) : null,
          price_paise: pricePaise,
          promo_price_paise: promoPricePaise,
          published: true,
          active: true,
          updated_at: new Date().toISOString(),
        })
        .eq('id', input.id)
        .eq('provider_id', input.provider_id)
        .select('*')
        .single();

      if (updateError) throw updateError;
      return NextResponse.json({ success: true, plan: updated });
    }

    // Insert new plan
    const { data: newPlan, error: insertError } = await db
      .from('subscription_plans')
      .insert({
        provider_id: input.provider_id,
        name: input.name,
        description: input.description || `${durationDays}-day mess subscription`,
        plan_type: planType,
        duration_months: planType === 'fixed_period' ? durationMonths : null,
        meal_credits: planType === 'meal_credits' ? (input.meal_credits || 60) : null,
        price_paise: pricePaise,
        promo_price_paise: promoPricePaise,
        daily_meal_limit: input.daily_meal_limit,
        allow_pickup: true,
        allow_delivery: false,
        published: true,
        active: true,
      })
      .select('*')
      .single();

    if (insertError) throw insertError;

    // Link plan to meal slots
    let slotIds = input.meal_slot_ids;
    if (slotIds.length === 0) {
      const { data: slots } = await db
        .from('meal_slots')
        .select('id')
        .eq('provider_id', input.provider_id)
        .eq('active', true);
      slotIds = (slots ?? []).map((s) => s.id);
    }

    if (slotIds.length > 0 && newPlan?.id) {
      const links = slotIds.map((slotId) => ({ plan_id: newPlan.id, meal_slot_id: slotId }));
      await db.from('plan_meal_slots').insert(links);
    }

    return NextResponse.json({ success: true, plan: newPlan }, { status: 201 });
  } catch (error: any) {
    console.error('Provider plan creation error:', error?.message);
    return NextResponse.json({ success: false, error: error?.message || 'Failed to save plan.' }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  let body: any = {};
  try { body = await req.json(); } catch {}

  const providerId = params.get('provider_id') || body.provider_id || '';
  const planId = params.get('plan_id') || body.plan_id || '';

  if (!providerId || !planId) {
    return NextResponse.json({ success: false, error: 'provider_id and plan_id are required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const db = getAdminClient();
  if (!db) return NextResponse.json({ success: false, error: 'Plan data service is not configured.' }, { status: 503 });

  try {
    await db.from('plan_meal_slots').delete().eq('plan_id', planId);
    const { error } = await db.from('subscription_plans').delete().eq('id', planId).eq('provider_id', providerId);
    if (error) {
      // If records depend on it, soft-delete
      await db.from('subscription_plans').update({ active: false, published: false }).eq('id', planId).eq('provider_id', providerId);
    }
    return NextResponse.json({ success: true, message: 'Plan deleted successfully.' });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err?.message || 'Failed to delete plan.' }, { status: 500 });
  }
}
