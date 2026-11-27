import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = String(searchParams.get('provider_id') || searchParams.get('providerId') || '').trim();
  const slotFilter = String(searchParams.get('slot') || '').trim().toUpperCase();

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  if (admin && UUID_RE.test(providerId)) {
    try {
      let query = admin
        .from('counter_orders')
        .select('*')
        .eq('provider_id', providerId)
        .order('created_at', { ascending: false })
        .limit(100);
      if (slotFilter && slotFilter !== 'ALL') {
        query = query.eq('slot', slotFilter);
      }
      const { data, error } = await query;
      if (!error) {
        return NextResponse.json(
          {
            success: true,
            orders: (data ?? []).map((row: any) => ({
              id: row.id,
              provider_id: row.provider_id,
              customer_name: row.customer_name,
              customer_phone: row.customer_phone || '',
              slot: row.slot,
              items_summary: row.items_summary,
              amount_paise: Number(row.amount_paise || 0),
              amount_inr: Math.round(Number(row.amount_paise || 0) / 100),
              payment_mode: row.payment_mode,
              status: row.status,
              created_at: row.created_at,
            })),
          },
          { headers: { 'Cache-Control': 'private, no-store' } }
        );
      }
    } catch {}
  }

  const storeOrders = Array.from(platformStore.counterOrders.values())
    .filter((o) => o.provider_id === providerId && (!slotFilter || slotFilter === 'ALL' || o.slot === slotFilter))
    .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

  return NextResponse.json(
    { success: true, orders: storeOrders },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = String(body.provider_id || body.providerId || '').trim();
  const customerName = String(body.customer_name || body.customerName || '').trim().slice(0, 80);
  const customerPhone = String(body.customer_phone || body.customerPhone || '').trim().slice(0, 20);
  const slot = String(body.slot || 'LUNCH').trim().toUpperCase().slice(0, 20);
  const itemsSummary = String(body.items_summary || body.itemsSummary || 'Daily Meal').trim().slice(0, 240);
  const paymentModeRaw = String(body.payment_mode || 'counter_cash').trim().toLowerCase();
  const paymentMode = ['counter_cash', 'counter_upi', 'online'].includes(paymentModeRaw)
    ? paymentModeRaw
    : 'counter_cash';

  const amountPaise =
    body.amount_paise !== undefined
      ? Math.round(Number(body.amount_paise))
      : Math.round(Number(body.amount_inr ?? body.amount ?? 0) * 100);

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }
  if (!customerName || customerName.length < 2) {
    return NextResponse.json({ success: false, error: 'Customer name is required.' }, { status: 400 });
  }
  if (!Number.isFinite(amountPaise) || amountPaise < 0 || amountPaise > 1_000_000) {
    return NextResponse.json({ success: false, error: 'Enter a valid order amount.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const nowIso = new Date().toISOString();
  const admin = getAdminClient();
  if (admin && UUID_RE.test(providerId)) {
    try {
      const { data, error } = await admin
        .from('counter_orders')
        .insert({
          provider_id: providerId,
          customer_name: customerName,
          customer_phone: customerPhone || null,
          slot,
          items_summary: itemsSummary || 'Daily Meal',
          amount_paise: amountPaise,
          payment_mode: paymentMode,
          status: 'completed',
          recorded_by: UUID_RE.test(access.userId) ? access.userId : null,
        })
        .select('*')
        .single();

      if (!error && data) {
        return NextResponse.json(
          {
            success: true,
            order: {
              ...data,
              amount_inr: Math.round(Number(data.amount_paise || 0) / 100),
            },
            message: 'Walk-in counter order recorded.',
          },
          { status: 201 }
        );
      }
    } catch {}
  }

  const fallbackOrder = {
    id: `cord-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
    provider_id: providerId,
    customer_name: customerName,
    customer_phone: customerPhone,
    slot,
    items_summary: itemsSummary || 'Daily Meal',
    amount_paise: amountPaise,
    amount_inr: Math.round(amountPaise / 100),
    payment_mode: paymentMode,
    status: 'completed',
    created_at: nowIso,
  };
  platformStore.counterOrders.set(fallbackOrder.id, fallbackOrder);

  return NextResponse.json(
    { success: true, order: fallbackOrder, message: 'Walk-in counter order recorded.' },
    { status: 201 }
  );
}
