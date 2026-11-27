import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';
import { logAdminAudit } from '@/lib/admin-rbac';

export const dynamic = 'force-dynamic';

const statuses = ['pending_payment', 'active', 'paused', 'expired', 'cancelled', 'refund_pending', 'refunded', 'payment_failed'] as const;

const SubscriptionActionSchema = z.object({
  subscription_id: z.string().uuid(),
  action: z.enum(['pause', 'resume', 'extend_days', 'adjust_credits', 'cancel']),
  reason: z.string().trim().min(3).max(500),
  extend_days: z.number().int().min(1).max(365).optional(),
  credits_delta: z.number().int().min(-100).max(200).optional(),
});

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req, 'subscriptions.read');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const params = new URL(req.url).searchParams;
  const page = Math.min(100000, Math.max(1, Number(params.get('page')) || 1));
  const pageSize = Math.min(50, Math.max(1, Number(params.get('page_size')) || 20));
  const status = params.get('status') ?? '';
  const query = params.get('q')?.trim().slice(0, 80) ?? '';
  if (status && !statuses.includes(status as (typeof statuses)[number])) {
    return NextResponse.json({ success: false, error: 'Unsupported subscription status.' }, { status: 400 });
  }

  let matchedCustomerIds: string[] = [];
  if (query && !/^[0-9a-f-]{36}$/i.test(query)) {
    const clean = query.replace(/[%_,]/g, '');
    const { data: profMatches } = await access.admin
      .from('profiles')
      .select('id')
      .ilike('display_name', `%${clean}%`)
      .limit(50);
    matchedCustomerIds = (profMatches ?? []).map((p: any) => String(p.id));
    if (matchedCustomerIds.length === 0) {
      return NextResponse.json(
        { success: true, total: 0, page, page_size: pageSize, subscriptions: [] },
        { headers: { 'Cache-Control': 'private, no-store' } }
      );
    }
  }

  let request = access.admin
    .from('subscriptions')
    .select(
      'id,customer_id,provider_id,plan_id,status,plan_type_snapshot,plan_name_snapshot,price_paid_paise,discount_paise,promo_code,payment_mode,initial_meal_credits,remaining_meal_credits,starts_at,expires_at,created_at',
      { count: 'exact' }
    )
    .order('created_at', { ascending: false });

  if (status) request = request.eq('status', status);
  if (/^[0-9a-f-]{36}$/i.test(query)) {
    request = request.or(`id.eq.${query},customer_id.eq.${query},provider_id.eq.${query}`);
  } else if (matchedCustomerIds.length > 0) {
    request = request.in('customer_id', matchedCustomerIds);
  }

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

  const customerNames = new Map((customers.data ?? []).map((row: any) => [row.id, row.display_name]));
  const providerNames = new Map((providers.data ?? []).map((row: any) => [row.id, row.display_name]));
  const subscriptions = rows.map((row) => ({
    ...row,
    customer_name: customerNames.get(row.customer_id) ?? 'Profile unavailable',
    provider_name: providerNames.get(row.provider_id) ?? 'Provider unavailable',
  }));

  return NextResponse.json(
    { success: true, total: count ?? 0, page, page_size: pageSize, subscriptions },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function PATCH(req: NextRequest) {
  const access = await requireAdmin(req, 'subscriptions.moderate');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const body = await req.json().catch(() => ({}));
  const parsed = SubscriptionActionSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { success: false, error: 'Valid subscription ID, action, and reason are required.' },
      { status: 400 }
    );
  }

  const { subscription_id, action, reason, extend_days, credits_delta } = parsed.data;
  const { data: sub, error: fetchErr } = await access.admin
    .from('subscriptions')
    .select('*')
    .eq('id', subscription_id)
    .maybeSingle();

  if (fetchErr || !sub) {
    return NextResponse.json({ success: false, error: 'Subscription not found.' }, { status: 404 });
  }

  const updates: Record<string, any> = { updated_at: new Date().toISOString() };
  let notifMessage = '';

  if (action === 'pause') {
    updates.status = 'paused';
    updates.pause_started_at = new Date().toISOString();
    notifMessage = `Your ${sub.plan_name_snapshot} pass was paused by Thali Support (${reason}).`;
  } else if (action === 'resume') {
    updates.status = 'active';
    notifMessage = `Your ${sub.plan_name_snapshot} pass has been resumed and is active.`;
  } else if (action === 'cancel') {
    updates.status = 'cancelled';
    updates.cancelled_at = new Date().toISOString();
    updates.cancellation_reason = reason;
    notifMessage = `Your ${sub.plan_name_snapshot} pass was cancelled (${reason}).`;
  } else if (action === 'extend_days') {
    const days = extend_days ?? 7;
    const baseExp = sub.expires_at ? Math.max(Date.now(), new Date(sub.expires_at).getTime()) : Date.now();
    updates.expires_at = new Date(baseExp + days * 86400000).toISOString();
    if (sub.status === 'expired') updates.status = 'active';
    notifMessage = `Good news! Your ${sub.plan_name_snapshot} validity was extended by ${days} days.`;
  } else if (action === 'adjust_credits') {
    const delta = credits_delta ?? 1;
    const nextRemaining = Math.max(0, Number(sub.remaining_meal_credits ?? 0) + delta);
    updates.remaining_meal_credits = nextRemaining;
    if (nextRemaining > 0 && sub.status === 'expired') updates.status = 'active';
    notifMessage = `Your meal credits were updated to ${nextRemaining} (${reason}).`;
  }

  const { data: updated, error: updErr } = await access.admin
    .from('subscriptions')
    .update(updates)
    .eq('id', subscription_id)
    .select('*')
    .single();

  if (updErr) {
    return NextResponse.json({ success: false, error: 'Could not update subscription.' }, { status: 503 });
  }

  await logAdminAudit(access.admin, {
    actorUserId: access.userId,
    action: `subscription.${action}`,
    subjectType: 'subscription',
    subjectId: subscription_id,
    reason,
    details: { extend_days, credits_delta },
  });

  if (sub.customer_id && notifMessage) {
    await access.admin
      .from('customer_notifications')
      .insert({
        customer_id: sub.customer_id,
        title: 'Subscription Updated',
        message: notifMessage,
        notification_type: 'subscription',
        is_read: false,
      })
      .then(() => null, () => null);
  }

  return NextResponse.json({ success: true, subscription: updated, message: 'Subscription updated.' });
}
