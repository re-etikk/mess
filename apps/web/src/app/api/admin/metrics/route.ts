import { NextRequest, NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

function indiaDayBounds(now = new Date()) {
  const day = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(now);
  const start = new Date(`${day}T00:00:00+05:30`);
  return { day, start: start.toISOString(), end: new Date(start.getTime() + 24 * 60 * 60 * 1000).toISOString() };
}

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const db = access.admin;
  const { day, start, end } = indiaDayBounds();
  const [
    providers,
    activeProviders,
    pendingProviders,
    customers,
    subscriptions,
    activeSubscriptions,
    expiredSubscriptions,
    bookings,
    pendingBookings,
    redemptions,
    todayRedemptions,
    payments,
    succeededPayments,
    failedPayments,
    pendingPayments,
    pendingRefunds,
    pendingSettlements,
  ] = await Promise.all([
    db.from('providers').select('id', { count: 'exact', head: true }),
    db.from('providers').select('id', { count: 'exact', head: true }).eq('status', 'active'),
    db.from('providers').select('id', { count: 'exact', head: true }).eq('status', 'pending_review'),
    db.from('user_roles').select('user_id', { count: 'exact', head: true }).eq('role', 'customer').is('revoked_at', null),
    db.from('subscriptions').select('id', { count: 'exact', head: true }),
    db.from('subscriptions').select('id', { count: 'exact', head: true }).eq('status', 'active'),
    db.from('subscriptions').select('id', { count: 'exact', head: true }).eq('status', 'expired'),
    db.from('meal_bookings').select('id', { count: 'exact', head: true }),
    db.from('meal_bookings').select('id', { count: 'exact', head: true }).in('status', ['draft', 'pending_payment', 'confirmed', 'ready']),
    db.from('meal_redemptions').select('id', { count: 'exact', head: true }),
    db.from('meal_redemptions').select('id', { count: 'exact', head: true }).gte('redeemed_at', start).lt('redeemed_at', end),
    db.from('payment_transactions').select('id', { count: 'exact', head: true }),
    db.from('payment_transactions').select('id', { count: 'exact', head: true }).eq('status', 'succeeded'),
    db.from('payment_transactions').select('id', { count: 'exact', head: true }).eq('status', 'failed'),
    db.from('payment_transactions').select('id', { count: 'exact', head: true }).in('status', ['created', 'pending']),
    db.from('refunds').select('id', { count: 'exact', head: true }).in('status', ['requested', 'pending']),
    db.from('provider_settlements').select('id', { count: 'exact', head: true }).in('status', ['draft', 'pending', 'processing']),
  ]);

  const results = [providers, activeProviders, pendingProviders, customers, subscriptions, activeSubscriptions,
    expiredSubscriptions, bookings, pendingBookings, redemptions, todayRedemptions, payments, succeededPayments,
    failedPayments, pendingPayments, pendingRefunds, pendingSettlements];
  const failed = results.find((result) => result.error);
  if (failed?.error) {
    console.error('Admin overview query failed:', failed.error.message);
    return NextResponse.json({ success: false, error: 'Overview records could not be loaded.' }, { status: 503 });
  }

  const count = (result: { count: number | null }) => result.count ?? 0;
  return NextResponse.json({
    success: true,
    as_of: new Date().toISOString(),
    timezone: 'Asia/Kolkata',
    day,
    providers: { total: count(providers), active: count(activeProviders), pending: count(pendingProviders) },
    customers: { total: count(customers) },
    subscriptions: { total: count(subscriptions), active: count(activeSubscriptions), expired: count(expiredSubscriptions) },
    orders: { total: count(bookings), open: count(pendingBookings) },
    redemptions: { total: count(redemptions), today: count(todayRedemptions) },
    payments: { total: count(payments), succeeded: count(succeededPayments), failed: count(failedPayments), pending: count(pendingPayments) },
    refunds: { pending: count(pendingRefunds) },
    settlements: { pending: count(pendingSettlements) },
    definitions: {
      customers: 'Profiles with a current, non-revoked customer role.',
      active_subscriptions: "subscriptions.status = 'active'.",
      open_orders: 'Bookings in draft, pending_payment, confirmed, or ready status.',
      today_redemptions: `Redemptions from ${day} 00:00 to next day 00:00 in Asia/Kolkata.`,
      pending_refunds: 'Refunds in requested or pending status.',
      pending_settlements: 'Provider settlements in draft, pending, or processing status.',
      payment_totals: 'Transaction counts grouped by the persisted payment_status enum; no amounts are summed in this overview.',
    },
  }, { headers: { 'Cache-Control': 'private, no-store' } });
}
