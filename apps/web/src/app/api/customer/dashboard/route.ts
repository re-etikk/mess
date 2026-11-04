import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    let userId: string | null = null;

    // 1. Try Bearer token in headers
    const authHeader = req.headers.get('authorization');
    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.slice(7).trim();
      if (token.startsWith('jwt_session_') || token.startsWith('jwt_mock_')) {
        try {
          const payloadStr = Buffer.from(token.replace(/^jwt_(session|mock)_/, ''), 'base64url').toString('utf8');
          const sess = JSON.parse(payloadStr);
          userId = sess.userId || sess.id || null;
        } catch {}
      } else {
        const db = getAdminClient();
        if (db) {
          try {
            const { data: { user } } = await db.auth.getUser(token);
            if (user) userId = user.id;
          } catch {}
        }
        if (!userId) {
          try {
            const parts = token.split('.');
            if (parts.length === 3) {
              const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
              userId = payload.sub || null;
            }
          } catch {}
        }
      }
    }

    // 2. Try cookie session
    if (!userId) {
      try {
        const session = await createClient();
        const { data: { user } } = await session.auth.getUser();
        if (user) userId = user.id;
      } catch {}
    }

    // 3. Check query param fallback
    const { searchParams } = new URL(req.url);
    const queryCustId = searchParams.get('customer_id') || searchParams.get('userId');
    if (!userId && queryCustId) {
      userId = queryCustId;
    }

    if (!userId) {
      return NextResponse.json({ success: false, error: 'Authentication required.' }, { status: 401 });
    }

    const db = getAdminClient();
    if (db) {
      try {
        const [subscriptions, redemptions] = await Promise.all([
          db.from('subscriptions')
            .select('id,status,plan_id,plan_type_snapshot,plan_name_snapshot,price_paid_paise,initial_meal_credits,remaining_meal_credits,starts_at,expires_at,created_at,provider_id,providers(id,display_name,slug,locality,city)')
            .eq('customer_id', userId).order('created_at', { ascending: false }).limit(30),
          db.from('meal_redemptions')
            .select('id,redeemed_at,provider_id,providers(display_name),meal_bookings(service_date,meal_slots(name))')
            .eq('customer_id', userId).order('redeemed_at', { ascending: false }).limit(30),
        ]);

        if (subscriptions.data && subscriptions.data.length > 0) {
          return NextResponse.json({
            success: true,
            subscriptions: subscriptions.data,
            recent_redemptions: redemptions.data ?? [],
          }, { headers: { 'Cache-Control': 'private, no-store' } });
        }
      } catch {}
    }

    // Fallback: check platformStore
    const userSubs: any[] = [];
    for (const [_, sub] of platformStore.subscriptions.entries()) {
      if (sub.customer_id === userId || sub.id.includes(userId)) {
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
          payment_mode: sub.payment_mode,
          receipt_url: (sub as any).receipt_url,
          utr_reference: (sub as any).utr_reference,
          providers: {
            id: sub.provider_id,
            display_name: prov?.display_name || 'Mess Partner',
            slug: prov?.slug || 'mess',
            locality: prov?.locality || 'Locality',
            city: prov?.city || 'Bengaluru',
          },
        });
      }
    }

    const userReds: any[] = [];
    for (const [_, red] of platformStore.redemptions.entries()) {
      if (red.user_id === userId) {
        userReds.push({
          id: red.id,
          redeemed_at: red.redeemed_at,
          provider_id: red.provider_id,
          providers: {
            display_name: 'Mess Partner',
          },
          meal_bookings: {
            service_date: red.date,
            meal_slots: {
              name: red.slot,
            },
          },
        });
      }
    }

    return NextResponse.json({
      success: true,
      subscriptions: userSubs,
      recent_redemptions: userReds,
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Customer dashboard API error:', error);
    return NextResponse.json({ success: false, error: 'Customer dashboard is temporarily unavailable.' }, { status: 500 });
  }
}
