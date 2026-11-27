import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';
import { logAdminAudit } from '@/lib/admin-rbac';
import { addPartnerNotification } from '@/lib/partner-notifications';

export const dynamic = 'force-dynamic';

const PromoUpsertSchema = z.object({
  resource: z.literal('promo'),
  id: z.string().uuid().optional(),
  code: z.string().trim().min(3).max(32),
  title: z.string().trim().min(2).max(120),
  description: z.string().trim().max(300).optional(),
  provider_id: z.string().uuid().nullable().optional(),
  discount_type: z.enum(['flat', 'percent']).optional(),
  flat_discount_inr: z.number().min(0).max(5000).optional(),
  discount_percent: z.number().min(0).max(90).optional(),
  max_discount_inr: z.number().min(0).max(5000).nullable().optional(),
  min_order_inr: z.number().min(0).max(50000).optional().default(0),
  applicable_to_plans: z.boolean().optional().default(true),
  applicable_to_daily: z.boolean().optional().default(true),
  first_order_only: z.boolean().optional().default(false),
  show_in_app: z.boolean().optional().default(true),
  usage_limit: z.number().int().min(1).max(1000000).nullable().optional(),
  max_uses_per_user: z.number().int().min(1).max(100).nullable().optional(),
  valid_from: z.string().nullable().optional(),
  valid_until: z.string().nullable().optional(),
  is_active: z.boolean().optional().default(true),
});

const AnnouncementUpsertSchema = z.object({
  resource: z.literal('announcement'),
  id: z.string().uuid().optional(),
  title: z.string().trim().min(2).max(120),
  body: z.string().trim().min(2).max(500),
  badge_text: z.string().trim().max(30).optional().default('OFFER'),
  target_audience: z.enum(['all', 'customer', 'provider']).optional().default('all'),
  provider_id: z.string().uuid().nullable().optional(),
  promo_code: z.string().trim().max(32).nullable().optional(),
  action_url: z.string().trim().max(300).nullable().optional(),
  image_url: z.string().trim().max(500).nullable().optional(),
  is_featured: z.boolean().optional().default(false),
  priority: z.number().int().min(-100).max(1000).optional().default(10),
  expires_at: z.string().nullable().optional(),
  is_active: z.boolean().optional().default(true),
});

const BroadcastSchema = z.object({
  resource: z.literal('broadcast'),
  audience: z.enum(['all_customers', 'all_partners', 'single_customer', 'single_provider']),
  target_id: z.string().uuid().optional(),
  title: z.string().trim().min(2).max(120),
  message: z.string().trim().min(3).max(400),
  notification_type: z.enum(['offer', 'system', 'billing', 'menu_update']).optional().default('offer'),
});

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req, 'offers.manage');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const [promosRes, annRes, providersRes] = await Promise.all([
    access.admin.from('promo_codes').select('*').order('created_at', { ascending: false }).limit(100),
    access.admin
      .from('announcements')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(50)
      .then((r) => r, () => ({ data: [], error: null })),
    access.admin.from('providers').select('id,display_name,city').eq('status', 'active').order('display_name').limit(200),
  ]);

  return NextResponse.json(
    {
      success: true,
      promos: promosRes.data ?? [],
      announcements: annRes.data ?? [],
      providers: providersRes.data ?? [],
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  const access = await requireAdmin(req, 'offers.manage');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const body = await req.json().catch(() => ({}));

  const promoParsed = PromoUpsertSchema.safeParse(body);
  if (promoParsed.success) {
    const p = promoParsed.data;
    const cleanCode = p.code.toUpperCase().replace(/[^A-Z0-9_-]/g, '');
    if (cleanCode.length < 3) {
      return NextResponse.json({ success: false, error: 'Promo code must have at least 3 alphanumeric characters.' }, { status: 400 });
    }
    const isPercent = p.discount_type === 'percent' || (!p.flat_discount_inr && (p.discount_percent ?? 0) > 0);
    const payload: Record<string, any> = {
      code: cleanCode,
      title: p.title,
      description: p.description || null,
      provider_id: p.provider_id || null,
      flat_discount_paise: isPercent ? null : Math.round((p.flat_discount_inr || 0) * 100),
      discount_percent: isPercent ? Math.round(p.discount_percent || 0) : null,
      max_discount_paise: isPercent && p.max_discount_inr ? Math.round(p.max_discount_inr * 100) : null,
      min_order_paise: Math.round((p.min_order_inr || 0) * 100),
      applicable_to_plans: p.applicable_to_plans,
      applicable_to_daily: p.applicable_to_daily,
      first_order_only: p.first_order_only,
      show_in_app: p.show_in_app,
      usage_limit: p.usage_limit ?? null,
      max_uses_per_user: p.max_uses_per_user ?? null,
      valid_from: p.valid_from || new Date().toISOString(),
      valid_until: p.valid_until || null,
      is_active: p.is_active,
    };

    const query = p.id
      ? access.admin.from('promo_codes').update(payload).eq('id', p.id).select('*').single()
      : access.admin.from('promo_codes').insert({ ...payload, created_by: access.userId }).select('*').single();

    let { data, error } = await query;
    if (error?.code === '42703') {
      const { first_order_only: _a, max_uses_per_user: _b, show_in_app: _c, created_by: _d, ...base } = payload;
      const retry = p.id
        ? await access.admin.from('promo_codes').update(base).eq('id', p.id).select('*').single()
        : await access.admin.from('promo_codes').insert(base).select('*').single();
      data = retry.data;
      error = retry.error;
    }

    if (error) {
      return NextResponse.json({ success: false, error: error.message || 'Could not save promo code.' }, { status: 400 });
    }

    await logAdminAudit(access.admin, {
      actorUserId: access.userId,
      action: p.id ? 'offer.promo_updated' : 'offer.promo_created',
      subjectType: 'promo_code',
      subjectId: data?.id || null,
      details: { code: cleanCode, is_active: p.is_active },
    });

    return NextResponse.json({ success: true, promo: data, message: `Promo ${cleanCode} saved.` });
  }

  const annParsed = AnnouncementUpsertSchema.safeParse(body);
  if (annParsed.success) {
    const a = annParsed.data;
    const payload: Record<string, any> = {
      title: a.title,
      body: a.body,
      badge_text: a.badge_text || 'OFFER',
      target_audience: a.target_audience,
      provider_id: a.provider_id || null,
      promo_code: a.promo_code ? a.promo_code.toUpperCase() : null,
      action_url: a.action_url || null,
      image_url: a.image_url || null,
      is_featured: a.is_featured,
      priority: a.priority,
      expires_at: a.expires_at || null,
      is_active: a.is_active,
    };

    const query = a.id
      ? access.admin.from('announcements').update(payload).eq('id', a.id).select('*').single()
      : access.admin.from('announcements').insert({ ...payload, created_by: access.userId }).select('*').single();

    let { data, error } = await query;
    if (error?.code === '42703') {
      const { target_audience: _a, promo_code: _b, priority: _c, created_by: _d, ...base } = payload;
      const retry = a.id
        ? await access.admin.from('announcements').update(base).eq('id', a.id).select('*').single()
        : await access.admin.from('announcements').insert(base).select('*').single();
      data = retry.data;
      error = retry.error;
    }

    if (error) {
      return NextResponse.json({ success: false, error: error.message || 'Could not save banner/announcement.' }, { status: 400 });
    }

    await logAdminAudit(access.admin, {
      actorUserId: access.userId,
      action: a.id ? 'offer.announcement_updated' : 'offer.announcement_created',
      subjectType: 'announcement',
      subjectId: data?.id || null,
      details: { title: a.title },
    });

    return NextResponse.json({ success: true, announcement: data, message: 'Banner published cleanly.' });
  }

  const bcast = BroadcastSchema.safeParse(body);
  if (bcast.success) {
    const { audience, target_id, title, message, notification_type } = bcast.data;
    let sent = 0;

    if (audience === 'single_customer' && target_id) {
      const { error } = await access.admin.from('customer_notifications').insert({
        customer_id: target_id,
        title,
        message,
        notification_type,
        is_read: false,
      });
      if (!error) sent = 1;
    } else if (audience === 'all_customers') {
      const { data: custRoles } = await access.admin
        .from('user_roles')
        .select('user_id')
        .eq('role', 'customer')
        .is('revoked_at', null)
        .limit(500);
      const rows = (custRoles ?? []).map((r: any) => ({
        customer_id: r.user_id,
        title,
        message,
        notification_type,
        is_read: false,
      }));
      if (rows.length > 0) {
        const { error } = await access.admin.from('customer_notifications').insert(rows);
        if (!error) sent = rows.length;
      }
    } else if (audience === 'single_provider' && target_id) {
      addPartnerNotification({ provider_id: target_id, type: 'info', title, message, action_tab: 'overview' });
      sent = 1;
    } else if (audience === 'all_partners') {
      const { data: provs } = await access.admin.from('providers').select('id').eq('status', 'active').limit(500);
      for (const p of provs ?? []) {
        addPartnerNotification({ provider_id: String(p.id), type: 'info', title, message, action_tab: 'overview' });
        sent += 1;
      }
    }

    await logAdminAudit(access.admin, {
      actorUserId: access.userId,
      action: 'offer.broadcast_sent',
      subjectType: 'notification_broadcast',
      details: { audience, sent, title },
    });

    return NextResponse.json({ success: true, sent, message: `Sent notification to ${sent} recipient(s).` });
  }

  return NextResponse.json({ success: false, error: 'Unsupported offer or campaign payload.' }, { status: 400 });
}

export async function DELETE(req: NextRequest) {
  const access = await requireAdmin(req, 'offers.manage');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const { searchParams } = new URL(req.url);
  const resource = searchParams.get('resource');
  const id = searchParams.get('id')?.trim() || '';
  if (!id || !/^[0-9a-f-]{36}$/i.test(id)) {
    return NextResponse.json({ success: false, error: 'Valid item ID is required.' }, { status: 400 });
  }

  if (resource === 'promo') {
    await access.admin.from('promo_codes').delete().eq('id', id);
    await logAdminAudit(access.admin, { actorUserId: access.userId, action: 'offer.promo_deleted', subjectType: 'promo_code', subjectId: id });
    return NextResponse.json({ success: true, message: 'Promo removed.' });
  }
  if (resource === 'announcement') {
    await access.admin.from('announcements').delete().eq('id', id);
    await logAdminAudit(access.admin, { actorUserId: access.userId, action: 'offer.announcement_deleted', subjectType: 'announcement', subjectId: id });
    return NextResponse.json({ success: true, message: 'Announcement removed.' });
  }

  return NextResponse.json({ success: false, error: 'Unsupported resource type.' }, { status: 400 });
}
