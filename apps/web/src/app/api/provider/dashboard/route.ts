import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { generateCounterQRToken, getIndiaDateString } from '@/lib/crypto';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id') || '';
  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  const db = getAdminClient();
  if (!db) return NextResponse.json({ success: false, error: 'Provider data service is not configured.' }, { status: 503 });

  const [{ data: provider, error: providerError }, { data: slots, error: slotsError }, subs, plans, scans] = await Promise.all([
    db.from('providers').select('id,display_name,status,timezone').eq('id', providerId).maybeSingle(),
    db.from('meal_slots').select('id,name,starts_at_local,ends_at_local').eq('provider_id', providerId).eq('active', true),
    db.from('subscriptions').select('id', { count: 'exact', head: true }).eq('provider_id', providerId).eq('status', 'active'),
    db.from('subscription_plans').select('id', { count: 'exact', head: true }).eq('provider_id', providerId).eq('active', true),
    db.from('meal_redemptions').select('id,redeemed_at,customer_id,subscription_id,confirmation_method,profiles(display_name),meal_bookings!inner(service_date,meal_slots(name))', { count: 'exact' }).eq('provider_id', providerId).order('redeemed_at', { ascending: false }).limit(15),
  ]);
  if (providerError || slotsError || subs.error || plans.error || scans.error) {
    const issue = providerError || slotsError || subs.error || plans.error || scans.error;
    console.error('Provider dashboard query failed:', issue?.message);
    return NextResponse.json({ success: false, error: 'Provider dashboard data could not be loaded.' }, { status: 503 });
  }
  if (!provider) return NextResponse.json({ success: false, error: 'Provider not found.' }, { status: 404 });

  const now = new Date();
  const localTime = new Intl.DateTimeFormat('en-GB', { timeZone: provider.timezone || 'Asia/Kolkata', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(now);
  const current = (slots ?? []).find((slot) => slot.starts_at_local <= localTime && slot.ends_at_local >= localTime);
  const today = getIndiaDateString(now);
  const todayStart = new Date(`${today}T00:00:00+05:30`).toISOString();
  const tomorrow = new Date(new Date(todayStart).getTime() + 24 * 60 * 60 * 1000).toISOString();
  const { count: todayCount, error: todayError } = await db.from('meal_redemptions')
    .select('id', { count: 'exact', head: true }).eq('provider_id', providerId).gte('redeemed_at', todayStart).lt('redeemed_at', tomorrow);
  if (todayError) return NextResponse.json({ success: false, error: 'Today’s attendance could not be loaded.' }, { status: 503 });

  const qrToken = provider.status === 'active' && current ? generateCounterQRToken({ providerId, date: today, slot: current.name }) : null;
  const recent = (scans.data ?? []).map((row: any) => ({
    id: row.id,
    user_id: row.customer_id,
    customer_name: Array.isArray(row.profiles) ? row.profiles[0]?.display_name || '' : row.profiles?.display_name || '',
    subscription_id: row.subscription_id,
    slot: row.meal_bookings?.meal_slots?.name || '',
    date: row.meal_bookings?.service_date,
    redeemed_at: row.redeemed_at,
    confirmation_method: row.confirmation_method,
  }));
  return NextResponse.json({
    success: true,
    provider: { id: provider.id, display_name: provider.display_name, status: provider.status },
    today_date: today,
    current_slot: current?.name || null,
    qr_token: qrToken,
    metrics: {
      today_scans_count: todayCount ?? 0,
      total_scans: scans.count ?? 0,
      active_subscribers: subs.count ?? 0,
      active_plans_count: plans.count ?? 0,
    },
    today_redemptions: recent.filter((item) => item.date === today),
  }, { headers: { 'Cache-Control': 'private, no-store' } });
}
