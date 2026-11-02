import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

function getClientSafe() {
  const db = getAdminClient();
  if (db) return db;
  try {
    return createClient();
  } catch {
    return null;
  }
}

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || '';
  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const client = getClientSafe();
  if (!client) {
    return NextResponse.json({ success: true, total: 0, redemptions: [] });
  }

  try {
    let query = client
      .from('meal_redemptions')
      .select('id,customer_id,provider_id,subscription_id,confirmation_method,redeemed_at')
      .eq('provider_id', providerId)
      .order('redeemed_at', { ascending: false })
      .limit(500);

    const { data, error } = await query;
    if (error) {
      console.error('Provider redemption query error:', error.message);
      return NextResponse.json({ success: true, total: 0, redemptions: [] });
    }

    const redemptions = (data ?? []).map((row: any) => ({
      id: row.id,
      user_id: row.customer_id,
      customer_name: 'Member',
      customer_phone: '',
      provider_id: row.provider_id,
      subscription_id: row.subscription_id,
      date: row.redeemed_at ? row.redeemed_at.split('T')[0] : '',
      slot: 'Meal',
      confirmation_method: row.confirmation_method || 'qr_scan',
      redeemed_at: row.redeemed_at,
    }));

    return NextResponse.json({
      success: true,
      total: redemptions.length,
      redemptions,
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (err: any) {
    return NextResponse.json({ success: true, total: 0, redemptions: [] });
  }
}
