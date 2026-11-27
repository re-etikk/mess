import { NextRequest, NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

function indiaDayBounds(now = new Date()) {
  const day = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Kolkata',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
  const start = new Date(`${day}T00:00:00+05:30`);
  return {
    day,
    start: start.toISOString(),
    end: new Date(start.getTime() + 24 * 60 * 60 * 1000).toISOString(),
  };
}

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req, 'overview.read');
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const db = access.admin;
  const { day, start, end } = indiaDayBounds();
  const [
    providers,
    activeProviders,
    pendingProviders,
    suspendedProviders,
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
    openTickets,
    urgentTickets,
    activePromos,
    activeAnnouncements,
    paidTxSample,
  ] = await Promise.all([
    db.from('providers').select('id', { count: 'exact', head: true }),
    db.from('providers').select('id', { count: 'exact', head: true }).eq('status', 'active'),
    db.from('providers').select('id', { count: 'exact', head: true }).eq('status', 'pending_review'),
    db.from('providers').select('id', { count: 'exact', head: true }).eq('status', 'suspended'),
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
    db.from('support_tickets').select('id', { count: 'exact', head: true }).in('status', ['open', 'triaged', 'in_progress']),
    db.from('support_tickets').select('id', { count: 'exact', head: true }).in('status', ['open', 'triaged', 'in_progress']).in('priority', ['high', 'urgent']),
    db.from('promo_codes').select('id', { count: 'exact', head: true }).eq('is_active', true),
    db.from('announcements').select('id', { count: 'exact', head: true }).eq('is_active', true).then((r) => r, () => ({ count: 0, error: null })),
    db.from('payment_transactions').select('amount_paise').eq('status', 'succeeded').limit(5000),
  ]);

  const coreResults = [
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
  ];
  const failed = coreResults.find((result) => result.error);
  if (failed?.error) {
    console.error('Admin overview query failed:', failed.error.message);
    return NextResponse.json({ success: false, error: 'Overview records could not be loaded.' }, { status: 503 });
  }

  const gmvPaise = ((paidTxSample.data as Array<{ amount_paise?: number }>) || []).reduce(
    (sum, tx) => sum + Number(tx.amount_paise || 0),
    0
  );

  const count = (result: { count: number | null }) => result.count ?? 0;
  return NextResponse.json(
    {
      success: true,
      admin_role: access.adminRole,
      as_of: new Date().toISOString(),
      timezone: 'Asia/Kolkata',
      day,
      providers: {
        total: count(providers),
        active: count(activeProviders),
        pending: count(pendingProviders),
        suspended: count(suspendedProviders),
      },
      customers: { total: count(customers) },
      subscriptions: {
        total: count(subscriptions),
        active: count(activeSubscriptions),
        expired: count(expiredSubscriptions),
      },
      orders: { total: count(bookings), open: count(pendingBookings) },
      redemptions: { total: count(redemptions), today: count(todayRedemptions) },
      payments: {
        total: count(payments),
        succeeded: count(succeededPayments),
        failed: count(failedPayments),
        pending: count(pendingPayments),
        verified_gmv_inr: Math.round(gmvPaise / 100),
      },
      refunds: { pending: count(pendingRefunds) },
      settlements: { pending: count(pendingSettlements) },
      support: { open: count(openTickets), urgent: count(urgentTickets) },
      offers: { active_promos: count(activePromos), active_announcements: count(activeAnnouncements) },
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}
