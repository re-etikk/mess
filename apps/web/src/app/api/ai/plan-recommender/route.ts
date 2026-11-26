import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { recommendBestPlan } from '@/lib/ai-service';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = String(body.provider_id || '').trim();
  const weeklyDays = Math.min(7, Math.max(1, Number(body.weekly_days || 6)));
  const weeklySkips = Math.min(10, Math.max(0, Number(body.weekly_skips || 0)));
  const mealsPerDay = Math.min(3, Math.max(1, Number(body.meals_per_day || 2)));

  let plans: any[] = Array.isArray(body.plans) ? body.plans : [];

  if (plans.length === 0 && providerId) {
    const admin = getAdminClient();
    if (admin) {
      try {
        const { data } = await admin
          .from('subscription_plans')
          .select('id,name,plan_type,duration_days,price_paise,meal_credits')
          .eq('provider_id', providerId)
          .eq('active', true);
        if (data && data.length > 0) {
          plans = data.map((p: any) => ({
            id: p.id,
            name: p.name,
            plan_type: p.plan_type || 'fixed_period',
            duration_days: Number(p.duration_days || 30),
            price_inr: Math.round(Number(p.price_paise || 0) / 100),
            meal_credits: p.meal_credits,
          }));
        }
      } catch {}
    }

    if (plans.length === 0) {
      for (const p of platformStore.plans.values()) {
        if (p.provider_id === providerId && p.is_active) {
          plans.push({
            id: p.id,
            name: p.name,
            plan_type: p.plan_type,
            duration_days: p.duration_days,
            price_inr: Math.round(p.price_paise / 100),
            meal_credits: p.meal_credits,
          });
        }
      }
    }
  }

  const recommendation = recommendBestPlan({
    plans,
    weeklyDays,
    weeklySkips,
    mealsPerDay,
  });

  return NextResponse.json({
    success: true,
    ...recommendation,
  });
}
