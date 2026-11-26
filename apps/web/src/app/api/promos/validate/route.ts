import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { sanitizePostgrestSearch } from '@/lib/auth-session';
import { platformStore, validateAndApplyPromo } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const rawProviderId = new URL(req.url).searchParams.get('provider_id')?.trim() || '';
  const providerId = /^[0-9a-f-]{36}$/i.test(rawProviderId) ? rawProviderId : sanitizePostgrestSearch(rawProviderId);
  const admin = getAdminClient();
  const promos: any[] = [];

  if (admin) {
    try {
      let query = admin.from('promo_codes').select('*').eq('is_active', true).order('created_at', { ascending: false });
      if (providerId) {
        query = query.or(`provider_id.is.null,provider_id.eq.${providerId}`);
      }
      const { data } = await query;
      if (data && data.length > 0) {
        promos.push(...data);
      }
    } catch {}
  }

  if (promos.length === 0) {
    for (const p of platformStore.promos.values()) {
      if (p.is_active) {
        promos.push(p);
      }
    }
  }

  return NextResponse.json({ success: true, promos }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const code = String(body.code || '').trim().toUpperCase();
  const providerId = body.provider_id ? String(body.provider_id).trim() : undefined;
  const orderAmountPaise = Number(body.order_amount_paise ?? (body.order_amount_inr ? Math.round(Number(body.order_amount_inr) * 100) : 0));

  if (!code) {
    return NextResponse.json({ isValid: false, message: 'Promo code is required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  if (admin) {
    try {
      const { data: promo } = await admin
        .from('promo_codes')
        .select('*')
        .eq('code', code)
        .eq('is_active', true)
        .maybeSingle();

      if (promo) {
        if (promo.provider_id && providerId && promo.provider_id !== providerId) {
          return NextResponse.json({ isValid: false, message: 'Promo code is valid for another mess only.' }, { status: 400 });
        }
        const now = Date.now();
        if (promo.valid_until && new Date(promo.valid_until).getTime() < now) {
          return NextResponse.json({ isValid: false, message: 'This promo code has expired.' }, { status: 400 });
        }
        if (promo.usage_limit && promo.times_used >= promo.usage_limit) {
          return NextResponse.json({ isValid: false, message: 'Promo code usage limit reached.' }, { status: 400 });
        }
        if (orderAmountPaise < Number(promo.min_order_paise || 0)) {
          const minInr = Math.round(Number(promo.min_order_paise || 0) / 100);
          return NextResponse.json({ isValid: false, message: `Minimum order amount ₹${minInr} required.` }, { status: 400 });
        }

        let discountPaise = 0;
        if (promo.discount_percent) {
          discountPaise = Math.round((orderAmountPaise * Number(promo.discount_percent)) / 100);
          if (promo.max_discount_paise && discountPaise > Number(promo.max_discount_paise)) {
            discountPaise = Number(promo.max_discount_paise);
          }
        } else if (promo.flat_discount_paise) {
          discountPaise = Number(promo.flat_discount_paise);
        }
        discountPaise = Math.min(discountPaise, orderAmountPaise);
        const finalAmountPaise = Math.max(0, orderAmountPaise - discountPaise);

        return NextResponse.json({
          isValid: true,
          code: promo.code,
          title: promo.title,
          discount_paise: discountPaise,
          discount_inr: Math.round(discountPaise / 100),
          final_amount_paise: finalAmountPaise,
          final_amount_inr: Math.round(finalAmountPaise / 100),
          message: `Saved ₹${Math.round(discountPaise / 100)} with ${promo.code}!`,
        });
      }
    } catch {}
  }

  const res = validateAndApplyPromo({ code, orderAmountPaise });
  return NextResponse.json(
    {
      isValid: res.isValid,
      code: res.code,
      discount_paise: res.discountPaise,
      discount_inr: Math.round(res.discountPaise / 100),
      final_amount_paise: res.finalAmountPaise,
      final_amount_inr: Math.round(res.finalAmountPaise / 100),
      message: res.message,
    },
    { status: res.isValid ? 200 : 400 }
  );
}
