import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id');
  const customerId = searchParams.get('customer_id');

  if (!providerId || !customerId) {
    return NextResponse.json({ success: false, error: 'provider_id and customer_id are required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: true, messages: [] });
  }

  try {
    const { data: messages, error } = await admin
      .from('chat_messages')
      .select('*')
      .eq('provider_id', providerId)
      .eq('customer_id', customerId)
      .order('created_at', { ascending: true })
      .limit(100);

    if (error) {
      console.error('Error fetching chat messages:', error.message);
      return NextResponse.json({ success: true, messages: [] });
    }

    // Mark unread messages as read
    const unreadIds = (messages || [])
      .filter((m) => !m.is_read)
      .map((m) => m.id);

    if (unreadIds.length > 0) {
      await admin
        .from('chat_messages')
        .update({ is_read: true })
        .in('id', unreadIds);
    }

    return NextResponse.json({
      success: true,
      messages: messages || [],
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err?.message || 'Failed to load chat messages' }, { status: 500 });
  }
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

    const admin = getAdminClient();
    if (!admin) {
      return NextResponse.json({
        success: true,
        message: {
          id: `msg-${Date.now()}`,
          provider_id: providerId,
          customer_id: customerId,
          sender_role: senderRole,
          sender_name: senderName,
          sender_id: senderId,
          message,
          attachment_url: attachmentUrl,
          created_at: new Date().toISOString(),
        },
      });
    }

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
      .single();

    if (error) {
      console.error('Failed to insert chat message:', error.message);
      return NextResponse.json({ success: false, error: error.message }, { status: 500 });
    }

    // Add in-app notification for the recipient
    try {
      const recipientUserId = senderRole === 'customer' ? null : customerId;
      if (recipientUserId && recipientUserId.length > 10) {
        await admin.from('notifications').insert({
          user_id: recipientUserId,
          title: `New message from ${senderName}`,
          body: message.length > 80 ? `${message.slice(0, 77)}...` : message,
          notification_type: 'system',
          is_read: false,
        });
      }
    } catch {}

    return NextResponse.json({
      success: true,
      message: newMsg,
    }, { status: 201 });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err?.message || 'Server error sending message' }, { status: 500 });
  }
}
