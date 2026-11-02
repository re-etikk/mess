import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { generateCounterQRToken, getIndiaDateString } from '@/lib/crypto';

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
  const providerId = new URL(req.url).searchParams.get('provider_id') || '';
  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const client = getClientSafe();
  if (!client) return NextResponse.json({ success: false, error: 'Provider data service is not configured.' }, { status: 503 });

  try {
    const [{ data: provider }, { data: dbSlots }, subs, plans, scans] = await Promise.all([
      client.from('providers').select('id,display_name,status,timezone').eq('id', providerId).maybeSingle(),
      client.from('meal_slots').select('id,name,starts_at_local,ends_at_local,active').eq('provider_id', providerId).eq('active', true),
      client.from('subscriptions').select('id', { count: 'exact', head: true }).eq('provider_id', providerId).eq('status', 'active'),
      client.from('subscription_plans').select('id', { count: 'exact', head: true }).eq('provider_id', providerId).eq('active', true),
      client.from('meal_redemptions').select('id,redeemed_at,customer_id,subscription_id,confirmation_method', { count: 'exact' }).eq('provider_id', providerId).order('redeemed_at', { ascending: false }).limit(15),
    ]);

    const slots = dbSlots ?? [
      { id: 'lunch-default', name: 'LUNCH', starts_at_local: '12:00:00', ends_at_local: '15:30:00', active: true },
    ];

    const now = new Date();
    const localTime = new Intl.DateTimeFormat('en-GB', {
      timeZone: provider?.timezone || 'Asia/Kolkata',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).format(now);

    const current = slots.find((slot) => slot.starts_at_local <= localTime && slot.ends_at_local >= localTime) || slots[0];
    const today = getIndiaDateString(now);

    const todayStart = new Date(`${today}T00:00:00+05:30`).toISOString();
    const tomorrow = new Date(new Date(todayStart).getTime() + 24 * 60 * 60 * 1000).toISOString();

    let todayCount = 0;
    try {
      const res = await client
        .from('meal_redemptions')
        .select('id', { count: 'exact', head: true })
        .eq('provider_id', providerId)
        .gte('redeemed_at', todayStart)
        .lt('redeemed_at', tomorrow);
      todayCount = res.count ?? 0;
    } catch {}

    const qrToken = generateCounterQRToken({ providerId, date: today, slot: current?.name || 'LUNCH' });

    const recent = (scans?.data ?? []).map((row: any) => ({
      id: row.id,
      user_id: row.customer_id,
      customer_name: 'Student Member',
      subscription_id: row.subscription_id,
      slot: current?.name || 'LUNCH',
      date: today,
      redeemed_at: row.redeemed_at,
      confirmation_method: row.confirmation_method || 'qr_scan',
    }));

    return NextResponse.json({
      success: true,
      provider: {
        id: provider?.id || providerId,
        display_name: provider?.display_name || 'My Mess',
        status: provider?.status || 'active',
      },
      today_date: today,
      current_slot: current?.name || 'LUNCH',
      qr_token: qrToken,
      metrics: {
        today_scans_count: todayCount,
        total_scans: scans?.count ?? 0,
        unbilled_scans: todayCount,
        active_subscribers: subs?.count ?? 0,
        active_plans_count: plans?.count ?? 0,
      },
      today_redemptions: recent,
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error: any) {
    console.error('Provider dashboard query failed:', error?.message);
    const today = getIndiaDateString();
    return NextResponse.json({
      success: true,
      provider: { id: providerId, display_name: 'My Mess', status: 'active' },
      today_date: today,
      current_slot: 'LUNCH',
      qr_token: generateCounterQRToken({ providerId, date: today, slot: 'LUNCH' }),
      metrics: {
        today_scans_count: 0,
        total_scans: 0,
        unbilled_scans: 0,
        active_subscribers: 0,
        active_plans_count: 0,
      },
      today_redemptions: [],
    });
  }
}
