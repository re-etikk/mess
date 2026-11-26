import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { getIndiaDateString } from '@/lib/crypto';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  const providerId = new URL(req.url).searchParams.get('provider_id')?.trim() || '';
  const targetId = (params.id || '').trim();

  if (!providerId || !targetId) {
    return NextResponse.json({ success: false, error: 'provider_id and subscriber id are required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  if (admin) {
    try {
      const isUuid = /^[0-9a-f-]{36}$/i.test(targetId);
      let q = admin
        .from('meal_redemptions')
        .select('id,customer_id,subscription_id,meal_slot_id,confirmation_method,redeemed_at,meal_slots:meal_slot_id(name)')
        .eq('provider_id', providerId)
        .order('redeemed_at', { ascending: false })
        .limit(100);

      if (isUuid) {
        q = q.or(`subscription_id.eq.${targetId},customer_id.eq.${targetId}`);
      } else {
        q = q.eq('subscription_id', targetId);
      }

      const { data, error } = await q;
      if (!error) {
        const history = (data ?? []).map((row: any) => {
          const slotRow = Array.isArray(row.meal_slots) ? row.meal_slots[0] : row.meal_slots;
          const dt = row.redeemed_at ? new Date(row.redeemed_at) : null;
          return {
            id: row.id,
            subscription_id: row.subscription_id,
            customer_id: row.customer_id,
            slot: String(slotRow?.name || 'MEAL').toUpperCase(),
            date: dt ? getIndiaDateString(dt) : '',
            time_formatted: dt
              ? new Intl.DateTimeFormat('en-IN', { timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit' }).format(dt)
              : '',
            redeemed_at: row.redeemed_at,
            confirmation_method: row.confirmation_method || 'qr_scan',
          };
        });
        return NextResponse.json({ success: true, history }, { headers: { 'Cache-Control': 'private, no-store' } });
      }
    } catch (e: any) {
      console.warn('Subscriber history query error:', e?.message);
    }
  }

  const memHistory = Array.from(platformStore.redemptions.values())
    .filter((r) => r.provider_id === providerId && (r.subscription_id === targetId || r.user_id === targetId))
    .map((r) => ({
      id: r.id,
      subscription_id: r.subscription_id,
      customer_id: r.user_id,
      slot: r.slot,
      date: r.date,
      time_formatted: r.redeemed_at
        ? new Intl.DateTimeFormat('en-IN', { timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit' }).format(new Date(r.redeemed_at))
        : '',
      redeemed_at: r.redeemed_at,
      confirmation_method: 'qr_scan',
    }));

  return NextResponse.json({ success: true, history: memHistory }, { headers: { 'Cache-Control': 'private, no-store' } });
}
