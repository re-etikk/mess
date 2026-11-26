import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { isAllowedMediaUrl, requireCustomerIdentity } from '@/lib/auth-session';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

async function resolveChatParticipant(
  req: NextRequest,
  providerId: string,
  customerId: string
): Promise<{ ok: true; role: 'provider' | 'customer'; userId: string } | { ok: false; status: 401 | 403; error: string }> {
  const provAuth = await requireProviderOwnership(req, providerId);
  if (provAuth.ok) {
    return { ok: true, role: 'provider', userId: provAuth.userId };
  }
  const custAuth = await requireCustomerIdentity(req, customerId);
  if (custAuth.ok) {
    return { ok: true, role: 'customer', userId: custAuth.userId };
  }
  return {
    ok: false,
    status: custAuth.status === 403 || provAuth.status === 403 ? 403 : 401,
    error: 'Authentication required to access this conversation.',
  };
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id')?.trim();
  const customerId = searchParams.get('customer_id')?.trim();

  if (!providerId || !customerId) {
    return NextResponse.json({ success: false, error: 'provider_id and customer_id are required.' }, { status: 400 });
  }

  const participant = await resolveChatParticipant(req, providerId, customerId);
  if (!participant.ok) {
    return NextResponse.json({ success: false, error: participant.error }, { status: participant.status });
  }

  const allMessages: any[] = [];
  const seenIds = new Set<string>();

  const admin = getAdminClient();
  if (admin) {
    try {
      const { data: messages, error } = await admin
        .from('chat_messages')
        .select('*')
        .eq('provider_id', providerId)
        .eq('customer_id', customerId)
        .order('created_at', { ascending: true })
        .limit(100);

      if (!error && messages) {
        for (const m of messages) {
          seenIds.add(m.id);
          allMessages.push(m);
        }

        // Mark ONLY incoming messages from the counterparty as read
        const otherRole = participant.role === 'provider' ? 'customer' : 'provider';
        const unreadIds = messages.filter((m) => !m.is_read && m.sender_role === otherRole).map((m) => m.id);
        if (unreadIds.length > 0) {
          await admin.from('chat_messages').update({ is_read: true }).in('id', unreadIds);
        }
      }
    } catch (e: any) {
      console.warn('DB chat fetch error:', e?.message);
    }
  }

  for (const m of platformStore.chatMessages) {
    if (m.provider_id === providerId && m.customer_id === customerId && !seenIds.has(m.id)) {
      seenIds.add(m.id);
      allMessages.push(m);
    }
  }

  allMessages.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());

  return NextResponse.json(
    {
      success: true,
      transport_security: 'TLS',
      messages: allMessages,
    },
    { headers: { 'Cache-Control': 'no-store' } }
  );
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = String(body.provider_id || body.providerId || '').trim();
    const customerId = String(body.customer_id || body.customerId || '').trim();
    const message = String(body.message || '').trim().slice(0, 2000);
    const attachmentUrl = body.attachment_url ? String(body.attachment_url).trim() : null;

    if (!providerId || !customerId || !message) {
      return NextResponse.json({ success: false, error: 'provider_id, customer_id, and message are required.' }, { status: 400 });
    }
    if (attachmentUrl && !isAllowedMediaUrl(attachmentUrl)) {
      return NextResponse.json({ success: false, error: 'Invalid attachment URL.' }, { status: 400 });
    }

    const participant = await resolveChatParticipant(req, providerId, customerId);
    if (!participant.ok) {
      return NextResponse.json({ success: false, error: participant.error }, { status: participant.status });
    }

    const senderRole = participant.role;
    const senderName =
      String(body.sender_name || '').trim().slice(0, 80) ||
      (senderRole === 'customer' ? 'Customer' : 'Kitchen Partner');
    const senderId = participant.userId;

    const msgObj = {
      id: `msg-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`,
      provider_id: providerId,
      customer_id: customerId,
      sender_role: senderRole,
      sender_name: senderName,
      sender_id: senderId,
      message,
      attachment_url: attachmentUrl,
      is_read: false,
      created_at: new Date().toISOString(),
    };

    platformStore.chatMessages.push(msgObj);

    const admin = getAdminClient();
    if (admin) {
      try {
        const { data: newMsg, error } = await admin
          .from('chat_messages')
          .insert({
            provider_id: providerId,
            customer_id: customerId,
            sender_role: senderRole,
            sender_name: senderName,
            sender_id: senderId,
            message,
            attachment_url: attachmentUrl,
            is_read: false,
          })
          .select('*')
          .maybeSingle();

        if (!error && newMsg) {
          msgObj.id = newMsg.id;
        }
      } catch (dbErr: any) {
        console.warn('DB chat insert fallback to platformStore:', dbErr?.message);
      }
    }

    return NextResponse.json(
      {
        success: true,
        message: msgObj,
      },
      { status: 201 }
    );
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err?.message || 'Server error sending message' }, { status: 500 });
  }
}
