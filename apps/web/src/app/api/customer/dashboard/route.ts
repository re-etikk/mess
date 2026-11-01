import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(_req: NextRequest) {
  try {
    const session = await createClient();
    const { data: { user }, error: authError } = await session.auth.getUser();
    if (authError || !user) return NextResponse.json({ success: false, error: 'Authentication required.' }, { status: 401 });

    const db = getAdminClient();
    if (!db) return NextResponse.json({ success: false, error: 'Customer data service is not configured.' }, { status: 503 });
    const [subscriptions, redemptions] = await Promise.all([
      db.from('subscriptions')
        .select('id,status,plan_type_snapshot,plan_name_snapshot,initial_meal_credits,remaining_meal_credits,starts_at,expires_at,created_at,providers(id,display_name,slug,locality,city)')
        .eq('customer_id', user.id).order('created_at', { ascending: false }).limit(30),
      db.from('meal_redemptions')
        .select('id,redeemed_at,provider_id,providers(display_name),meal_bookings(service_date,meal_slots(name))')
        .eq('customer_id', user.id).order('redeemed_at', { ascending: false }).limit(30),
    ]);
    if (subscriptions.error || redemptions.error) {
      console.error('Customer dashboard API query failed:', subscriptions.error?.message || redemptions.error?.message);
      return NextResponse.json({ success: false, error: 'Customer records could not be loaded.' }, { status: 503 });
    }
    return NextResponse.json({ success: true, subscriptions: subscriptions.data ?? [], recent_redemptions: redemptions.data ?? [] }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Customer dashboard API unavailable:', error instanceof Error ? error.message : 'unknown error');
    return NextResponse.json({ success: false, error: 'Customer dashboard is temporarily unavailable.' }, { status: 503 });
  }
}
