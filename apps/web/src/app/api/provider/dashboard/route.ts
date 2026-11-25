import { NextRequest, NextResponse } from 'next/server';
import { createClient as createSupabaseClient } from '@supabase/supabase-js';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { generateCounterQRToken, getIndiaDateString } from '@/lib/crypto';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://mrbtwsrknqofjkrbssww.supabase.co';
const SUPABASE_ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yYnR3c3JrbnFvZmprcmJzc3d3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5MzEzNDcsImV4cCI6MjEwODUwNzM0N30.TzKjZ593n_ku_81ZCAuzOkeHl-7pGmQjylzIP3cHssc';

function getClientSafe() {
  const db = getAdminClient();
  if (db) return db;
  try {
    const sClient = createClient();
    if (sClient) return sClient;
  } catch {}
  return createSupabaseClient(SUPABASE_URL, SUPABASE_ANON, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id') || '';
  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const client = getClientSafe();
  if (!client) return NextResponse.json({ success: false, error: 'Provider data service is not configured.' }, { status: 503 });

  try {
    const now = new Date();
    const today = getIndiaDateString(now);
    const todayStart = new Date(`${today}T00:00:00+05:30`).toISOString();
    const tomorrow = new Date(new Date(todayStart).getTime() + 24 * 60 * 60 * 1000).toISOString();

    const [{ data: provider }, { data: dbSlots }, subs, pendingSubs, plans, scans, revRes] = await Promise.all([
      client.from('providers').select('id,display_name,status,timezone,locality,city').eq('id', providerId).maybeSingle(),
      client.from('meal_slots').select('id,name,starts_at_local,ends_at_local,active').eq('provider_id', providerId).eq('active', true),
      client.from('subscriptions').select('id,price_paid_paise,payment_mode', { count: 'exact' }).eq('provider_id', providerId).eq('status', 'active'),
      client.from('subscriptions').select('id,price_paid_paise').eq('provider_id', providerId).eq('status', 'pending_payment'),
      client.from('subscription_plans').select('id', { count: 'exact', head: true }).eq('provider_id', providerId).eq('active', true),
      client
        .from('meal_redemptions')
        .select('id,redeemed_at,customer_id,subscription_id,confirmation_method,profiles:customer_id(display_name)', { count: 'exact' })
        .eq('provider_id', providerId)
        .order('redeemed_at', { ascending: false })
        .limit(15),
      client
        .from('mess_reviews')
        .select('rating')
        .eq('provider_id', providerId)
        .then((r) => r, () => ({ data: [] as any[] })),
    ]);

    const slots = dbSlots ?? [];
    const localTime = new Intl.DateTimeFormat('en-GB', {
      timeZone: provider?.timezone || 'Asia/Kolkata',
      hour: '2-digit',
      minute: '2-digit',
      hourCycle: 'h23',
    }).format(now);

    const current = slots.find((slot) => slot.starts_at_local <= localTime && slot.ends_at_local >= localTime) || slots[0];

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

    const recent = (scans?.data ?? []).map((row: any) => {
      const prof = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
      return {
        id: row.id,
        user_id: row.customer_id,
        customer_name: prof?.display_name || 'Subscriber',
        subscription_id: row.subscription_id,
        slot: current?.name || 'LUNCH',
        date: today,
        redeemed_at: row.redeemed_at,
        confirmation_method: row.confirmation_method || 'qr_scan',
      };
    });

    const pendingCashList = pendingSubs.data ?? [];
    const pendingCashInr = Math.round(
      pendingCashList.reduce((acc: number, s: any) => acc + Number(s.price_paid_paise || 0), 0) / 100
    );

    const activeSubsList = subs.data ?? [];
    const onlineSettledInr = Math.round(
      activeSubsList
        .filter((s: any) => s.payment_mode !== 'counter_cash')
        .reduce((acc: number, s: any) => acc + Number(s.price_paid_paise || 0), 0) / 100
    );

    const reviews = (revRes as any)?.data ?? [];
    const avgRating =
      reviews.length > 0
        ? Math.round((reviews.reduce((a: number, r: any) => a + Number(r.rating || 0), 0) / reviews.length) * 10) / 10
        : null;

    const manualOpen = platformStore.providerStatuses.get(providerId);

    return NextResponse.json(
      {
        success: true,
        provider: {
          id: provider?.id || providerId,
          display_name: provider?.display_name || 'Mess Partner',
          locality: provider?.locality || '',
          city: provider?.city || '',
          status: provider?.status || 'active',
        },
        is_open_today: manualOpen !== undefined ? manualOpen : provider?.status === 'active',
        today_date: today,
        current_slot: current?.name || 'LUNCH',
        qr_token: qrToken,
        metrics: {
          today_scans_count: todayCount,
          total_scans: scans?.count ?? 0,
          unbilled_scans: todayCount,
          active_subscribers: subs?.count ?? 0,
          active_plans_count: plans?.count ?? 0,
          pending_cash_count: pendingCashList.length,
          pending_cash_inr: pendingCashInr,
          online_settled_inr: onlineSettledInr,
          average_rating: avgRating,
          reviews_count: reviews.length,
        },
        today_redemptions: recent,
      },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  } catch (error: any) {
    console.error('Provider dashboard query failed:', error?.message);
    return NextResponse.json({ success: false, error: 'Failed to load partner dashboard metrics.' }, { status: 500 });
  }
}
