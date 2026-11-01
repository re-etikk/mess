import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || params.get('providerId') || '';
  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  const db = getAdminClient();
  if (!db) return NextResponse.json({ success: false, error: 'Plan data service is not configured.' }, { status: 503 });
  const { data, error } = await db.from('subscription_plans')
    .select('id,provider_id,name,description,plan_type,duration_months,meal_credits,price_paise,currency,promo_price_paise,daily_meal_limit,allow_pickup,allow_delivery,cancellation_policy,missed_meal_policy,terms_version,published,active,created_at')
    .eq('provider_id', providerId).order('created_at', { ascending: false });
  if (error) return NextResponse.json({ success: false, error: 'Plans could not be loaded.' }, { status: 503 });
  return NextResponse.json({ success: true, plans: data ?? [] }, { headers: { 'Cache-Control': 'private, no-store' } });
}

const CreatePlan = z.object({
  provider_id: z.string().uuid(),
  name: z.string().trim().min(2).max(100),
  description: z.string().trim().max(1000).optional().default(''),
  plan_type: z.enum(['fixed_period', 'meal_credits']),
  duration_months: z.number().int().refine((value) => [1, 3, 6, 12].includes(value)).optional(),
  duration_days: z.number().int().optional(),
  meal_credits: z.number().int().positive().optional(),
  price_paise: z.number().int().nonnegative().optional(),
  price_inr: z.number().nonnegative().optional(),
  daily_meal_limit: z.number().int().positive().max(10).default(1),
  published: z.boolean().default(true),
}).superRefine((value, ctx) => {
  if (value.plan_type === 'fixed_period' && !value.duration_months && !([30, 90, 180, 360].includes(value.duration_days || -1))) {
    ctx.addIssue({ code: 'custom', path: ['duration_months'], message: 'Choose a supported plan duration.' });
  }
  if (value.plan_type === 'meal_credits' && !value.meal_credits) ctx.addIssue({ code: 'custom', path: ['meal_credits'], message: 'Meal credits are required.' });
  if (value.price_paise === undefined && value.price_inr === undefined) ctx.addIssue({ code: 'custom', path: ['price_paise'], message: 'Plan price is required.' });
});

export async function POST(req: NextRequest) {
  let body: unknown;
  try { body = await req.json(); } catch { return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 }); }
  const parsed = CreatePlan.safeParse(body);
  if (!parsed.success) return NextResponse.json({ success: false, error: 'Invalid plan details.', details: parsed.error.flatten() }, { status: 400 });
  const input = parsed.data;
  const access = await requireProviderOwnership(req, input.provider_id);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  const db = getAdminClient();
  if (!db) return NextResponse.json({ success: false, error: 'Plan data service is not configured.' }, { status: 503 });

  const durationMonths = input.duration_months ?? (input.duration_days ? input.duration_days / 30 : null);
  const { data, error } = await db.from('subscription_plans').insert({
    provider_id: input.provider_id,
    name: input.name,
    description: input.description || null,
    plan_type: input.plan_type,
    duration_months: input.plan_type === 'fixed_period' ? durationMonths : null,
    meal_credits: input.plan_type === 'meal_credits' ? input.meal_credits : null,
    price_paise: input.price_paise ?? Math.round((input.price_inr || 0) * 100),
    daily_meal_limit: input.daily_meal_limit,
    allow_pickup: true,
    allow_delivery: false,
    cancellation_policy: 'Refunds are handled under the published Thali refund policy.',
    missed_meal_policy: 'A meal credit is consumed only after a verified on-premise redemption; unused entitlements expire under the plan validity terms.',
    terms_version: '1',
    published: input.published,
    active: true,
  }).select('id,provider_id,name,description,plan_type,duration_months,meal_credits,price_paise,published,active,created_at').single();
  if (error) {
    console.error('Provider plan creation failed:', error.message);
    return NextResponse.json({ success: false, error: 'Plan could not be saved. Confirm the provider is active and the database schema is current.' }, { status: 503 });
  }
  return NextResponse.json({ success: true, plan: data }, { status: 201 });
}

export async function DELETE(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || '';
  const planId = params.get('plan_id') || '';
  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  const db = getAdminClient();
  if (!db) return NextResponse.json({ success: false, error: 'Plan data service is not configured.' }, { status: 503 });
  const { error } = await db.from('subscription_plans').delete().eq('id', planId).eq('provider_id', providerId);
  if (error) return NextResponse.json({ success: false, error: 'Plan cannot be removed while records depend on it.' }, { status: 409 });
  return NextResponse.json({ success: true });
}
