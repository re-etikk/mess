import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  const db = getAdminClient();
  if (!db) return NextResponse.json({ success: false, error: 'Provider data is not configured.' }, { status: 503 });
  const slot = new URL(req.url).searchParams.get('slot');
  const { data: provider, error: providerError } = await db.from('providers').select('id,display_name,address,phone,status').eq('id', params.id).eq('status', 'active').maybeSingle();
  if (providerError) return NextResponse.json({ success: false, error: 'Provider details are unavailable.' }, { status: 503 });
  if (!provider) return NextResponse.json({ success: false, error: 'Active provider not found.' }, { status: 404 });
  let slotId: string | null = null;
  if (slot) {
    const { data, error } = await db.from('meal_slots').select('id,name').eq('provider_id', provider.id).eq('active', true).ilike('name', slot).maybeSingle();
    if (error) return NextResponse.json({ success: false, error: 'Meal slots are unavailable.' }, { status: 503 });
    slotId = data?.id ?? null;
  }
  const { data: items, error: menuError } = await db.from('menu_items').select('id,name,description,category,dietary_type,price_paise,active,available_from,available_until').eq('provider_id', provider.id).eq('active', true).order('name');
  if (menuError) return NextResponse.json({ success: false, error: 'Menu is unavailable.' }, { status: 503 });
  return NextResponse.json({ success: true, provider: { id: provider.id, name: provider.display_name, address: provider.address, phone: provider.phone }, slot: slot || null, meal_slot_id: slotId, menu: { items_included: items.filter((item) => Number(item.price_paise) === 0), items_extra: items.filter((item) => Number(item.price_paise) > 0), items } }, { headers: { 'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=120' } });
}
