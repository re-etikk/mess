import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id');
  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: true, conversations: [] });
  }

  try {
    const { data: messages, error } = await admin
      .from('chat_messages')
      .select('*')
      .eq('provider_id', providerId)
      .order('created_at', { ascending: false })
      .limit(300);

    if (error) {
      return NextResponse.json({ success: true, conversations: [] });
    }

    const conversationsMap = new Map<string, {
      customer_id: string;
      customer_name: string;
      last_message: string;
      last_message_at: string;
      unread_count: number;
    }>();

    for (const msg of messages || []) {
      const existing = conversationsMap.get(msg.customer_id);
      if (!existing) {
        conversationsMap.set(msg.customer_id, {
          customer_id: msg.customer_id,
          customer_name: msg.sender_role === 'customer' ? msg.sender_name : 'Customer',
          last_message: msg.message,
          last_message_at: msg.created_at,
          unread_count: (!msg.is_read && msg.sender_role === 'customer') ? 1 : 0,
        });
      } else {
        if (!msg.is_read && msg.sender_role === 'customer') {
          existing.unread_count += 1;
        }
        if (existing.customer_name === 'Customer' && msg.sender_role === 'customer') {
          existing.customer_name = msg.sender_name;
        }
      }
    }

    return NextResponse.json({
      success: true,
      conversations: Array.from(conversationsMap.values()),
    }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err?.message || 'Failed to list conversations' }, { status: 500 });
  }
}
