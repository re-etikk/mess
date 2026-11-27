import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import crypto from 'crypto';
import { requireAdmin } from '@/lib/supabase/admin';
import { logAdminAudit } from '@/lib/admin-rbac';
import { addPartnerNotification } from '@/lib/partner-notifications';
import { sendEmailNotification } from '@/lib/notifications';
import { escapeHtml } from '@/lib/auth-session';

export const dynamic = 'force-dynamic';

const ReplySchema = z.object({
  ticket_id: z.string().uuid(),
  action: z.literal('reply'),
  message: z.string().trim().min(2).max(3000),
  is_internal: z.boolean().optional().default(false),
  next_status: z.enum(['open', 'triaged', 'in_progress', 'waiting_for_user', 'resolved', 'closed']).optional(),
});

const MetaSchema = z.object({
  ticket_id: z.string().uuid(),
  action: z.literal('update_meta'),
  status: z.enum(['open', 'triaged', 'in_progress', 'waiting_for_user', 'resolved', 'closed']).optional(),
  priority: z.enum(['low', 'normal', 'high', 'urgent']).optional(),
  resolution_note: z.string().trim().max(1500).optional(),
});

const CompensationResolveSchema = z.object({
  ticket_id: z.string().uuid(),
  action: z.literal('resolve_with_compensation'),
  resolution_note: z.string().trim().min(3).max(1500),
  compensation_type: z.enum(['apology_coupon', 'extend_subscription', 'refund_request', 'none']),
  coupon_amount_inr: z.number().int().min(10).max(2000).optional(),
  extend_days: z.number().int().min(1).max(90).optional(),
  subscription_id: z.string().uuid().optional(),
});

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req, 'support.read');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const params = new URL(req.url).searchParams;
  const ticketId = params.get('ticket_id')?.trim() || '';

  if (ticketId && /^[0-9a-f-]{36}$/i.test(ticketId)) {
    const { data: ticket, error } = await access.admin
      .from('support_tickets')
      .select('*')
      .eq('id', ticketId)
      .maybeSingle();

    if (error || !ticket) {
      return NextResponse.json({ success: false, error: 'Support ticket not found.' }, { status: 404 });
    }

    const [msgsRes, userRes, provRes, subsRes] = await Promise.all([
      access.admin
        .from('support_ticket_messages')
        .select('*')
        .eq('ticket_id', ticketId)
        .order('created_at', { ascending: true }),
      ticket.created_by
        ? access.admin.from('profiles').select('id,display_name,email,phone_e164,account_status').eq('id', ticket.created_by).maybeSingle()
        : Promise.resolve({ data: null }),
      ticket.provider_id
        ? access.admin.from('providers').select('id,display_name,public_phone,status').eq('id', ticket.provider_id).maybeSingle()
        : Promise.resolve({ data: null }),
      ticket.created_by
        ? access.admin
            .from('subscriptions')
            .select('id,plan_name_snapshot,status,price_paid_paise,expires_at')
            .eq('customer_id', ticket.created_by)
            .order('created_at', { ascending: false })
            .limit(5)
        : Promise.resolve({ data: [] }),
    ]);

    return NextResponse.json(
      {
        success: true,
        ticket,
        messages: msgsRes.data ?? [],
        requester_profile: userRes.data ?? null,
        provider_info: provRes.data ?? null,
        related_subscriptions: subsRes.data ?? [],
      },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  }

  const page = Math.min(100000, Math.max(1, Number(params.get('page')) || 1));
  const pageSize = Math.min(50, Math.max(1, Number(params.get('page_size')) || 25));
  const status = params.get('status')?.trim() || '';
  const priority = params.get('priority')?.trim() || '';
  const role = params.get('role')?.trim() || '';
  const q = params.get('q')?.trim().replace(/[%_,]/g, '').slice(0, 80) || '';
  const from = (page - 1) * pageSize;

  let query = access.admin
    .from('support_tickets')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false });

  if (status) query = query.eq('status', status);
  if (priority) query = query.eq('priority', priority);
  if (role === 'customer' || role === 'provider') query = query.eq('requester_role', role);
  if (q) {
    query = /^[0-9a-f-]{36}$/i.test(q)
      ? query.eq('id', q)
      : query.or(`subject.ilike.%${q}%,requester_name.ilike.%${q}%,requester_email.ilike.%${q}%,category.ilike.%${q}%`);
  }

  const { data, error, count } = await query.range(from, from + pageSize - 1);
  if (error) {
    console.error('Support queue load failed:', error.message);
    return NextResponse.json({ success: false, error: 'Support tickets could not be loaded.' }, { status: 503 });
  }

  return NextResponse.json(
    {
      success: true,
      total: count ?? 0,
      page,
      page_size: pageSize,
      tickets: data ?? [],
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function PATCH(req: NextRequest) {
  const access = await requireAdmin(req, 'support.resolve');
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const body = await req.json().catch(() => ({}));

  const reply = ReplySchema.safeParse(body);
  if (reply.success) {
    const { ticket_id, message, is_internal, next_status } = reply.data;
    const { data: ticket } = await access.admin.from('support_tickets').select('*').eq('id', ticket_id).maybeSingle();
    if (!ticket) return NextResponse.json({ success: false, error: 'Ticket not found.' }, { status: 404 });

    const { error: msgErr } = await access.admin.from('support_ticket_messages').insert({
      ticket_id,
      sender_role: 'admin',
      sender_id: access.userId,
      sender_name: 'Thali Support Team',
      message,
      is_internal,
    });
    if (msgErr) return NextResponse.json({ success: false, error: 'Could not save support reply.' }, { status: 503 });

    const resolvedStatus = next_status || (is_internal ? ticket.status : 'waiting_for_user');
    await access.admin
      .from('support_tickets')
      .update({
        status: resolvedStatus,
        assigned_to: access.userId,
        resolved_at: resolvedStatus === 'resolved' || resolvedStatus === 'closed' ? new Date().toISOString() : ticket.resolved_at,
        updated_at: new Date().toISOString(),
      })
      .eq('id', ticket_id);

    await logAdminAudit(access.admin, {
      actorUserId: access.userId,
      action: is_internal ? 'support.internal_note' : 'support.replied',
      subjectType: 'support_ticket',
      subjectId: ticket_id,
      details: { next_status: resolvedStatus },
    });

    if (!is_internal) {
      if (ticket.created_by && ticket.requester_role !== 'provider') {
        await access.admin
          .from('customer_notifications')
          .insert({
            customer_id: ticket.created_by,
            title: `Support Reply: ${ticket.subject}`,
            message: message.slice(0, 180),
            notification_type: 'support',
            is_read: false,
          })
          .then(() => null, () => null);
      } else if (ticket.provider_id) {
        addPartnerNotification({
          provider_id: ticket.provider_id,
          type: 'support',
          title: `Support Reply: ${ticket.subject}`,
          message: message.slice(0, 180),
          action_tab: 'support',
        });
      }

      if (ticket.requester_email && String(ticket.requester_email).includes('@')) {
        void sendEmailNotification({
          to: String(ticket.requester_email),
          subject: `Re: [Thali Support] ${ticket.subject}`,
          html: `<p>Hi ${escapeHtml(ticket.requester_name || 'there')},</p><p>${escapeHtml(message)}</p><p style="color:#666;font-size:12px;">You can also view this update inside your Thali Support screen.</p>`,
        }).catch(() => null);
      }
    }

    return NextResponse.json({ success: true, message: is_internal ? 'Internal note saved.' : 'Reply sent to requester.' });
  }

  const meta = MetaSchema.safeParse(body);
  if (meta.success) {
    const { ticket_id, status, priority, resolution_note } = meta.data;
    const updates: Record<string, any> = { assigned_to: access.userId, updated_at: new Date().toISOString() };
    if (status) {
      updates.status = status;
      if (status === 'resolved' || status === 'closed') updates.resolved_at = new Date().toISOString();
    }
    if (priority) updates.priority = priority;
    if (resolution_note !== undefined) updates.resolution_note = resolution_note;

    const { data: updated, error } = await access.admin
      .from('support_tickets')
      .update(updates)
      .eq('id', ticket_id)
      .select('*')
      .maybeSingle();

    if (error || !updated) {
      return NextResponse.json({ success: false, error: 'Ticket update failed.' }, { status: 503 });
    }

    await logAdminAudit(access.admin, {
      actorUserId: access.userId,
      action: 'support.meta_updated',
      subjectType: 'support_ticket',
      subjectId: ticket_id,
      reason: resolution_note || null,
      details: { status, priority },
    });

    return NextResponse.json({ success: true, ticket: updated, message: 'Ticket updated.' });
  }

  const comp = CompensationResolveSchema.safeParse(body);
  if (comp.success) {
    const { ticket_id, resolution_note, compensation_type, coupon_amount_inr, extend_days, subscription_id } = comp.data;
    const { data: ticket } = await access.admin.from('support_tickets').select('*').eq('id', ticket_id).maybeSingle();
    if (!ticket) return NextResponse.json({ success: false, error: 'Ticket not found.' }, { status: 404 });

    let promoGranted: string | null = null;
    let publicMessage = `Ticket resolved: ${resolution_note}`;

    if (compensation_type === 'apology_coupon') {
      const amtInr = coupon_amount_inr ?? 50;
      promoGranted = `CARE${amtInr}-${crypto.randomBytes(2).toString('hex').toUpperCase()}`;
      await access.admin.from('promo_codes').insert({
        code: promoGranted,
        title: `Support Courtesy ₹${amtInr} Off`,
        description: `Issued for support ticket #${ticket_id.slice(0, 8)}`,
        flat_discount_paise: amtInr * 100,
        min_order_paise: amtInr * 100,
        usage_limit: 1,
        max_uses_per_user: 1,
        show_in_app: false,
        is_active: true,
        created_by: access.userId,
        valid_until: new Date(Date.now() + 30 * 86400000).toISOString(),
      });
      publicMessage = `${resolution_note}\n\nCourtesy Promo Code Issued: ${promoGranted} (₹${amtInr} off, valid 30 days).`;
    } else if (compensation_type === 'extend_subscription' && subscription_id) {
      const days = extend_days ?? 3;
      const { data: sub } = await access.admin.from('subscriptions').select('id,expires_at').eq('id', subscription_id).maybeSingle();
      if (sub) {
        const baseExp = sub.expires_at ? Math.max(Date.now(), new Date(sub.expires_at).getTime()) : Date.now();
        await access.admin
          .from('subscriptions')
          .update({ expires_at: new Date(baseExp + days * 86400000).toISOString(), status: 'active' })
          .eq('id', subscription_id);
        publicMessage = `${resolution_note}\n\nYour meal pass validity has been extended by ${days} days.`;
      }
    } else if (compensation_type === 'refund_request' && ticket.payment_transaction_id) {
      const { data: tx } = await access.admin
        .from('payment_transactions')
        .select('id,amount_paise')
        .eq('id', ticket.payment_transaction_id)
        .maybeSingle();
      if (tx) {
        await access.admin.from('refunds').insert({
          payment_transaction_id: tx.id,
          amount_paise: tx.amount_paise,
          reason_code: 'support_resolution',
          reason_note: resolution_note,
          status: 'requested',
          requested_by: access.userId,
          idempotency_key: `ticket-${ticket_id}`,
        });
        publicMessage = `${resolution_note}\n\nA refund request has been queued for finance verification.`;
      }
    }

    await access.admin.from('support_ticket_messages').insert({
      ticket_id,
      sender_role: 'admin',
      sender_id: access.userId,
      sender_name: 'Thali Resolution Desk',
      message: publicMessage,
      is_internal: false,
    });

    const { data: updated } = await access.admin
      .from('support_tickets')
      .update({
        status: 'resolved',
        resolution_note,
        resolution_action: compensation_type,
        promo_code_granted: promoGranted,
        assigned_to: access.userId,
        resolved_at: new Date().toISOString(),
      })
      .eq('id', ticket_id)
      .select('*')
      .single();

    if (ticket.created_by && ticket.requester_role !== 'provider') {
      await access.admin
        .from('customer_notifications')
        .insert({
          customer_id: ticket.created_by,
          title: promoGranted ? `Resolved · Coupon ${promoGranted}` : 'Support Ticket Resolved',
          message: publicMessage.slice(0, 220),
          notification_type: promoGranted ? 'offer' : 'support',
          is_read: false,
        })
        .then(() => null, () => null);
    } else if (ticket.provider_id) {
      addPartnerNotification({
        provider_id: ticket.provider_id,
        type: 'support',
        title: 'Support Ticket Resolved',
        message: publicMessage.slice(0, 220),
        action_tab: 'support',
      });
    }

    await logAdminAudit(access.admin, {
      actorUserId: access.userId,
      action: `support.resolved.${compensation_type}`,
      subjectType: 'support_ticket',
      subjectId: ticket_id,
      reason: resolution_note,
      details: { promoGranted, subscription_id, extend_days },
    });

    return NextResponse.json({
      success: true,
      ticket: updated,
      promo_code: promoGranted,
      message: 'Support ticket resolved cleanly.',
    });
  }

  return NextResponse.json({ success: false, error: 'Unsupported support action payload.' }, { status: 400 });
}
