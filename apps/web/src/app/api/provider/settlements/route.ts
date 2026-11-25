import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || searchParams.get('providerId');

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok && access.status !== 401) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const allItems: any[] = [];
  const seenIds = new Set<string>();

  // 1. Fetch from Supabase DB
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
          created_at,
          payment_verified_at,
          profiles:customer_id (
            display_name,
            phone_e164
          )
        `)
        .eq('provider_id', providerId)
        .order('created_at', { ascending: false });

      if (!error && dbSubs) {
        const subIds = dbSubs.map((s: any) => s.id);
        const cfTxBySubId = new Map<string, { gateway_order_id?: string; gateway_payment_id?: string }>();
        if (subIds.length > 0) {
          try {
            const { data: cfTxs } = await admin
              .from('payment_transactions')
              .select('subscription_id, gateway_order_id, gateway_payment_id, status')
              .in('subscription_id', subIds)
              .eq('gateway_name', 'cashfree')
              .eq('status', 'succeeded');
            if (cfTxs) {
              for (const tx of cfTxs) {
                if (tx.subscription_id) {
                  cfTxBySubId.set(tx.subscription_id, tx);
                }
              }
            }
          } catch {}
        }

        for (const sub of dbSubs) {
          seenIds.add(sub.id);
          const profile = Array.isArray(sub.profiles) ? sub.profiles[0] : sub.profiles;
          const pricePaise = Number(sub.price_paid_paise || 0);
          const cfTx = cfTxBySubId.get(sub.id);
          allItems.push({
            id: sub.id,
            transaction_id: cfTx?.gateway_payment_id || cfTx?.gateway_order_id || `TXN-${sub.id.slice(0, 8).toUpperCase()}`,
            utr_reference: cfTx?.gateway_order_id || '',
            provider_id: sub.provider_id,
            customer_id: sub.customer_id,
            customer_name: profile?.display_name || 'Subscriber',
            customer_phone: profile?.phone_e164 || '',
            plan_name: sub.plan_name_snapshot || 'Meal Plan',
            plan_type: sub.plan_type_snapshot || 'fixed_period',
            amount_inr: pricePaise / 100,
            status: sub.status === 'active' ? 'paid' : sub.status,
            payment_mode: cfTx ? 'online_cashfree' : 'counter_upi',
            receipt_url: '',
            created_at: sub.created_at,
            paid_at: sub.payment_verified_at || sub.created_at,
          });
        }
      }
    } catch (e) {
      console.warn('DB error fetching provider subscriptions for settlements:', e);
    }
  }

  // 2. Fetch from platformStore
  for (const [id, sub] of platformStore.subscriptions.entries()) {
    if (sub.provider_id === providerId && !seenIds.has(id)) {
      seenIds.add(id);
      const isApproved = sub.status === 'active';
      const cfRef = (sub as any).cashfree_payment_id || (sub as any).cashfree_order_id || '';
      allItems.push({
        id: sub.id,
        transaction_id: cfRef || ((sub as any).utr_reference ? `UTR-${(sub as any).utr_reference}` : `TXN-${sub.id.slice(0, 8).toUpperCase()}`),
        utr_reference: (sub as any).utr_reference || (sub as any).cashfree_order_id || '',
        provider_id: sub.provider_id,
        customer_id: sub.customer_id,
        customer_name: sub.customer_name || 'Subscriber',
        customer_phone: sub.customer_phone || '',
        customer_email: sub.customer_email || '',
        plan_name: sub.plan_name,
        plan_type: sub.plan_type,
        amount_inr: (sub.price_paid_paise || 0) / 100,
        status: isApproved ? 'paid' : sub.status,
        payment_mode: sub.payment_mode === 'online' || cfRef ? 'online_cashfree' : (sub.payment_mode || 'counter_upi'),
        receipt_url: (sub as any).receipt_url || '',
        created_at: sub.created_at,
        paid_at: (sub as any).activated_at || sub.created_at,
      });
    }
  }

  // Sort descending by created_at
  allItems.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

  // Filter Paid (Active / Verified)
  const paid = allItems.filter(item => item.status === 'paid' || item.status === 'active');

  // Compute metrics
  let totalCollected = 0;
  let upiCollected = 0;
  let cashCollected = 0;

  for (const item of paid) {
    const amt = item.amount_inr || 0;
    totalCollected += amt;
    const modeLower = String(item.payment_mode || '').toLowerCase();
    if (modeLower === 'cash' || modeLower === 'counter_cash') {
      cashCollected += amt;
    } else {
      upiCollected += amt;
    }
  }

  // Monthly summary
  const monthlyMap: Record<string, { month: string; amount: number; count: number }> = {};
  for (const item of paid) {
    const date = new Date(item.paid_at || item.created_at);
    const monthKey = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
    const monthLabel = date.toLocaleString('default', { month: 'short', year: 'numeric' });
    if (!monthlyMap[monthKey]) {
      monthlyMap[monthKey] = { month: monthLabel, amount: 0, count: 0 };
    }
    monthlyMap[monthKey].amount += item.amount_inr;
    monthlyMap[monthKey].count += 1;
  }

  const monthlySummary = Object.values(monthlyMap);

  return NextResponse.json({
    success: true,
    provider_id: providerId,
    summary: {
      total_collected_inr: totalCollected,
      upi_collected_inr: upiCollected,
      cash_collected_inr: cashCollected,
      active_subscribers: paid.length,
      total_transactions: allItems.length,
    },
    paid,
    history: allItems,
    monthly_summary: monthlySummary,
  }, { headers: { 'Cache-Control': 'no-store' } });
}
