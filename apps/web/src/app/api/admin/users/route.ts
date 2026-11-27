import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';
import { hasAdminCapability, logAdminAudit } from '@/lib/admin-rbac';

export const dynamic = 'force-dynamic';

const CustomerActionSchema = z.object({
  user_id: z.string().uuid(),
  action: z.enum(['suspend', 'block', 'reactivate']),
  reason: z.string().trim().min(3).max(500),
});

function maskPhone(value: string | null) {
  if (!value) return null;
  const digits = value.replace(/\D/g, '');
  return digits.length < 4 ? '••••' : `••••••${digits.slice(-4)}`;
}

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req, 'customers.read');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const params = new URL(req.url).searchParams;
  const detailId = params.get('detail_id')?.trim() || '';

  if (detailId && /^[0-9a-f-]{36}$/i.test(detailId)) {
    const canUnmask = hasAdminCapability(access.adminRole, 'customers.unmask');
    const [profRes, subsRes, addrRes, ticketsRes] = await Promise.all([
      access.admin.from('profiles').select('*').eq('id', detailId).maybeSingle(),
      access.admin
        .from('subscriptions')
        .select('id,provider_id,plan_name_snapshot,status,price_paid_paise,starts_at,expires_at,created_at,providers(display_name)')
        .eq('customer_id', detailId)
        .order('created_at', { ascending: false })
        .limit(20),
      access.admin.from('customer_addresses').select('*').eq('customer_id', detailId).limit(10),
      access.admin
        .from('support_tickets')
        .select('id,category,subject,status,priority,created_at')
        .or(`created_by.eq.${detailId},about_user_id.eq.${detailId}`)
        .order('created_at', { ascending: false })
        .limit(10),
    ]);

    if (!profRes.data) {
      return NextResponse.json({ success: false, error: 'Customer not found.' }, { status: 404 });
    }

    if (canUnmask) {
      await logAdminAudit(access.admin, {
        actorUserId: access.userId,
        action: 'customer.detail_viewed',
        subjectType: 'profile',
        subjectId: detailId,
      });
    }

    return NextResponse.json(
      {
        success: true,
        customer: {
          id: profRes.data.id,
          name: profRes.data.display_name,
          email: canUnmask ? profRes.data.email : null,
          phone: canUnmask ? profRes.data.phone_e164 : maskPhone(profRes.data.phone_e164),
          account_status: profRes.data.account_status || 'active',
          suspension_reason: profRes.data.suspension_reason || null,
          locality: profRes.data.default_locality || '',
          city: profRes.data.default_city || '',
          food_preference: profRes.data.food_preference || 'veg',
          created_at: profRes.data.created_at,
        },
        subscriptions: subsRes.data ?? [],
        addresses: canUnmask ? addrRes.data ?? [] : [],
        tickets: ticketsRes.data ?? [],
      },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  }

  const page = Math.min(100000, Math.max(1, Number(params.get('page')) || 1));
  const pageSize = Math.min(50, Math.max(1, Number(params.get('page_size')) || 20));
  const query = params.get('q')?.trim().slice(0, 80) ?? '';
  const statusFilter = params.get('status')?.trim().toLowerCase() ?? '';
  const from = (page - 1) * pageSize;

  const buildQuery = (withStatus: boolean) => {
    const cols = withStatus
      ? 'id,display_name,phone_e164,email,default_city,account_status,suspension_reason,created_at,user_roles!user_roles_user_id_fkey!inner(role,revoked_at)'
      : 'id,display_name,phone_e164,email,default_city,created_at,user_roles!user_roles_user_id_fkey!inner(role,revoked_at)';

    let reqQ = access.admin
      .from('profiles')
      .select(cols, { count: 'exact' })
      .eq('user_roles.role', 'customer')
      .is('user_roles.revoked_at', null)
      .order('created_at', { ascending: false })
      .range(from, from + pageSize - 1);

    if (withStatus && statusFilter && ['active', 'suspended', 'blocked'].includes(statusFilter)) {
      reqQ = reqQ.eq('account_status', statusFilter);
    }

    if (query) {
      if (/^[0-9a-f-]{36}$/i.test(query)) {
        reqQ = reqQ.eq('id', query);
      } else {
        const clean = query.replace(/[%_,]/g, '');
        reqQ = reqQ.or(`display_name.ilike.%${clean}%,email.ilike.%${clean}%,phone_e164.ilike.%${clean}%`);
      }
    }
    return reqQ;
  };

  let res = await buildQuery(true);
  if (res.error?.code === '42703') {
    res = await buildQuery(false);
  }

  if (res.error) {
    console.error('Admin user directory query failed:', res.error.message);
    return NextResponse.json({ success: false, error: 'User directory could not be loaded.' }, { status: 503 });
  }

  const users = (res.data ?? []).map((profile: any) => ({
    id: profile.id,
    name: profile.display_name,
    phone_masked: maskPhone(profile.phone_e164),
    city: profile.default_city || null,
    account_status: profile.account_status || 'active',
    suspension_reason: profile.suspension_reason || null,
    role: 'customer',
    created_at: profile.created_at,
  }));

  return NextResponse.json(
    { success: true, total: res.count ?? 0, page, page_size: pageSize, users },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function PATCH(req: NextRequest) {
  const access = await requireAdmin(req, 'customers.moderate');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const body = await req.json().catch(() => ({}));
  const parsed = CustomerActionSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json(
      { success: false, error: 'Valid customer ID, action, and reason are required.' },
      { status: 400 }
    );
  }

  const { user_id, action, reason } = parsed.data;
  const nextStatus = action === 'reactivate' ? 'active' : action === 'block' ? 'blocked' : 'suspended';

  const { data, error } = await access.admin
    .from('profiles')
    .update({
      account_status: nextStatus,
      suspension_reason: action === 'reactivate' ? null : reason,
      suspended_at: action === 'reactivate' ? null : new Date().toISOString(),
      suspended_by: action === 'reactivate' ? null : access.userId,
    })
    .eq('id', user_id)
    .select('id,display_name,account_status')
    .maybeSingle();

  if (error) {
    console.error('Customer moderation update error:', error.message);
    return NextResponse.json({ success: false, error: 'Customer account status could not be updated.' }, { status: 503 });
  }
  if (!data) {
    return NextResponse.json({ success: false, error: 'Customer profile not found.' }, { status: 404 });
  }

  await logAdminAudit(access.admin, {
    actorUserId: access.userId,
    action: `customer.${action}`,
    subjectType: 'profile',
    subjectId: user_id,
    reason,
    details: { account_status: nextStatus },
  });

  await access.admin
    .from('customer_notifications')
    .insert({
      customer_id: user_id,
      title: action === 'reactivate' ? 'Account Reactivated' : 'Account Notice',
      message:
        action === 'reactivate'
          ? 'Your Thali customer account has been reactivated.'
          : `Your account was placed on hold. Reason: ${reason}`,
      notification_type: 'system',
      is_read: false,
    })
    .then(() => null, () => null);

  return NextResponse.json({ success: true, customer: data, message: `Customer status set to ${nextStatus}.` });
}
