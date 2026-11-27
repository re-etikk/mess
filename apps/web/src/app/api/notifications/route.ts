import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireCustomerIdentity } from '@/lib/auth-session';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

interface NormalizedNotification {
  id: string;
  title: string;
  message: string;
  notification_type: string;
  action_route: string | null;
  is_read: boolean;
  created_at: string;
}

function resolveNotificationsDb() {
  const admin = getAdminClient();
  if (admin) return admin;
  try {
    return createClient();
  } catch {
    return null;
  }
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const queryCustId = searchParams.get('customer_id') || searchParams.get('userId');

  const auth = await requireCustomerIdentity(req, queryCustId);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }
  const userId = auth.userId;

  const byId = new Map<string, NormalizedNotification>();
  const db = resolveNotificationsDb();

  if (db) {
    try {
      const { data } = await db
        .from('customer_notifications')
        .select('id,title,message,notification_type,action_route,is_read,created_at')
        .eq('customer_id', userId)
        .order('created_at', { ascending: false })
        .limit(50);

      for (const row of data ?? []) {
        if (!row?.id) continue;
        byId.set(String(row.id), {
          id: String(row.id),
          title: String(row.title || 'Notification'),
          message: String(row.message || ''),
          notification_type: String(row.notification_type || 'general'),
          action_route: row.action_route ? String(row.action_route) : null,
          is_read: row.is_read === true,
          created_at: String(row.created_at || new Date().toISOString()),
        });
      }
    } catch {}

    try {
      const { data: legacy } = await db
        .from('notifications')
        .select('id,title,message,type,is_read,created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(50);

      for (const row of legacy ?? []) {
        if (!row?.id || byId.has(String(row.id))) continue;
        byId.set(String(row.id), {
          id: String(row.id),
          title: String(row.title || 'Notification'),
          message: String(row.message || ''),
          notification_type: String(row.type || 'general'),
          action_route: null,
          is_read: row.is_read === true,
          created_at: String(row.created_at || new Date().toISOString()),
        });
      }
    } catch {}
  }

  for (const n of platformStore.notifications.values()) {
    if (n.customer_id !== userId) continue;
    if (!byId.has(n.id)) {
      byId.set(n.id, {
        id: n.id,
        title: n.title,
        message: n.message,
        notification_type: n.notification_type || 'general',
        action_route: (n as { action_route?: string }).action_route || null,
        is_read: n.is_read === true,
        created_at: n.created_at || new Date().toISOString(),
      });
    }
  }

  const notifications = Array.from(byId.values()).sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  );

  return NextResponse.json(
    { success: true, notifications },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function PATCH(req: NextRequest) {
  let body: { notification_id?: string; id?: string; mark_all?: boolean; customer_id?: string } = {};
  try {
    body = await req.json();
  } catch {}

  const auth = await requireCustomerIdentity(req, body.customer_id);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }
  const userId = auth.userId;
  const targetId = String(body.notification_id || body.id || '').trim();

  for (const [key, item] of platformStore.notifications.entries()) {
    if (item.customer_id !== userId) continue;
    if (!targetId || item.id === targetId || body.mark_all) {
      platformStore.notifications.set(key, { ...item, is_read: true });
    }
  }

  const db = resolveNotificationsDb();
  if (db) {
    try {
      let query = db.from('customer_notifications').update({ is_read: true }).eq('customer_id', userId);
      if (targetId && !body.mark_all) query = query.eq('id', targetId);
      await query;
    } catch {}

    try {
      let legacyQuery = db.from('notifications').update({ is_read: true }).eq('user_id', userId);
      if (targetId && !body.mark_all) legacyQuery = legacyQuery.eq('id', targetId);
      await legacyQuery;
    } catch {}
  }

  return NextResponse.json(
    { success: true },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}
