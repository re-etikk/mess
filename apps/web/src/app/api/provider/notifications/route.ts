import { NextRequest, NextResponse } from 'next/server';
import { getPartnerNotifications, markPartnerNotificationRead } from '@/lib/partner-notifications';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || searchParams.get('providerId');

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const notifications = getPartnerNotifications(providerId);
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
