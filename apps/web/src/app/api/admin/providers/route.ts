import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';
import { logAdminAudit } from '@/lib/admin-rbac';
import { addPartnerNotification } from '@/lib/partner-notifications';
import { sendEmailNotification } from '@/lib/notifications';
import { escapeHtml } from '@/lib/auth-session';

export const dynamic = 'force-dynamic';

const ReviewSchema = z.object({
  provider_id: z.string().uuid(),
  decision: z.enum(['approve', 'reject']),
  reason: z.string().trim().min(3).max(500),
});

const ModerationSchema = z.object({
  provider_id: z.string().uuid(),
  action: z.enum(['suspend', 'reactivate', 'update_controls']),
  reason: z.string().trim().max(500).optional(),
  is_featured: z.boolean().optional(),
  featured_rank: z.number().int().min(1).max(999).optional(),
  is_verified_badge: z.boolean().optional(),
  commission_bps_override: z.number().int().min(0).max(5000).nullable().optional(),
  is_accepting_orders: z.boolean().optional(),
});

const FULL_COLS =
  'id,owner_user_id,display_name,public_phone,public_email,description,address_line1,locality,city,state,pincode,supports_pickup,supports_delivery,is_accepting_orders,is_featured,featured_rank,is_verified_badge,commission_bps_override,suspension_reason,approved_at,created_at,status';
const BASE_COLS =
  'id,owner_user_id,display_name,public_phone,public_email,description,address_line1,locality,city,state,pincode,supports_pickup,supports_delivery,approved_at,created_at,status';

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req, 'partners.read');
  if (!auth.ok) return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });

  const params = new URL(req.url).searchParams;
  const includeAll = params.get('all') === 'true';
  const statusFilter = params.get('status')?.trim() || '';
  const cityFilter = params.get('city')?.trim().replace(/[%_,]/g, '').slice(0, 60) ?? '';
  const page = Math.min(100000, Math.max(1, Number(params.get('page')) || 1));
  const pageSize = Math.min(50, Math.max(1, Number(params.get('page_size')) || 20));
  const search = params.get('q')?.trim().replace(/[%_,]/g, '').slice(0, 80) ?? '';
  const from = (page - 1) * pageSize;

  const queryProviders = async (statusEq?: string, excludePending?: boolean) => {
    const build = (cols: string) => {
      let q = auth.admin.from('providers').select(cols, { count: 'exact' });
      if (statusEq) q = q.eq('status', statusEq);
      if (excludePending) q = q.neq('status', 'pending_review');
      if (search) q = q.or(`display_name.ilike.%${search}%,locality.ilike.%${search}%,city.ilike.%${search}%`);
      if (cityFilter) q = q.ilike('city', `%${cityFilter}%`);
      return q.order('created_at', { ascending: false }).range(from, from + pageSize - 1);
    };
    const primary = await build(FULL_COLS);
    if (primary.error?.code === '42703') {
      return await build(BASE_COLS);
    }
    return primary;
  };

  const [pending, directory] = await Promise.all([
    queryProviders('pending_review'),
    statusFilter && statusFilter !== 'all'
      ? queryProviders(statusFilter)
      : includeAll
        ? queryProviders(undefined, true)
        : queryProviders('active'),
  ]);

  if (pending.error || directory.error) {
    console.error('Admin providers query failed:', pending.error?.message || directory.error?.message);
    return NextResponse.json({ success: false, error: 'Provider records could not be loaded.' }, { status: 503 });
  }

  return NextResponse.json(
    {
      success: true,
      applications: pending.data ?? [],
      applications_total: pending.count ?? 0,
      active_providers: directory.data ?? [],
      active_total: directory.count ?? 0,
      page,
      page_size: pageSize,
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function PATCH(req: NextRequest) {
  const auth = await requireAdmin(req, 'partners.moderate');
  if (!auth.ok) return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });

  if (process.env.VERCEL_ENV === 'preview') {
    return NextResponse.json(
      { success: false, error: 'Provider decisions are disabled in preview deployments.' },
      { status: 403 }
    );
  }

  let payload: unknown;
  try {
    payload = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }

  const reviewParsed = ReviewSchema.safeParse(payload);
  if (reviewParsed.success) {
    const { provider_id, decision, reason } = reviewParsed.data;
    const approved = decision === 'approve';
    const { data: provider, error } = await auth.admin
      .from('providers')
      .update({
        status: approved ? 'active' : 'rejected',
        approved_at: approved ? new Date().toISOString() : null,
        approved_by: approved ? auth.userId : null,
      })
      .eq('id', provider_id)
      .eq('status', 'pending_review')
      .select('id,display_name,public_email,status,approved_at')
      .maybeSingle();

    if (error) {
      return NextResponse.json({ success: false, error: 'Provider decision could not be saved.' }, { status: 503 });
    }
    if (!provider) {
      return NextResponse.json({ success: false, error: 'No pending application was found for this provider.' }, { status: 404 });
    }

    await logAdminAudit(auth.admin, {
      actorUserId: auth.userId,
      action: approved ? 'provider.approved' : 'provider.rejected',
      subjectType: 'provider',
      subjectId: provider.id,
      reason,
    });

    addPartnerNotification({
      provider_id: provider.id,
      type: 'info',
      title: approved ? 'Kitchen Approved!' : 'Kitchen Application Update',
      message: approved
        ? `Congratulations! ${provider.display_name} is now live on Thali.`
        : `Application status update: ${reason}`,
      action_tab: 'overview',
    });

    if (provider.public_email && String(provider.public_email).includes('@')) {
      void sendEmailNotification({
        to: String(provider.public_email),
        subject: approved
          ? `Your Kitchen ${provider.display_name} Is Now Live on Thali!`
          : `Kitchen Application Update - ${provider.display_name}`,
        html: `<p>Hello,</p><p>${escapeHtml(
          approved
            ? `Your kitchen ${provider.display_name} has been verified and activated by Thali Operations.`
            : `Your kitchen application was not approved at this time. Reason: ${reason}`
        )}</p>`,
      }).catch(() => null);
    }

    return NextResponse.json({ success: true, provider, decision, reason, message: `Provider ${decision}d.` });
  }

  const modParsed = ModerationSchema.safeParse(payload);
  if (!modParsed.success) {
    return NextResponse.json(
      { success: false, error: 'Invalid provider action payload.', details: modParsed.error.flatten() },
      { status: 400 }
    );
  }

  const { provider_id, action, reason, ...controls } = modParsed.data;
  if ((action === 'suspend' || action === 'reactivate') && (!reason || reason.trim().length < 3)) {
    return NextResponse.json({ success: false, error: 'A reason of at least 3 characters is required.' }, { status: 400 });
  }

  const updateFields: Record<string, any> = {};
  let auditAction = 'provider.controls_updated';

  if (action === 'suspend') {
    updateFields.status = 'suspended';
    updateFields.is_accepting_orders = false;
    updateFields.suspension_reason = reason?.trim() || null;
    auditAction = 'provider.suspended';
  } else if (action === 'reactivate') {
    updateFields.status = 'active';
    updateFields.suspension_reason = null;
    updateFields.approved_at = new Date().toISOString();
    updateFields.approved_by = auth.userId;
    auditAction = 'provider.reactivated';
  } else {
    if (controls.is_featured !== undefined) updateFields.is_featured = controls.is_featured;
    if (controls.featured_rank !== undefined) updateFields.featured_rank = controls.featured_rank;
    if (controls.is_verified_badge !== undefined) updateFields.is_verified_badge = controls.is_verified_badge;
    if (controls.commission_bps_override !== undefined) updateFields.commission_bps_override = controls.commission_bps_override;
    if (controls.is_accepting_orders !== undefined) updateFields.is_accepting_orders = controls.is_accepting_orders;
  }

  const { data: updated, error: updErr } = await auth.admin
    .from('providers')
    .update(updateFields)
    .eq('id', provider_id)
    .select('id,display_name,status,is_accepting_orders')
    .maybeSingle();

  if (updErr) {
    console.error('Provider moderation update error:', updErr.message);
    return NextResponse.json({ success: false, error: 'Kitchen controls could not be updated.' }, { status: 503 });
  }
  if (!updated) {
    return NextResponse.json({ success: false, error: 'Kitchen not found.' }, { status: 404 });
  }

  await logAdminAudit(auth.admin, {
    actorUserId: auth.userId,
    action: auditAction,
    subjectType: 'provider',
    subjectId: provider_id,
    reason: reason || null,
    details: updateFields,
  });

  if (action === 'suspend' || action === 'reactivate') {
    addPartnerNotification({
      provider_id,
      type: 'info',
      title: action === 'suspend' ? 'Kitchen Suspended' : 'Kitchen Reactivated',
      message: reason || 'Status updated by Thali Operations.',
      action_tab: 'overview',
    });
  }

  return NextResponse.json({ success: true, provider: updated, message: 'Kitchen controls updated.' });
}
