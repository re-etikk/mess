import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { sanitizePostgrestSearch } from '@/lib/auth-session';
import { platformStore } from '@/lib/platform-service';
import { evaluatePromoCode } from '@/lib/promo-engine';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const rawProviderId = searchParams.get('provider_id')?.trim() || '';
  const providerId = /^[0-9a-f-]{36}$/i.test(rawProviderId) ? rawProviderId : sanitizePostgrestSearch(rawProviderId);
  const orderContext = searchParams.get('order_context')?.trim().toLowerCase();
  const admin = getAdminClient();
  const promos: any[] = [];
  const now = Date.now();

  if (admin) {
    try {
      let query = admin
        .from('promo_codes')
        .select('*')
        .eq('is_active', true)
        .order('created_at', { ascending: false });
      if (providerId) {
        query = query.or(`provider_id.is.null,provider_id.eq.${providerId}`);
      } else {
        query = query.is('provider_id', null);
      }
      const { data } = await query;
      for (const row of data ?? []) {
        if (row.show_in_app === false) continue;
        if (row.valid_from && new Date(row.valid_from).getTime() > now) continue;
        if (row.valid_until && new Date(row.valid_until).getTime() < now) continue;
        if (row.usage_limit && Number(row.times_used || 0) >= Number(row.usage_limit)) continue;
        if (orderContext === 'plan' && row.applicable_to_plans === false) continue;
        if (orderContext === 'daily' && row.applicable_to_daily === false) continue;
        promos.push(row);
      }
    } catch {}
  }

  if (promos.length === 0) {
    for (const p of platformStore.promos.values()) {
      if (!p.is_active) continue;
      if (p.provider_id && (!providerId || p.provider_id !== providerId)) continue;
      promos.push(p);
    }
  }

  return NextResponse.json({ success: true, promos }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const code = String(body.code || '').trim().toUpperCase();
  const providerId = body.provider_id ? String(body.provider_id).trim() : undefined;
  const customerId = body.customer_id ? String(body.customer_id).trim() : undefined;
  const orderContext = body.order_context === 'daily' || body.order_context === 'plan' ? body.order_context : undefined;
  const orderAmountPaise = Number(
    body.order_amount_paise ?? (body.order_amount_inr ? Math.round(Number(body.order_amount_inr) * 100) : 0)
  );

  const admin = getAdminClient();
  const res = await evaluatePromoCode({
    admin,
    code,
    providerId,
    customerId,
    orderContext,
    orderAmountPaise,
  });

  return NextResponse.json(
    {
      isValid: res.isValid,
      code: res.code,
      title: res.title,
      discount_paise: res.discountPaise,
      discount_inr: Math.round(res.discountPaise / 100),
      final_amount_paise: res.finalAmountPaise,
      final_amount_inr: Math.round(res.finalAmountPaise / 100),
      message: res.message,
    },
    { status: res.isValid ? 200 : 400 }
  );
}
