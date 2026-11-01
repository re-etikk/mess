import { NextRequest, NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

const statuses = ['pending_payment', 'active', 'paused', 'expired', 'cancelled', 'refund_pending', 'refunded', 'payment_failed'] as const;

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const params = new URL(req.url).searchParams;
  const page = Math.min(100000, Math.max(1, Number(params.get('page')) || 1));
  const pageSize = Math.min(50, Math.max(1, Number(params.get('page_size')) || 20));
  const status = params.get('status') ?? '';
  const query = params.get('q')?.trim().slice(0, 80) ?? '';
  if (status && !statuses.includes(status as (typeof statuses)[number])) {
    return NextResponse.json({ success: false, error: 'Unsupported subscription status.' }, { status: 400 });
  }
  if (query && !/^[0-9a-f-]{36}$/i.test(query)) {
    return NextResponse.json({ success: false, error: 'Search by a subscription, customer, or provider ID.' }, { status: 400 });
  }

  let request = access.admin.from('subscriptions')
    .select('id,customer_id,provider_id,plan_id,status,plan_type_snapshot,plan_name_snapshot,price_paid_paise,initial_meal_credits,remaining_meal_credits,starts_at,expires_at,created_at', { count: 'exact' })
    .order('created_at', { ascending: false });
  if (status) request = request.eq('status', status);
  if (query) request = request.or(`id.eq.${query},customer_id.eq.${query},provider_id.eq.${query}`);
  const { data, error, count } = await request.range((page - 1) * pageSize, page * pageSize - 1);
  if (error) {
    console.error('Admin subscription list failed:', error.message);
    return NextResponse.json({ success: false, error: 'Subscriptions could not be loaded.' }, { status: 503 });
  }

  const rows = data ?? [];
  const customerIds = [...new Set(rows.map((row) => row.customer_id))];
  const providerIds = [...new Set(rows.map((row) => row.provider_id))];
  const [customers, providers] = await Promise.all([
    customerIds.length ? access.admin.from('profiles').select('id,display_name').in('id', customerIds) : Promise.resolve({ data: [], error: null }),
    providerIds.length ? access.admin.from('providers').select('id,display_name').in('id', providerIds) : Promise.resolve({ data: [], error: null }),
  ]);
  if (customers.error || providers.error) {
    console.error('Admin subscription labels failed:', customers.error?.message || providers.error?.message);
    return NextResponse.json({ success: false, error: 'Subscription labels could not be loaded.' }, { status: 503 });
  }
  const customerNames = new Map((customers.data ?? []).map((row: any) => [row.id, row.display_name]));
  const providerNames = new Map((providers.data ?? []).map((row: any) => [row.id, row.display_name]));
  const subscriptions = rows.map((row) => ({
    ...row,
    customer_name: customerNames.get(row.customer_id) ?? 'Profile unavailable',
    provider_name: providerNames.get(row.provider_id) ?? 'Provider unavailable',
  }));

  return NextResponse.json({
    success: true,
    total: count ?? 0,
    page,
    page_size: pageSize,
    subscriptions,
  }, { headers: { 'Cache-Control': 'private, no-store' } });
}
