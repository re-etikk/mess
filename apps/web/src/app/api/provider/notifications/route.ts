import { NextRequest, NextResponse } from 'next/server';
import { getPartnerNotifications, markPartnerNotificationRead, addPartnerNotification } from '@/lib/partner-notifications';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || searchParams.get('providerId');

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  let notifications = getPartnerNotifications(providerId);

  // If in-memory notifications list is empty (e.g. server restart), reconstruct from DB / platformStore
  if (notifications.length === 0) {
    const admin = getAdminClient();
    if (admin) {
      try {
        const { data: subs } = await admin
          .from('subscriptions')
          .select('id,customer_id,plan_id,status,created_at,profiles:customer_id(display_name,phone_e164)')
          .eq('provider_id', providerId)
          .order('created_at', { ascending: false })
          .limit(10);

        if (subs && subs.length > 0) {
          for (const s of subs) {
            const cName = (s.profiles as any)?.display_name || 'Student';
            const isPending = s.status === 'pending_payment';
            addPartnerNotification({
              provider_id: providerId,
              type: isPending ? 'pending_payment' : 'info',
              title: isPending ? 'Pass Order (Pending Payment)' : 'Active Subscriber',
              message: isPending
                ? `${cName} placed a pass order. Verify cash or UPI payment at counter.`
                : `${cName} is an active subscriber at your mess.`,
              customer_name: cName,
              subscription_id: s.id,
            });
          }
        }
      } catch (_) {}
    }
    notifications = getPartnerNotifications(providerId);
  }

  const unreadCount = notifications.filter((n) => !n.read).length;

  return NextResponse.json({
    success: true,
    notifications,
    unread_count: unreadCount,
  });
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = body.provider_id || body.providerId;
  const notifId = body.notification_id || body.id;

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  markPartnerNotificationRead(providerId, notifId);

  return NextResponse.json({
    success: true,
    message: 'Notifications marked as read.',
  });
}
