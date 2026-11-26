import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient, noStoreFetch } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { ensurePlanSlotsLinked, publicErrorMessage } from '@/lib/auth-session';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';
export const fetchCache = 'force-no-store';

const SLOT_ORDER: Record<string, number> = { breakfast: 1, lunch: 2, snacks: 3, dinner: 4 };

const DEFAULT_SLOTS = [
  { name: 'breakfast', starts_at_local: '07:30:00', ends_at_local: '10:00:00' },
  { name: 'lunch', starts_at_local: '12:00:00', ends_at_local: '15:30:00' },
  { name: 'snacks', starts_at_local: '16:30:00', ends_at_local: '18:30:00' },
  { name: 'dinner', starts_at_local: '19:30:00', ends_at_local: '22:30:00' },
];

async function getDbClient() {
  const admin = getAdminClient();
  if (admin) return admin;
  try {
    return await createClient();
  } catch {
    return null;
  }
}

void noStoreFetch;

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id') || params.get('providerId') || '';
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  const slotFilter = params.get('slot_id');

  const access = await requireProviderOwnership(req, providerId);

  try {
    const client = await getDbClient();
    if (!client) {
      return NextResponse.json({ success: true, items: [], menus: [], menu: [] }, { headers: { 'Cache-Control': 'private, no-store' } });
    }

    const [{ data: provider }, { data: dbSlots }] = await Promise.all([
      client.from('providers').select('id,display_name,status').eq('id', providerId).maybeSingle(),
      client.from('meal_slots').select('id,name,starts_at_local,ends_at_local,active').eq('provider_id', providerId).eq('active', true),
    ]);

    let slots = (dbSlots ?? []).filter((s) => String(s.name || '').trim().toLowerCase() !== 'all');
    // If no slots exist yet in DB, use default slots (breakfast, lunch, dinner)
    if (slots.length === 0) {
      slots = DEFAULT_SLOTS.filter((s) => s.name !== 'snacks').map((s) => ({
        id: `slot-${s.name}-${providerId.slice(0, 8)}`,
        name: s.name,
        starts_at_local: s.starts_at_local,
        ends_at_local: s.ends_at_local,
        active: true,
      }));
    } else {
      slots.sort((a, b) => (SLOT_ORDER[String(a.name).toLowerCase()] ?? 99) - (SLOT_ORDER[String(b.name).toLowerCase()] ?? 99));
    }

    let itemsQuery = client.from('menu_items').select('*').eq('provider_id', providerId);
    if (!access.ok) {
      itemsQuery = itemsQuery.eq('active', true);
    }
    if (slotFilter) {
      itemsQuery = itemsQuery.eq('meal_slot_id', slotFilter);
    }
    const { data: dbItems, error: itemsError } = await itemsQuery.order('name');
    if (itemsError) console.error('Menu items query error:', itemsError.message);
    let items = (dbItems ?? []).filter((item: any) => !item.name?.toLowerCase().includes('test'));
    if (items.length === 0) {
      const { data: fb } = await client.from('menu_items').select('*').eq('provider_id', providerId);
      if (fb && fb.length > 0) {
        items = fb.filter((item: any) => !item.name?.toLowerCase().includes('test'));
      }
    }

    const menus = slots.filter((slot) => !slotFilter || slot.id === slotFilter).map((slot) => {
      const slotNameUpper = slot.name.toUpperCase();
      const storeMenu = platformStore.menus.get(`${providerId}_Daily_${slotNameUpper}`);

      const slotItems = items.filter((item) =>
        item.meal_slot_id === slot.id ||
        (!item.meal_slot_id && item.description && item.description.toLowerCase().includes(slot.name.toLowerCase()))
      );

      const dbIncluded = slotItems
        .filter((item) => !item.is_add_on && item.active !== false && !item.name?.toLowerCase().includes('test'))
        .map((item) => item.name);
      const storeIncluded = (storeMenu?.items_included || []).filter((name: string) => !name.toLowerCase().includes('test'));
      const combinedIncluded = dbIncluded.length > 0 ? dbIncluded : storeIncluded;

      const dbExtra = slotItems
        .filter((item) => item.is_add_on && item.active !== false && !item.name?.toLowerCase().includes('test'))
        .map((item) => ({
          id: item.id,
          name: item.name,
          price_paise: Number(item.price_paise || 0),
          price: Number(item.price_paise || 0) / 100,
          limit: item.max_quantity || 5,
          is_available: item.active !== false,
        }));
      const storeExtra = (storeMenu?.items_extra || [])
        .filter((e: any) => !e.name.toLowerCase().includes('test'))
        .map((e: any) => ({
          id: `store-extra-${e.name.toLowerCase().replace(/\s+/g, '-')}`,
          name: e.name,
          price_paise: Math.round((e.price || 30) * 100),
          price: e.price || 30,
          limit: e.limit || 5,
          is_available: e.is_available !== false,
        }));
      const combinedExtra = storeExtra.length > 0 ? storeExtra : dbExtra;

      const dbUnavailable = slotItems.filter((item) => item.active === false).map((item) => item.name);
      const storeUnavailable = storeMenu?.items_unavailable || [];
      const combinedUnavailable = (storeUnavailable.length > 0 ? storeUnavailable : dbUnavailable).filter((name: string) => !name.toLowerCase().includes('test'));

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
  day_of_week: z.string().trim().default('Daily'),
  item_kind: z.enum(['included', 'addon', 'special']).optional(),
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
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const db = await getDbClient();
  const itemName = (input.name || input.item_name || '').trim();

  // ACTION: ADD ITEM
  if (input.action === 'add_item') {
    if (!itemName) {
      return NextResponse.json({ success: false, error: 'Dish name is required.' }, { status: 400 });
    }

    let slotId = input.slot_id;
    const slotName = (input.slot || 'lunch').trim().toLowerCase();
    if (slotName === 'all') {
      return NextResponse.json({ success: false, error: 'Choose Breakfast, Lunch, Snacks, or Dinner.' }, { status: 400 });
    }
    const dayOfWeek = input.day_of_week || 'Daily';
    const itemKind = input.item_kind || (input.is_extra ? 'addon' : 'included');
    const priceVal = input.price || (input.price_paise ? input.price_paise / 100 : 30);

    if (db) {
      try {
        if (!slotId) {
          const { data: existingSlot, error: slotLookupError } = await db
            .from('meal_slots')
            .select('id,active')
            .eq('provider_id', input.provider_id)
            .ilike('name', slotName)
            .limit(1)
            .maybeSingle();

          if (slotLookupError) {
            console.error('Meal slot lookup error:', slotLookupError.message);
            return NextResponse.json(
              { success: false, error: publicErrorMessage(slotLookupError, 'Could not load meal slot. Please try again.') },
              { status: 503 }
            );
          }

          if (existingSlot) {
            slotId = existingSlot.id;
            if (existingSlot.active === false) {
              await db.from('meal_slots').update({ active: true, updated_at: new Date().toISOString() }).eq('id', existingSlot.id);
            }
          } else {
            const defaultSlot = DEFAULT_SLOTS.find((s) => s.name === slotName) || DEFAULT_SLOTS[1];
            const { data: newSlot, error: slotCreateErr } = await db
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
            if (slotCreateErr || !newSlot) {
              console.error('Meal slot create error:', slotCreateErr?.message);
              return NextResponse.json(
                { success: false, error: publicErrorMessage(slotCreateErr, 'Could not create meal slot. Please try again.') },
                { status: 503 }
              );
            }
            slotId = newSlot.id;
          }
        }

        const pricePaise = input.price_paise ?? Math.round(priceVal * 100);
        const baseInsert = {
          provider_id: input.provider_id,
          meal_slot_id: slotId || null,
          name: itemName,
          description: input.description || `${slotName} item`,
          dietary_type: input.dietary_type || 'vegetarian',
          price_paise: pricePaise,
          is_add_on: input.is_extra,
          max_quantity: input.max_quantity,
          active: true,
        };
        const extRes = await db
          .from('menu_items')
          .insert({ ...baseInsert, day_of_week: dayOfWeek, item_kind: itemKind })
          .select('*')
          .single();

        let savedItem = extRes.data;
        if (extRes.error) {
          const baseRes = await db.from('menu_items').insert(baseInsert).select('*').single();
          if (baseRes.error || !baseRes.data) {
            console.error('Menu item DB insert error:', baseRes.error?.message || extRes.error.message);
            return NextResponse.json(
              { success: false, error: publicErrorMessage(baseRes.error || extRes.error, 'Could not save dish right now. Please try again.') },
              { status: 503 }
            );
          }
          savedItem = baseRes.data;
        }

        const adminClient = getAdminClient();
        if (adminClient) {
          await ensurePlanSlotsLinked(adminClient, input.provider_id);
        }

        const slotKey = `${input.provider_id}_${dayOfWeek}_${slotName.toUpperCase()}`;
        let storeMenu = platformStore.menus.get(slotKey);
        if (!storeMenu) {
          storeMenu = {
            id: `menu-${input.provider_id}-${dayOfWeek}-${slotName}`,
            provider_id: input.provider_id,
            day_of_week: dayOfWeek,
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
        } else if (!storeMenu.items_included.some((x) => x.toLowerCase() === itemName.toLowerCase())) {
          storeMenu.items_included.push(itemName);
        }

        return NextResponse.json({ success: true, item: savedItem || { name: itemName } }, { status: 201 });
      } catch (err: any) {
        console.error('DB menu insert failed:', err?.message);
        return NextResponse.json(
          { success: false, error: publicErrorMessage(err, 'Could not save dish right now. Please try again.') },
          { status: 503 }
        );
      }
    }

    const slotKey = `${input.provider_id}_${dayOfWeek}_${slotName.toUpperCase()}`;
    let storeMenu = platformStore.menus.get(slotKey);
    if (!storeMenu) {
      storeMenu = {
        id: `menu-${input.provider_id}-${dayOfWeek}-${slotName}`,
        provider_id: input.provider_id,
        day_of_week: dayOfWeek,
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
    } else if (!storeMenu.items_included.some((x) => x.toLowerCase() === itemName.toLowerCase())) {
      storeMenu.items_included.push(itemName);
    }

    return NextResponse.json({ success: true, item: { name: itemName, price: priceVal } }, { status: 201 });
  }

  // ACTION: REMOVE ITEM
  if (input.action === 'remove_item') {
    const slotName = (input.slot || 'lunch').toLowerCase();
    const dayOfWeek = input.day_of_week || 'Daily';
    const slotKey = `${input.provider_id}_${dayOfWeek}_${slotName.toUpperCase()}`;
    const storeMenu = platformStore.menus.get(slotKey) || platformStore.menus.get(`${input.provider_id}_Daily_${slotName.toUpperCase()}`);
    if (storeMenu && itemName) {
      storeMenu.items_included = storeMenu.items_included.filter((x) => x.toLowerCase() !== itemName.toLowerCase());
      storeMenu.items_extra = storeMenu.items_extra.filter((x) => x.name.toLowerCase() !== itemName.toLowerCase());
    }

    if (db) {
      try {
        const res = input.item_id
          ? await db.from('menu_items').delete().eq('id', input.item_id).eq('provider_id', input.provider_id)
          : itemName
            ? await db.from('menu_items').delete().eq('provider_id', input.provider_id).ilike('name', itemName)
            : { error: null };
        if (res.error) {
          console.error('Menu item delete error:', res.error.message);
          return NextResponse.json(
            { success: false, error: publicErrorMessage(res.error, 'Could not remove item. Please try again.') },
            { status: 503 }
          );
        }
      } catch (err: any) {
        console.error('Menu item delete exception:', err?.message);
        return NextResponse.json(
          { success: false, error: publicErrorMessage(err, 'Could not remove item. Please try again.') },
          { status: 503 }
        );
      }
    }
    return NextResponse.json({ success: true, message: 'Item removed successfully.' });
  }

  // ACTION: TOGGLE AVAILABILITY
  if (input.action === 'toggle_availability') {
    const isAvail = input.is_available !== undefined ? input.is_available : false;
    const slotName = (input.slot || 'lunch').toLowerCase();
    const dayOfWeek = input.day_of_week || 'Daily';
    const slotKey = `${input.provider_id}_${dayOfWeek}_${slotName.toUpperCase()}`;
    const storeMenu = platformStore.menus.get(slotKey) || platformStore.menus.get(`${input.provider_id}_Daily_${slotName.toUpperCase()}`);
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
        const res = input.item_id
          ? await db.from('menu_items').update({ active: isAvail }).eq('id', input.item_id).eq('provider_id', input.provider_id)
          : itemName
            ? await db.from('menu_items').update({ active: isAvail }).eq('provider_id', input.provider_id).ilike('name', itemName)
            : { error: null };
        if (res.error) {
          console.error('Menu availability update error:', res.error.message);
          return NextResponse.json(
            { success: false, error: publicErrorMessage(res.error, 'Could not update availability. Please try again.') },
            { status: 503 }
          );
        }
      } catch (err: any) {
        console.error('Menu availability update exception:', err?.message);
        return NextResponse.json(
          { success: false, error: publicErrorMessage(err, 'Could not update availability. Please try again.') },
          { status: 503 }
        );
      }
    }
    return NextResponse.json({ success: true, message: 'Availability updated successfully.' });
  }

  return NextResponse.json({ success: false, error: 'Unknown menu action.' }, { status: 400 });
}
