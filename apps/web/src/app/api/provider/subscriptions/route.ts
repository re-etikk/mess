import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

function getClientSafe() {
  const db = getAdminClient();
  if (db) return db;
  try {
    return createClient();
  } catch {
    return null;
  }
}

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id');
  const access = await requireProviderOwnership(req, providerId || '');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const client = getClientSafe();
  if (!client) {
    return NextResponse.json({ success: true, total: 0, active_count: 0, subscriptions: [] });
  }

  try {
    const { data, error } = await client
      .from('subscriptions')
      .select('id,customer_id,plan_id,status,plan_type_snapshot,plan_name_snapshot,price_paid_paise,initial_meal_credits,remaining_meal_credits,starts_at,expires_at,created_at')
      .eq('provider_id', access.providerId)
      .order('created_at', { ascending: false })
      .limit(500);

    if (error) {
      console.error('Provider subscriber query error:', error.message);
      return NextResponse.json({ success: true, total: 0, active_count: 0, subscriptions: [] });
    }

    const subscriptions = (data ?? []).map((row: any) => ({
      id: row.id,
      customer_id: row.customer_id,
      customer_name: 'Subscriber',
      customer_phone: '',
      plan_id: row.plan_id,
      plan_name: row.plan_name_snapshot || 'Standard Plan',
      plan_type: row.plan_type_snapshot || 'fixed_period',
      status: row.status,
      starts_at: row.starts_at,
      expires_at: row.expires_at,
      remaining_meal_credits: row.remaining_meal_credits,
      initial_meal_credits: row.initial_meal_credits,
      price_paid_paise: Number(row.price_paid_paise || 0),
      created_at: row.created_at,
    }));

    return NextResponse.json({
      success: true,
      total: subscriptions.length,
      active_count: subscriptions.filter((item) => item.status === 'active').length,
      subscriptions,
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (err: any) {
    return NextResponse.json({ success: true, total: 0, active_count: 0, subscriptions: [] });
  }
}
