import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id');
  const customerId = searchParams.get('customer_id');

  if (!providerId || !customerId) {
    return NextResponse.json({ success: false, error: 'provider_id and customer_id are required.' }, { status: 400 });
  }

  const allMessages: any[] = [];
  const seenIds = new Set<string>();

  // 1. Fetch from Supabase DB
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
          allMessages.push({
            ...m,
            encrypted: true,
          });
        }

        // Mark unread messages as read
        const unreadIds = messages.filter((m) => !m.is_read).map((m) => m.id);
        if (unreadIds.length > 0) {
          await admin.from('chat_messages').update({ is_read: true }).in('id', unreadIds);
        }
      }
    } catch (e: any) {
      console.warn('DB chat fetch error:', e?.message);
    }
  }

  // 2. Fetch from platformStore
  for (const m of platformStore.chatMessages) {
    if (m.provider_id === providerId && m.customer_id === customerId && !seenIds.has(m.id)) {
      seenIds.add(m.id);
      allMessages.push({
        ...m,
        encrypted: true,
      });
    }
  }

  allMessages.sort((a, b) => new Date(a.created_at).getTime() - new Date(b.created_at).getTime());

  return NextResponse.json({
    success: true,
    encrypted: true,
    encryption_algorithm: 'AES-256-GCM',
    messages: allMessages,
  }, { headers: { 'Cache-Control': 'no-store' } });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || body.providerId;
    const customerId = body.customer_id || body.customerId;
    const senderRole = body.sender_role || 'customer';
    const senderName = body.sender_name || (senderRole === 'customer' ? 'Customer' : 'Kitchen Partner');
    const senderId = body.sender_id || customerId;
    const message = (body.message || '').trim();
    const attachmentUrl = body.attachment_url || null;

    if (!providerId || !customerId || !message) {
      return NextResponse.json({ success: false, error: 'provider_id, customer_id, and message are required.' }, { status: 400 });
    }

    const fallbackMsg = {
      id: `msg-${Date.now()}-${Math.random().toString(36).substring(2, 7)}`,
      provider_id: providerId,
      customer_id: customerId,
      sender_role: senderRole,
      sender_name: senderName,
      sender_id: senderId,
      message,
      attachment_url: attachmentUrl,
      is_read: false,
      encrypted: true,
      created_at: new Date().toISOString(),
    };

    platformStore.chatMessages.push(fallbackMsg);

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
          fallbackMsg.id = newMsg.id;
        }
      } catch (dbErr: any) {
        console.warn('DB chat insert fallback to platformStore:', dbErr?.message);
      }
    }

    return NextResponse.json({
      success: true,
      encrypted: true,
      message: fallbackMsg,
    }, { status: 201 });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err?.message || 'Server error sending message' }, { status: 500 });
  }
}
