import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export async function GET() {
  const db = await createClient();
  const { data: auth } = await db.auth.getUser();
  if (!auth.user) return NextResponse.json({ success: false, error: 'Authentication required.' }, { status: 401 });
  const { data, error } = await db.from('notifications').select('id,category,title,body,deep_link,metadata,read_at,created_at').eq('user_id', auth.user.id).order('created_at', { ascending: false }).limit(100);
  if (error) return NextResponse.json({ success: false, error: 'Notifications are unavailable.' }, { status: 503 });
  return NextResponse.json({ success: true, total: data.length, unread_count: data.filter((item) => !item.read_at).length, notifications: data }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function PATCH(req: NextRequest) {
  const db = await createClient();
  const { data: auth } = await db.auth.getUser();
  if (!auth.user) return NextResponse.json({ success: false, error: 'Authentication required.' }, { status: 401 });
  let body: { notification_id?: string };
  try { body = await req.json(); } catch { body = {}; }
  let query = db.from('notifications').update({ read_at: new Date().toISOString() }).eq('user_id', auth.user.id);
  if (body.notification_id) query = query.eq('id', body.notification_id);
  const { error } = await query;
  if (error) return NextResponse.json({ success: false, error: 'Could not update notifications.' }, { status: 503 });
  return NextResponse.json({ success: true });
}
