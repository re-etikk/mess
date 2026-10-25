import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const customerId = searchParams.get('customer_id') || 'cust-ritik-001';

  const notifs = Array.from(platformStore.notifications.values())
    .filter((n) => n.customer_id === customerId)
    .sort((a, b) => b.created_at.localeCompare(a.created_at));

  return NextResponse.json({
    success: true,
    total: notifs.length,
    unread_count: notifs.filter((n) => !n.is_read).length,
    notifications: notifs,
  });
}

export async function PATCH(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const notifId = body.notification_id;

    if (notifId) {
      const notif = platformStore.notifications.get(notifId);
      if (notif) notif.is_read = true;
    } else {
      // Mark all read for customer
      const customerId = body.customer_id || 'cust-ritik-001';
      for (const n of platformStore.notifications.values()) {
        if (n.customer_id === customerId) n.is_read = true;
      }
    }

    return NextResponse.json({ success: true, message: 'Notifications updated.' });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err.message }, { status: 500 });
  }
}
