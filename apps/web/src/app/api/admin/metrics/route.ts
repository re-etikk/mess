import { NextRequest, NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const db = access.admin;
  const [providers, activeProviders, pendingProviders, subscriptions, activeSubscriptions, redemptions, payments, settlements] = await Promise.all([
    db.from('providers').select('id', { count: 'exact', head: true }),
    db.from('providers').select('id', { count: 'exact', head: true }).eq('status', 'active'),
    db.from('providers').select('id', { count: 'exact', head: true }).eq('status', 'pending_review'),
    db.from('subscriptions').select('id', { count: 'exact', head: true }),
    db.from('subscriptions').select('id', { count: 'exact', head: true }).eq('status', 'active'),
    db.from('meal_redemptions').select('id,redeemed_at', { count: 'exact' }),
    db.from('payment_transactions').select('amount_paise').eq('status', 'succeeded'),
    db.from('provider_settlements').select('net_payable_paise,status').eq('status', 'paid'),
  ]);

  const failed = [providers, activeProviders, pendingProviders, subscriptions, activeSubscriptions, redemptions, payments, settlements]
    .find((result) => result.error);
  if (failed?.error) {
    console.error('Admin metrics query failed:', failed.error.message);
    return NextResponse.json({ success: false, error: 'Metrics could not be loaded from the database.' }, { status: 503 });
  }

  const today = new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(new Date());
  const redemptionRows = redemptions.data ?? [];
  const paymentTotalPaise = (payments.data ?? []).reduce((sum, row) => sum + Number(row.amount_paise || 0), 0);
  const settlementTotalPaise = (settlements.data ?? []).reduce((sum, row) => sum + Number(row.net_payable_paise || 0), 0);

  return NextResponse.json({
    success: true,
    platform: 'Thali',
    providers: { total: providers.count ?? 0, active: activeProviders.count ?? 0, pending: pendingProviders.count ?? 0 },
    subscriptions: { total: subscriptions.count ?? 0, active: activeSubscriptions.count ?? 0 },
    redemptions: { total: redemptions.count ?? 0, today: redemptionRows.filter((row) => row.redeemed_at?.slice(0, 10) === today).length },
    financials: {
      verified_payments_inr: paymentTotalPaise / 100,
      paid_provider_settlements_inr: settlementTotalPaise / 100,
      currency: 'INR',
    },
  }, { headers: { 'Cache-Control': 'private, no-store' } });
}
