import { NextRequest, NextResponse } from 'next/server';
import { sendEmailNotification } from '@/lib/notifications';
import {
  escapeHtml,
  getClientIp,
  verifySignedSessionToken,
} from '@/lib/auth-session';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient as createSessionClient } from '@/lib/supabase/server';
import { checkRateLimit } from '@/lib/rate-limiter';

export const dynamic = 'force-dynamic';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function resolveOptionalAuthUser(req: NextRequest): Promise<{ userId: string; email?: string; role?: string; providerId?: string } | null> {
  const authHeader = req.headers.get('authorization');
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7).trim();
    if (!token) return null;
    const signed = verifySignedSessionToken(token, 'thali_tok_');
    if (signed) {
      return {
        userId: signed.userId,
        email: signed.email,
        role: signed.role,
        providerId: signed.providerId,
      };
    }
    const admin = getAdminClient();
    if (admin) {
      try {
        const { data: { user } } = await admin.auth.getUser(token);
        if (user) {
          return { userId: user.id, email: user.email || undefined };
        }
      } catch {}
    }
  }
  const cookieToken = req.cookies.get('thali_session_token')?.value?.trim();
  if (cookieToken) {
    const signedCookie = verifySignedSessionToken(cookieToken, 'thali_tok_');
    if (signedCookie) {
      return {
        userId: signedCookie.userId,
        email: signedCookie.email,
        role: signedCookie.role,
        providerId: signedCookie.providerId,
      };
    }
  }
  try {
    const supabase = await createSessionClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (user) return { userId: user.id, email: user.email || undefined };
  } catch {}
  return null;
}

export async function GET(req: NextRequest) {
  const actor = await resolveOptionalAuthUser(req);
  if (!actor) {
    return NextResponse.json({ success: false, error: 'Authentication required to view support tickets.' }, { status: 401 });
  }

  const admin = getAdminClient();
  if (!admin || !UUID_RE.test(actor.userId)) {
    return NextResponse.json({ success: true, tickets: [] }, { headers: { 'Cache-Control': 'private, no-store' } });
  }

  try {
    let providerIds: string[] = [];
    if (actor.providerId && UUID_RE.test(actor.providerId)) {
      providerIds = [actor.providerId];
    } else {
      const { data: owned } = await admin.from('providers').select('id').eq('owner_user_id', actor.userId).limit(10);
      providerIds = (owned ?? []).map((p: any) => String(p.id));
    }

    const orFilters = [`created_by.eq.${actor.userId}`, `about_user_id.eq.${actor.userId}`];
    if (providerIds.length > 0) {
      orFilters.push(`provider_id.in.(${providerIds.join(',')})`);
    }

    const { data: tickets, error } = await admin
      .from('support_tickets')
      .select(
        'id,category,subject,description,status,priority,requester_role,resolution_note,resolution_action,promo_code_granted,resolved_at,created_at,updated_at'
      )
      .or(orFilters.join(','))
      .order('created_at', { ascending: false })
      .limit(40);

    if (error) {
      return NextResponse.json({ success: false, error: 'Support tickets could not be loaded.' }, { status: 503 });
    }

    const ticketIds = (tickets ?? []).map((t: any) => t.id);
    const messagesByTicket = new Map<string, any[]>();
    if (ticketIds.length > 0) {
      try {
        const { data: msgs } = await admin
          .from('support_ticket_messages')
          .select('id,ticket_id,sender_role,sender_name,message,created_at')
          .in('ticket_id', ticketIds)
          .eq('is_internal', false)
          .order('created_at', { ascending: true });

        for (const m of msgs ?? []) {
          const arr = messagesByTicket.get(m.ticket_id) || [];
          arr.push(m);
          messagesByTicket.set(m.ticket_id, arr);
        }
      } catch {}
    }

    return NextResponse.json(
      {
        success: true,
        tickets: (tickets ?? []).map((t: any) => ({
          ...t,
          messages: messagesByTicket.get(t.id) || [],
        })),
      },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  } catch {
    return NextResponse.json({ success: false, error: 'Support tickets are temporarily unavailable.' }, { status: 503 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const rl = checkRateLimit(`support:${getClientIp(req)}`, 8, 15 * 60 * 1000);
    if (!rl.isAllowed) {
      return NextResponse.json(
        { success: false, error: 'Too many support requests submitted. Please try again later.' },
        { status: 429 }
      );
    }

    const body = await req.json().catch(() => ({}));
    const actor = await resolveOptionalAuthUser(req);

    const name = String(body.name || '').trim().slice(0, 80) || 'User';
    const email = String(body.email || actor?.email || '').trim().slice(0, 120) || 'No email provided';
    const phone = String(body.phone || '').trim().slice(0, 20) || 'No phone provided';
    const category = String(body.category || '').trim().slice(0, 60) || 'General Inquiry';
    const subjectInput = String(body.subject || '').trim().slice(0, 160);
    const description = String(body.description ?? body.message ?? '').trim().slice(0, 2500);
    const role = body.role === 'provider' || actor?.role === 'provider' ? 'provider' : 'customer';
    const priority = ['low', 'normal', 'high', 'urgent'].includes(String(body.priority || '').toLowerCase())
      ? String(body.priority).toLowerCase()
      : 'normal';

    if (!description || description.length < 5) {
      return NextResponse.json(
        { success: false, error: 'Please enter a brief description of your issue.' },
        { status: 400 }
      );
    }

    const admin = getAdminClient();
    let ticketId: string | null = null;
    const rawProv = String(body.provider_id || actor?.providerId || '').trim();
    let providerId: string | null = UUID_RE.test(rawProv) ? rawProv : null;
    const bookingId = UUID_RE.test(String(body.booking_id || '')) ? String(body.booking_id) : null;
    const paymentId = UUID_RE.test(String(body.payment_transaction_id || ''))
      ? String(body.payment_transaction_id)
      : null;

    if (admin) {
      try {
        if (!providerId && role === 'provider' && actor && UUID_RE.test(actor.userId)) {
          const { data: owned } = await admin
            .from('providers')
            .select('id')
            .eq('owner_user_id', actor.userId)
            .limit(1)
            .maybeSingle();
          if (owned?.id) providerId = owned.id;
        }

        const createdBy = actor && UUID_RE.test(actor.userId) ? actor.userId : null;
        const { data: inserted, error: insertErr } = await admin
          .from('support_tickets')
          .insert({
            created_by: createdBy,
            about_user_id: createdBy,
            provider_id: providerId,
            booking_id: bookingId,
            payment_transaction_id: paymentId,
            category,
            subject: subjectInput || `${category} support request`,
            description,
            status: 'open',
            priority,
            requester_name: name,
            requester_email: email,
            requester_phone: phone,
            requester_role: role,
          })
          .select('id')
          .single();

        if (!insertErr && inserted?.id) {
          ticketId = inserted.id;
          await admin
            .from('support_ticket_messages')
            .insert({
              ticket_id: inserted.id,
              sender_role: role,
              sender_id: createdBy,
              sender_name: name,
              message: description,
              is_internal: false,
            })
            .then(() => null, () => null);
        } else if (insertErr) {
          console.warn('support_tickets DB insert error:', insertErr.message);
        }
      } catch (e: any) {
        console.warn('Support DB persistence warning:', e?.message || 'unknown');
      }
    }

    const supportEmail = process.env.SUPPORT_EMAIL || 'support@thali.store';
    const mailSubject = `[THALI SUPPORT${ticketId ? ` #${ticketId.slice(0, 8)}` : ''}] ${category} - from ${name} (${role.toUpperCase()})`;
    const html = `
      <div style="font-family: sans-serif; max-width: 600px; padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px; background: #ffffff;">
        <h2 style="color: #0f172a; margin-top: 0;">New Support Request from ${escapeHtml(name)}</h2>
        <div style="background: #f8fafc; padding: 15px; border-radius: 8px; margin-bottom: 20px;">
          ${ticketId ? `<p style="margin: 4px 0;"><strong>Ticket ID:</strong> ${escapeHtml(ticketId)}</p>` : ''}
          <p style="margin: 4px 0;"><strong>Subject:</strong> ${escapeHtml(subjectInput || category)}</p>
          <p style="margin: 4px 0;"><strong>Category:</strong> ${escapeHtml(category)}</p>
          <p style="margin: 4px 0;"><strong>Role:</strong> ${escapeHtml(role.toUpperCase())}</p>
          <p style="margin: 4px 0;"><strong>Phone:</strong> ${escapeHtml(phone)}</p>
          <p style="margin: 4px 0;"><strong>Email:</strong> ${escapeHtml(email)}</p>
          <p style="margin: 4px 0;"><strong>Received At:</strong> ${escapeHtml(new Date().toLocaleString('en-IN'))}</p>
        </div>
        <h3 style="color: #334155; margin-bottom: 8px;">Issue Description:</h3>
        <p style="white-space: pre-wrap; background: #fffbeb; padding: 16px; border-radius: 8px; border: 1px solid #fde68a; color: #78350f;">
          ${escapeHtml(description)}
        </p>
      </div>
    `;

    const emailResult = await sendEmailNotification({
      to: supportEmail,
      subject: mailSubject,
      html,
    });

    return NextResponse.json(
      {
        success: true,
        ticket_id: ticketId,
        email_dispatched: emailResult.success,
        message: 'Support ticket submitted successfully! Our team will respond shortly.',
      },
      { status: 201 }
    );
  } catch {
    return NextResponse.json(
      { success: false, error: 'Failed to submit support ticket. Please try again.' },
      { status: 500 }
    );
  }
}

export async function PATCH(req: NextRequest) {
  const actor = await resolveOptionalAuthUser(req);
  if (!actor || !UUID_RE.test(actor.userId)) {
    return NextResponse.json({ success: false, error: 'Authentication required.' }, { status: 401 });
  }

  const body = await req.json().catch(() => ({}));
  const ticketId = String(body.ticket_id || '').trim();
  const message = String(body.message || '').trim().slice(0, 2000);
  if (!UUID_RE.test(ticketId) || message.length < 2) {
    return NextResponse.json({ success: false, error: 'Valid ticket ID and reply message are required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: false, error: 'Support service unavailable.' }, { status: 503 });
  }

  const { data: ticket } = await admin
    .from('support_tickets')
    .select('id,created_by,about_user_id,provider_id,requester_role,requester_name')
    .eq('id', ticketId)
    .maybeSingle();

  if (!ticket) {
    return NextResponse.json({ success: false, error: 'Ticket not found.' }, { status: 404 });
  }

  let authorized = ticket.created_by === actor.userId || ticket.about_user_id === actor.userId;
  if (!authorized && ticket.provider_id) {
    const { data: prov } = await admin
      .from('providers')
      .select('id')
      .eq('id', ticket.provider_id)
      .eq('owner_user_id', actor.userId)
      .maybeSingle();
    if (prov) authorized = true;
  }

  if (!authorized) {
    return NextResponse.json({ success: false, error: 'You cannot reply to another user ticket.' }, { status: 403 });
  }

  const senderRole = actor.role === 'provider' ? 'provider' : ticket.requester_role === 'provider' ? 'provider' : 'customer';
  const { error: msgErr } = await admin.from('support_ticket_messages').insert({
    ticket_id: ticketId,
    sender_role: senderRole,
    sender_id: actor.userId,
    sender_name: ticket.requester_name || 'User',
    message,
    is_internal: false,
  });

  if (msgErr) {
    return NextResponse.json({ success: false, error: 'Could not save reply.' }, { status: 503 });
  }

  await admin
    .from('support_tickets')
    .update({ status: 'open', updated_at: new Date().toISOString() })
    .eq('id', ticketId)
    .in('status', ['waiting_for_user', 'resolved']);

  return NextResponse.json({ success: true, message: 'Reply added to ticket.' });
}
