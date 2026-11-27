import { NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { getIstWeekday, isKitchenOpenFromRecord, isUndefinedColumnError } from '@/lib/kitchen-status';

export const dynamic = 'force-dynamic';
export const fetchCache = 'force-no-store';

export async function GET() {
  try {
    const client = getAdminClient() || (await createClient());
    const primaryRes = await client
      .from('providers')
      .select('id,display_name,slug,description,logo_path,cover_path,public_phone,public_email,address_line1,locality,city,state,pincode,supports_pickup,status,is_accepting_orders')
      .eq('status', 'active')
      .order('display_name', { ascending: true });

    let data: any[] | null = primaryRes.data as any[] | null;
    let error = primaryRes.error;
    if (isUndefinedColumnError(error, 'is_accepting_orders')) {
      const fb = await client
        .from('providers')
        .select('id,display_name,slug,description,logo_path,cover_path,public_phone,public_email,address_line1,locality,city,state,pincode,supports_pickup,status')
        .eq('status', 'active')
        .order('display_name', { ascending: true });
      data = fb.data as any[] | null;
      error = fb.error;
    }
    if (error) throw error;

    const list = data ?? [];
    const ids = list.map((p) => p.id);
    const weekday = getIstWeekday();
    const { data: hours } = ids.length
      ? await client
          .from('provider_operating_hours')
          .select('provider_id,closed')
          .in('provider_id', ids)
          .eq('weekday', weekday)
      : { data: [] as any[] };

    const hoursByProvider = new Map((hours ?? []).map((h: any) => [h.provider_id, h]));

    return NextResponse.json(
      {
        providers: list.map((provider) => ({
          ...provider,
          is_open_today: isKitchenOpenFromRecord({
            status: provider.status,
            is_accepting_orders: provider.is_accepting_orders,
            todayHours: hoursByProvider.get(provider.id) ?? null,
          }),
        })),
      },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  } catch (error) {
    console.error('Public provider listing failed:', error instanceof Error ? error.message : 'unknown error');
    return NextResponse.json({ success: false, error: 'Listings are temporarily unavailable. Please retry.' }, { status: 503 });
  }
}
