import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { requireCustomerIdentity } from '@/lib/auth-session';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const queryCustId = searchParams.get('customer_id') || searchParams.get('userId');

    const auth = await requireCustomerIdentity(req, queryCustId);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }
    const userId = auth.userId;

    const db = getAdminClient();
    if (db) {
      try {
        const [subscriptions, redemptions, notifs] = await Promise.all([
          db
            .from('subscriptions')
            .select(
              'id,status,plan_id,plan_type_snapshot,plan_name_snapshot,price_paid_paise,initial_meal_credits,remaining_meal_credits,starts_at,expires_at,created_at,provider_id,providers(id,display_name,slug,locality,city)'
            )
            .eq('customer_id', userId)
            .order('created_at', { ascending: false })
            .limit(30),
          db
            .from('meal_redemptions')
            .select('id,redeemed_at,provider_id,providers(display_name),meal_bookings(service_date,meal_slots(name))')
            .eq('customer_id', userId)
            .order('redeemed_at', { ascending: false })
            .limit(30),
          db
            .from('customer_notifications')
            .select('id,title,message,notification_type,action_route,is_read,created_at')
            .eq('customer_id', userId)
            .order('created_at', { ascending: false })
            .limit(20)
            .then((r) => r, () => ({ data: [] as any[] })),
        ]);

        if ((subscriptions.data && subscriptions.data.length > 0) || (redemptions.data && redemptions.data.length > 0)) {
          return NextResponse.json(
            {
              success: true,
              subscriptions: subscriptions.data ?? [],
              recent_redemptions: redemptions.data ?? [],
              notifications: (notifs as any)?.data ?? [],
            },
            { headers: { 'Cache-Control': 'private, no-store' } }
          );
        }
      } catch {}
    }

    const userSubs: any[] = [];
    for (const sub of platformStore.subscriptions.values()) {
      if (sub.customer_id === userId) {
        const prov = platformStore.providers.get(sub.provider_id);
        userSubs.push({
          id: sub.id,
          status: sub.status,
          plan_id: sub.plan_id,
          plan_type_snapshot: sub.plan_type,
          plan_name_snapshot: sub.plan_name,
          price_paid_paise: sub.price_paid_paise,
          initial_meal_credits: sub.initial_meal_credits,
          remaining_meal_credits: sub.remaining_meal_credits,
          starts_at: sub.starts_at,
          expires_at: sub.expires_at,
          created_at: sub.created_at,
          provider_id: sub.provider_id,
          providers: prov
            ? { id: prov.id, display_name: prov.display_name, slug: prov.slug, locality: prov.locality, city: prov.city }
            : { id: sub.provider_id, display_name: 'Mess Kitchen' },
        });
      }
    }

    const userReds: any[] = [];
    for (const red of platformStore.redemptions.values()) {
      if (red.user_id === userId) {
        const prov = platformStore.providers.get(red.provider_id);
        userReds.push({
          id: red.id,
          redeemed_at: red.redeemed_at,
          provider_id: red.provider_id,
          providers: { display_name: prov?.display_name || 'Mess Counter' },
          meal_bookings: { service_date: red.date, meal_slots: { name: red.slot } },
        });
      }
    }

    const userNotifs = Array.from(platformStore.notifications.values()).filter((n) => n.customer_id === userId);

    return NextResponse.json(
      {
        success: true,
        subscriptions: userSubs,
        recent_redemptions: userReds,
        notifications: userNotifs,
      },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  } catch (e: any) {
    return NextResponse.json({ success: false, error: e?.message || 'Unable to load dashboard.' }, { status: 500 });
  }
}
