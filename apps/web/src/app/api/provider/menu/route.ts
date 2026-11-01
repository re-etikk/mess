import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || params.get('providerId') || '';
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  const slotFilter = params.get('slot_id');
  const access = await requireProviderOwnership(req, providerId);
  const db = access.ok ? getAdminClient() : null;

  try {
    const client = db || await createClient();
    const [{ data: provider, error: providerError }, { data: slots, error: slotsError }] = await Promise.all([
      client.from('providers').select('id,status').eq('id', providerId).maybeSingle(),
      client.from('meal_slots').select('id,name,starts_at_local,ends_at_local,active').eq('provider_id', providerId).eq('active', true),
    ]);
    if (providerError || slotsError) throw providerError || slotsError;
    if (!provider || (!access.ok && provider.status !== 'active')) return NextResponse.json({ success: false, error: 'Provider not found.' }, { status: 404 });

    let itemsQuery = client.from('menu_items').select('id,provider_id,meal_slot_id,name,description,category,dietary_type,price_paise,is_add_on,max_quantity,active,available_from,available_until,updated_at')
      .eq('provider_id', providerId).eq('active', true).order('name');
    if (slotFilter) itemsQuery = itemsQuery.eq('meal_slot_id', slotFilter);
    const { data: items, error: itemsError } = await itemsQuery;
    if (itemsError) throw itemsError;

    const menus = (slots ?? []).filter((slot) => !slotFilter || slot.id === slotFilter).map((slot) => {
      const slotItems = (items ?? []).filter((item) => item.meal_slot_id === slot.id);
      return {
        id: slot.id,
        provider_id: providerId,
        slot_id: slot.id,
        slot: slot.name,
        starts_at_local: slot.starts_at_local,
        ends_at_local: slot.ends_at_local,
        items_included: slotItems.filter((item) => !item.is_add_on).map((item) => item.name),
        items_extra: slotItems.filter((item) => item.is_add_on).map((item) => ({ id: item.id, name: item.name, price_paise: Number(item.price_paise), price: Number(item.price_paise) / 100, limit: item.max_quantity, is_available: item.active })),
        items: slotItems,
        is_active: true,
      };
    });
    return NextResponse.json({ success: true, items: items ?? [], menus }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Provider menu query failed:', error instanceof Error ? error.message : 'unknown error');
    return NextResponse.json({ success: false, error: 'Menu could not be loaded. Verify that the menu-slot migration is applied.' }, { status: 503 });
  }
}

const MenuItemInput = z.object({
  provider_id: z.string().uuid(),
  action: z.enum(['add_item', 'remove_item', 'toggle_availability']),
  item_id: z.string().uuid().optional(),
  item_name: z.string().trim().min(1).max(120).optional(),
  name: z.string().trim().min(1).max(120).optional(),
  slot_id: z.string().uuid().optional(),
  slot: z.string().trim().min(1).max(40).optional(),
  description: z.string().trim().max(500).optional(),
  dietary_type: z.enum(['vegetarian', 'vegan', 'non_vegetarian', 'jain', 'unspecified']).default('unspecified'),
  price_paise: z.number().int().nonnegative().optional(),
  price: z.number().nonnegative().optional(),
  is_extra: z.boolean().default(false),
  max_quantity: z.number().int().min(1).max(100).default(5),
});

export async function POST(req: NextRequest) {
  let body: unknown;
  try { body = await req.json(); } catch { return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 }); }
  const parsed = MenuItemInput.safeParse(body);
  if (!parsed.success) return NextResponse.json({ success: false, error: 'Invalid menu item details.', details: parsed.error.flatten() }, { status: 400 });
  const input = parsed.data;
  const access = await requireProviderOwnership(req, input.provider_id);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  const db = getAdminClient();
  if (!db) return NextResponse.json({ success: false, error: 'Menu data service is not configured.' }, { status: 503 });

  if (input.action === 'add_item') {
    const name = input.name || input.item_name;
    if (!name) return NextResponse.json({ success: false, error: 'Dish name is required.' }, { status: 400 });
    let slotId = input.slot_id;
    if (!slotId && input.slot) {
      const { data: slot, error } = await db.from('meal_slots').select('id').eq('provider_id', input.provider_id).eq('active', true).ilike('name', input.slot).maybeSingle();
      if (error) return NextResponse.json({ success: false, error: 'Meal slot could not be verified.' }, { status: 503 });
      slotId = slot?.id;
    }
    if (!slotId) return NextResponse.json({ success: false, error: 'Choose a configured meal slot.' }, { status: 400 });
    const { data: slot, error: slotError } = await db.from('meal_slots').select('id').eq('id', slotId).eq('provider_id', input.provider_id).eq('active', true).maybeSingle();
    if (slotError || !slot) return NextResponse.json({ success: false, error: 'Meal slot does not belong to this provider.' }, { status: 400 });
    const pricePaise = input.price_paise ?? Math.round((input.price || 0) * 100);
    if (!input.is_extra && pricePaise !== 0) return NextResponse.json({ success: false, error: 'Included dishes must have a zero price; mark paid extras as add-ons.' }, { status: 400 });
    if (input.is_extra && pricePaise <= 0) return NextResponse.json({ success: false, error: 'A paid add-on needs a price greater than zero.' }, { status: 400 });
    const { data, error } = await db.from('menu_items').insert({
      provider_id: input.provider_id,
      meal_slot_id: slotId,
      name,
      description: input.description || null,
      category: null,
      dietary_type: input.dietary_type,
      price_paise: pricePaise,
      is_add_on: input.is_extra,
      max_quantity: input.max_quantity,
      active: true,
    }).select('id,provider_id,meal_slot_id,name,description,dietary_type,price_paise,is_add_on,max_quantity,active').single();
    if (error) {
      console.error('Menu item insert failed:', error.message);
      return NextResponse.json({ success: false, error: 'Dish could not be saved. Verify the menu-slot migration is applied.' }, { status: 503 });
    }
    return NextResponse.json({ success: true, item: data }, { status: 201 });
  }

  if (!input.item_id) return NextResponse.json({ success: false, error: 'item_id is required.' }, { status: 400 });
  const update = input.action === 'remove_item' ? { active: false } : { active: false };
  if (input.action === 'toggle_availability') {
    const { data: existing, error: lookupError } = await db.from('menu_items').select('active').eq('id', input.item_id).eq('provider_id', input.provider_id).maybeSingle();
    if (lookupError || !existing) return NextResponse.json({ success: false, error: 'Menu item not found.' }, { status: 404 });
    const { data, error } = await db.from('menu_items').update({ active: !existing.active }).eq('id', input.item_id).eq('provider_id', input.provider_id).select('id,active').single();
    if (error) return NextResponse.json({ success: false, error: 'Availability could not be updated.' }, { status: 503 });
    return NextResponse.json({ success: true, item: data });
  }
  const { error } = await db.from('menu_items').update(update).eq('id', input.item_id).eq('provider_id', input.provider_id);
  if (error) return NextResponse.json({ success: false, error: 'Menu item could not be removed.' }, { status: 503 });
  return NextResponse.json({ success: true });
}
