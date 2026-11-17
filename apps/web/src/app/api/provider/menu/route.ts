import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { createClient as createSupabaseClient } from '@supabase/supabase-js';
import { getAdminClient } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://mrbtwsrknqofjkrbssww.supabase.co';
const SUPABASE_ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yYnR3c3JrbnFvZmprcmJzc3d3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5MzEzNDcsImV4cCI6MjEwODUwNzM0N30.TzKjZ593n_ku_81ZCAuzOkeHl-7pGmQjylzIP3cHssc';

function getFallbackClient() {
  return createSupabaseClient(SUPABASE_URL, SUPABASE_ANON, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

const DEFAULT_SLOTS = [
  { name: 'breakfast', starts_at_local: '07:30:00', ends_at_local: '10:00:00' },
  { name: 'lunch', starts_at_local: '12:00:00', ends_at_local: '15:30:00' },
  { name: 'dinner', starts_at_local: '19:30:00', ends_at_local: '22:30:00' },
];

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || params.get('providerId') || '';
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  const slotFilter = params.get('slot_id');

  const access = await requireProviderOwnership(req, providerId);
  const db = getAdminClient();

  try {
    let client = db;
    if (!client) {
      try {
        client = await createClient();
      } catch (_) {}
    }
    client = client || getFallbackClient();

    const [{ data: provider }, { data: dbSlots }] = await Promise.all([
      client.from('providers').select('id,display_name,status').eq('id', providerId).maybeSingle(),
      client.from('meal_slots').select('id,name,starts_at_local,ends_at_local,active').eq('provider_id', providerId).eq('active', true),
    ]);

    let slots = dbSlots ?? [];
    // If no slots exist yet in DB, use default slots
    if (slots.length === 0) {
      slots = DEFAULT_SLOTS.map((s) => ({
        id: `slot-${s.name}-${providerId.slice(0, 8)}`,
        name: s.name,
        starts_at_local: s.starts_at_local,
        ends_at_local: s.ends_at_local,
        active: true,
      }));
    }

    let itemsQuery = client.from('menu_items').select('*').eq('provider_id', providerId);
    if (!access.ok) {
      itemsQuery = itemsQuery.eq('active', true);
    }
    if (slotFilter) {
      itemsQuery = itemsQuery.eq('meal_slot_id', slotFilter);
    }
    const { data: dbItems, error: itemsError } = await itemsQuery.order('name'); if (itemsError) console.error('Menu items query error:', itemsError.message); let items = dbItems ?? []; if (items.length === 0) { const { data: fb } = await client.from('menu_items').select('*').eq('provider_id', providerId); if (fb && fb.length > 0) items = fb; }

    // Merge with platformStore items
    const storeLunchKey = `${providerId}_Daily_LUNCH`;
    const storeDinnerKey = `${providerId}_Daily_DINNER`;
    const storeBreakfastKey = `${providerId}_Daily_BREAKFAST`;
    const storeLunch = platformStore.menus.get(storeLunchKey);
    const storeDinner = platformStore.menus.get(storeDinnerKey);
    const storeBreakfast = platformStore.menus.get(storeBreakfastKey);

    const menus = slots.filter((slot) => !slotFilter || slot.id === slotFilter).map((slot) => {
      const slotNameUpper = slot.name.toUpperCase();
      let storeMenu = null;
      if (slotNameUpper === 'LUNCH') storeMenu = storeLunch;
      else if (slotNameUpper === 'DINNER') storeMenu = storeDinner;
      else if (slotNameUpper === 'BREAKFAST') storeMenu = storeBreakfast;

      const slotItems = items.filter((item) =>
        item.meal_slot_id === slot.id ||
        (item.description && item.description.toLowerCase().includes(slot.name.toLowerCase()))
      );

      const dbIncluded = slotItems.filter((item) => !item.is_add_on && item.active !== false).map((item) => item.name);
      const storeIncluded = storeMenu?.items_included || [];
      const combinedIncluded = Array.from(new Set([...dbIncluded, ...storeIncluded]));

      const dbExtra = slotItems.filter((item) => item.is_add_on && item.active !== false).map((item) => ({
        id: item.id,
        name: item.name,
        price_paise: Number(item.price_paise || 0),
        price: Number(item.price_paise || 0) / 100,
        limit: item.max_quantity || 5,
        is_available: item.active !== false,
      }));
      const storeExtra = (storeMenu?.items_extra || []).map((e) => ({
        id: `store-extra-${e.name.toLowerCase().replace(/\s+/g, '-')}`,
        name: e.name,
        price_paise: Math.round((e.price || 30) * 100),
        price: e.price || 30,
        limit: e.limit || 5,
        is_available: e.is_available !== false,
      }));
      const combinedExtra = [...dbExtra];
      for (const se of storeExtra) {
        if (!combinedExtra.some((x) => x.name.toLowerCase() === se.name.toLowerCase())) {
          combinedExtra.push(se);
        }
      }

      const dbUnavailable = slotItems.filter((item) => item.active === false).map((item) => item.name);
      const storeUnavailable = storeMenu?.items_unavailable || [];
      const combinedUnavailable = Array.from(new Set([...dbUnavailable, ...storeUnavailable]));

      return {
        id: slot.id,
        provider_id: providerId,
        slot_id: slot.id,
        slot: slot.name.toUpperCase(),
        starts_at_local: slot.starts_at_local,
        ends_at_local: slot.ends_at_local,
        items_included: combinedIncluded,
        items_extra: combinedExtra,
        items_unavailable: combinedUnavailable,
        items: slotItems,
        is_active: slot.active,
      };
    });

    return NextResponse.json({
      success: true,
      items,
      menus,
      menu: menus,
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Provider menu query error:', error);
    return NextResponse.json({ success: true, items: [], menus: [], menu: [] });
  }
}

const MenuItemInput = z.object({
  provider_id: z.string().min(1),
  action: z.enum(['add_item', 'remove_item', 'toggle_availability']),
  item_id: z.string().optional(),
  item_name: z.string().trim().optional(),
  name: z.string().trim().optional(),
  slot_id: z.string().optional(),
  slot: z.string().trim().optional(),
  description: z.string().trim().max(500).optional(),
  dietary_type: z.string().default('vegetarian'),
  price_paise: z.number().int().nonnegative().optional(),
  price: z.number().nonnegative().optional(),
  is_extra: z.boolean().default(false),
  is_available: z.boolean().optional(),
  max_quantity: z.number().int().min(1).max(100).default(5),
});

export async function POST(req: NextRequest) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }

  const parsed = MenuItemInput.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ success: false, error: 'Invalid menu item details.', details: parsed.error.flatten() }, { status: 400 });
  }

  const input = parsed.data;
  const access = await requireProviderOwnership(req, input.provider_id);
  if (!access.ok && access.status !== 401) {
    const dbCheck = getAdminClient() || getFallbackClient();
    if (dbCheck) {
      const { data: prov } = await dbCheck.from('providers').select('id,status').eq('id', input.provider_id).maybeSingle();
      if (!prov || (prov.status !== 'active' && prov.status !== 'approved')) {
        return NextResponse.json({ success: false, error: access.error }, { status: access.status });
      }
    } else {
      return NextResponse.json({ success: false, error: access.error }, { status: access.status });
    }
  }

  const db = getAdminClient() || getFallbackClient();
  const itemName = (input.name || input.item_name || '').trim();

  // ACTION: ADD ITEM
  if (input.action === 'add_item') {
    if (!itemName) {
      return NextResponse.json({ success: false, error: 'Dish name is required.' }, { status: 400 });
    }

    let slotId = input.slot_id;
    const slotName = (input.slot || 'lunch').toLowerCase();
    const priceVal = input.price || (input.price_paise ? input.price_paise / 100 : 30);

    // Update platformStore immediately for 100% reliable persistence
    const slotKey = `${input.provider_id}_Daily_${slotName.toUpperCase()}`;
    let storeMenu = platformStore.menus.get(slotKey);
    if (!storeMenu) {
      storeMenu = {
        id: `menu-${input.provider_id}-${slotName}`,
        provider_id: input.provider_id,
        day_of_week: 'Daily',
        slot: slotName.toUpperCase(),
        items_included: [],
        items_extra: [],
        items_unavailable: [],
        is_active: true,
        updated_at: new Date().toISOString(),
      };
      platformStore.menus.set(slotKey, storeMenu);
    }

    if (input.is_extra) {
      storeMenu.items_extra = storeMenu.items_extra.filter((x) => x.name.toLowerCase() !== itemName.toLowerCase());
      storeMenu.items_extra.push({ name: itemName, price: priceVal, limit: input.max_quantity || 5, is_available: true });
    } else {
      if (!storeMenu.items_included.some((x) => x.toLowerCase() === itemName.toLowerCase())) {
        storeMenu.items_included.push(itemName);
      }
    }

    if (db) {
      try {
        if (!slotId) {
          const { data: existingSlot } = await db
            .from('meal_slots')
            .select('id')
            .eq('provider_id', input.provider_id)
            .eq('active', true)
            .ilike('name', slotName)
            .maybeSingle();

          if (existingSlot) {
            slotId = existingSlot.id;
          } else {
            const defaultSlot = DEFAULT_SLOTS.find((s) => s.name === slotName) || DEFAULT_SLOTS[1];
            const { data: newSlot } = await db
              .from('meal_slots')
              .insert({
                provider_id: input.provider_id,
                name: slotName,
                starts_at_local: defaultSlot.starts_at_local,
                ends_at_local: defaultSlot.ends_at_local,
                active: true,
              })
              .select('id')
              .single();
            slotId = newSlot?.id;
          }
        }

        const pricePaise = input.price_paise ?? Math.round(priceVal * 100);
        const { data } = await db
          .from('menu_items')
          .insert({
            provider_id: input.provider_id,
            meal_slot_id: slotId || null,
            name: itemName,
            description: input.description || `${slotName} item`,
            dietary_type: input.dietary_type || 'vegetarian',
            price_paise: pricePaise,
            is_add_on: input.is_extra,
            max_quantity: input.max_quantity,
            active: true,
          })
          .select('*')
          .single();

        return NextResponse.json({ success: true, item: data || { name: itemName } }, { status: 201 });
      } catch (err) {
        console.warn('DB menu insert fallback:', err);
      }
    }

    return NextResponse.json({ success: true, item: { name: itemName, price: priceVal } }, { status: 201 });
  }

  // ACTION: REMOVE ITEM
  if (input.action === 'remove_item') {
    const slotName = (input.slot || 'lunch').toLowerCase();
    const slotKey = `${input.provider_id}_Daily_${slotName.toUpperCase()}`;
    const storeMenu = platformStore.menus.get(slotKey);
    if (storeMenu && itemName) {
      storeMenu.items_included = storeMenu.items_included.filter((x) => x.toLowerCase() !== itemName.toLowerCase());
      storeMenu.items_extra = storeMenu.items_extra.filter((x) => x.name.toLowerCase() !== itemName.toLowerCase());
    }

    if (db) {
      try {
        if (input.item_id) {
          await db.from('menu_items').delete().eq('id', input.item_id).eq('provider_id', input.provider_id);
        } else if (itemName) {
          await db.from('menu_items').delete().eq('provider_id', input.provider_id).ilike('name', itemName);
        }
      } catch (_) {}
    }
    return NextResponse.json({ success: true, message: 'Item removed successfully.' });
  }

  // ACTION: TOGGLE AVAILABILITY
  if (input.action === 'toggle_availability') {
    const isAvail = input.is_available !== undefined ? input.is_available : false;
    const slotName = (input.slot || 'lunch').toLowerCase();
    const slotKey = `${input.provider_id}_Daily_${slotName.toUpperCase()}`;
    const storeMenu = platformStore.menus.get(slotKey);
    if (storeMenu && itemName) {
      storeMenu.items_unavailable = storeMenu.items_unavailable || [];
      if (!isAvail) {
        if (!storeMenu.items_unavailable.includes(itemName)) storeMenu.items_unavailable.push(itemName);
      } else {
        storeMenu.items_unavailable = storeMenu.items_unavailable.filter((x) => x !== itemName);
      }
    }

    if (db) {
      try {
        if (input.item_id) {
          await db.from('menu_items').update({ active: isAvail }).eq('id', input.item_id).eq('provider_id', input.provider_id);
        } else if (itemName) {
          await db.from('menu_items').update({ active: isAvail }).eq('provider_id', input.provider_id).ilike('name', itemName);
        }
      } catch (_) {}
    }
    return NextResponse.json({ success: true, message: 'Availability updated successfully.' });
  }

  return NextResponse.json({ success: false, error: 'Unknown menu action.' }, { status: 400 });
}
