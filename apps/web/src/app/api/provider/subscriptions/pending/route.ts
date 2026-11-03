import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || searchParams.get('providerId');

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const pendingList: any[] = [];
  const seenIds = new Set<string>();

  // 1. Check Supabase DB
  const admin = getAdminClient();
  if (admin) {
    try {
      const { data: dbSubs, error } = await admin
        .from('subscriptions')
        .select(`
          id,
          provider_id,
          customer_id,
          plan_id,
          status,
          plan_type_snapshot,
          plan_name_snapshot,
          price_paid_paise,
          initial_meal_credits,
          remaining_meal_credits,
          created_at,
          profiles:customer_id (
            display_name,
            phone_e164
          )
        `)
        .eq('provider_id', providerId)
        .eq('status', 'pending_payment')
        .order('created_at', { ascending: false });

      if (!error && dbSubs) {
        for (const sub of dbSubs) {
          seenIds.add(sub.id);
          const profile = Array.isArray(sub.profiles) ? sub.profiles[0] : sub.profiles;
          pendingList.push({
            id: sub.id,
            provider_id: sub.provider_id,
            customer_id: sub.customer_id,
            customer_name: profile?.display_name || 'Customer',
            customer_phone: profile?.phone_e164 || '',
            plan_id: sub.plan_id,
            plan_name: sub.plan_name_snapshot || 'Meal Plan',
            plan_type: sub.plan_type_snapshot || 'fixed_period',
            price_paise: sub.price_paid_paise || 0,
            price_inr: (sub.price_paid_paise || 0) / 100,
            status: sub.status,
            payment_mode: 'counter_cash',
            created_at: sub.created_at,
          });
        }
      }
    } catch (e) {
      console.warn('DB error fetching pending subscriptions:', e);
    }
  }

  // 2. Check platformStore
  for (const [id, sub] of platformStore.subscriptions.entries()) {
    if (sub.provider_id === providerId && sub.status === 'pending_payment' && !seenIds.has(id)) {
      seenIds.add(id);
      pendingList.push({
        id: sub.id,
        provider_id: sub.provider_id,
        customer_id: sub.customer_id,
        customer_name: sub.customer_name || 'Customer',
        customer_phone: sub.customer_phone || '',
        customer_email: sub.customer_email || '',
        plan_id: sub.plan_id,
        plan_name: sub.plan_name,
        plan_type: sub.plan_type,
        price_paise: sub.price_paid_paise,
        price_inr: sub.price_paid_paise / 100,
        status: sub.status,
        payment_mode: sub.payment_mode || 'counter_cash',
        receipt_url: (sub as any).receipt_url || '',
        utr_reference: (sub as any).utr_reference || '',
        upgrade_from_subscription_id: (sub as any).upgrade_from_subscription_id || null,
        upgrade_details: (sub as any).upgrade_details || null,
        created_at: sub.created_at,
      });
    }
  }

  // Sort descending by created_at
  pendingList.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

  return NextResponse.json({
    success: true,
    pending: pendingList,
    count: pendingList.length,
  });
}
