import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { getIndiaDateString } from '@/lib/crypto';

export const dynamic = 'force-dynamic';

async function getClientSafe() {
  const db = getAdminClient();
  if (db) return db;
  try {
    return await createClient();
  } catch {
    return null;
  }
}

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || '';
  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const client = await getClientSafe();
  if (!client) {
    return NextResponse.json({ success: true, total: 0, redemptions: [] });
  }

  try {
    const { data, error } = await client
      .from('meal_redemptions')
      .select('id,customer_id,provider_id,subscription_id,meal_slot_id,confirmation_method,redeemed_at,profiles:customer_id(display_name,phone_e164),meal_slots:meal_slot_id(name)')
      .eq('provider_id', access.providerId)
      .order('redeemed_at', { ascending: false })
      .limit(500);

    if (error) {
      console.error('Provider redemption query error:', error.message);
      return NextResponse.json({ success: true, total: 0, redemptions: [] });
    }

    const redemptions = (data ?? []).map((row: any) => {
      const prof = Array.isArray(row.profiles) ? row.profiles[0] : row.profiles;
      const slotRow = Array.isArray(row.meal_slots) ? row.meal_slots[0] : row.meal_slots;
      return {
        id: row.id,
        user_id: row.customer_id,
        customer_name: prof?.display_name || 'Subscriber',
        customer_phone: prof?.phone_e164 || '',
        provider_id: row.provider_id,
        subscription_id: row.subscription_id,
        date: row.redeemed_at ? getIndiaDateString(new Date(row.redeemed_at)) : '',
        slot: String(slotRow?.name || 'Meal').toUpperCase(),
        confirmation_method: row.confirmation_method || 'qr_scan',
        redeemed_at: row.redeemed_at,
      };
    });

    return NextResponse.json({
      success: true,
      total: redemptions.length,
      redemptions,
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (err: any) {
    return NextResponse.json({ success: true, total: 0, redemptions: [] });
  }
}
