import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || '';
  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  const db = getAdminClient();
  if (!db) return NextResponse.json({ success: false, error: 'Redemption data service is not configured.' }, { status: 503 });

  let query = db.from('meal_redemptions')
    .select('id,booking_id,subscription_id,customer_id,provider_id,redeemed_by,confirmation_method,redeemed_at,profiles(display_name,phone_e164),meal_bookings!inner(service_date,meal_slots(name))')
    .eq('provider_id', providerId).order('redeemed_at', { ascending: false }).limit(500);
  const date = params.get('date');
  if (date && /^\d{4}-\d{2}-\d{2}$/.test(date)) query = query.eq('meal_bookings.service_date', date);
  const { data, error } = await query;
  if (error) {
    console.error('Provider redemption query failed:', error.message);
    return NextResponse.json({ success: false, error: 'Redemption records could not be loaded.' }, { status: 503 });
  }
  const redemptions = (data ?? []).map((row: any) => ({
    id: row.id,
    user_id: row.customer_id,
    customer_name: row.profiles?.display_name || '',
    customer_phone: row.profiles?.phone_e164 || '',
    provider_id: row.provider_id,
    subscription_id: row.subscription_id,
    date: row.meal_bookings.service_date,
    slot: row.meal_bookings.meal_slots?.name || '',
    confirmation_method: row.confirmation_method,
    redeemed_at: row.redeemed_at,
  }));
  return NextResponse.json({ success: true, total: redemptions.length, redemptions }, { headers: { 'Cache-Control': 'private, no-store' } });
}
