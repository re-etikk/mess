import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id');

  if (!providerId) {
    return NextResponse.json(
      { success: false, error: 'provider_id is required.' },
      { status: 400 }
    );
  }

  const subMap = new Map<string, any>();

  // 1. Read from in-memory platformStore
  for (const s of platformStore.subscriptions.values()) {
    if (s.provider_id === providerId) {
      subMap.set(s.id, {
        id: s.id,
        customer_id: s.customer_id,
        customer_name: s.customer_name || 'Student Member',
        customer_phone: s.customer_phone || '',
        customer_email: s.customer_email || '',
        plan_id: s.plan_id,
        plan_name: s.plan_name,
        plan_type: s.plan_type,
        status: s.status,
        starts_at: s.starts_at,
        expires_at: s.expires_at,
        remaining_meal_credits: s.remaining_meal_credits,
        initial_meal_credits: s.initial_meal_credits,
        price_paid_paise: s.price_paid_paise,
        payment_mode: s.payment_mode || 'online',
        created_at: s.created_at,
      });
    }
  }

  // 2. Query Supabase table if accessible
  try {
    const admin = getAdminClient();
    if (admin) {
      const { data: dbSubs } = await admin
        .from('subscriptions')
        .select('*')
        .eq('provider_id', providerId)
        .order('created_at', { ascending: false });

      if (dbSubs) {
        for (const s of dbSubs) {
          if (!subMap.has(s.id)) {
            subMap.set(s.id, {
              id: s.id,
              customer_id: s.customer_id,
              customer_name: s.customer_name || 'Student Member',
              customer_phone: s.customer_phone || '',
              customer_email: s.customer_email || '',
              plan_id: s.plan_id,
              plan_name: s.plan_name || 'Active Plan',
              plan_type: s.remaining_meal_credits !== null ? 'meal_credits' : 'fixed_period',
              status: s.status,
              starts_at: s.starts_at,
              expires_at: s.expires_at,
              remaining_meal_credits: s.remaining_meal_credits,
              price_paid_paise: s.price_paid_paise || 0,
              payment_mode: s.payment_mode || 'offline',
              created_at: s.created_at,
            });
          }
        }
      }
    }
  } catch {}

  const subsList = Array.from(subMap.values());

  return NextResponse.json({
    success: true,
    total: subsList.length,
    active_count: subsList.filter((s) => s.status === 'active').length,
    subscriptions: subsList,
  });
}
