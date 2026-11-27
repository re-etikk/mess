import { NextRequest, NextResponse } from 'next/server';
import { createClient as createSupabaseClient } from '@supabase/supabase-js';
import { getAdminClient, noStoreFetch } from '@/lib/supabase/admin';
import { createClient } from '@/lib/supabase/server';
import { platformStore } from '@/lib/platform-service';
import { getIstWeekday, isKitchenOpenFromRecord, isUndefinedColumnError } from '@/lib/kitchen-status';

export const dynamic = 'force-dynamic';
export const fetchCache = 'force-no-store';

const SLOT_ORDER: Record<string, number> = { breakfast: 1, lunch: 2, snacks: 3, dinner: 4 };

function getFallbackClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anon) return null;
  return createSupabaseClient(url, anon, {
    global: { fetch: noStoreFetch },
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

function displayClock(value?: string | null): string {
  if (!value) return '';
  const [hourText, minuteText] = value.split(':');
  const hour = Number(hourText);
  if (isNaN(hour)) return value;
  const suffix = hour >= 12 ? 'PM' : 'AM';
  const hour12 = hour % 12 || 12;
  return `${String(hour12).padStart(2, '0')}:${minuteText || '00'} ${suffix}`;
}

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  let db = getAdminClient();
  if (!db) {
    try {
      db = await createClient();
    } catch {}
  }
  db = db || getFallbackClient();
  const searchParams = new URL(req.url).searchParams;
  const slot = searchParams.get('slot');
  const dayFilter = searchParams.get('day');
  const providerId = params.id;

  if (db) {
    try {
      const primaryProv = await db
        .from('providers')
        .select('id,display_name,description,address_line1,locality,city,public_phone,public_email,cover_path,logo_path,supports_pickup,supports_delivery,status,is_accepting_orders')
        .eq('id', providerId)
        .maybeSingle();

      let provider: any = primaryProv.data;
      if (isUndefinedColumnError(primaryProv.error, 'is_accepting_orders')) {
        const fallbackProv = await db
          .from('providers')
          .select('id,display_name,description,address_line1,locality,city,public_phone,public_email,cover_path,logo_path,supports_pickup,supports_delivery,status')
          .eq('id', providerId)
          .maybeSingle();
        provider = fallbackProv.data;
      }

      if (provider) {
        const todayWeekday = getIstWeekday();
        const [slotsPrimary, { data: dbItems }, { data: todayHour }] = await Promise.all([
          db
            .from('meal_slots')
            .select('id,name,starts_at_local,ends_at_local,active,single_meal_price_paise')
            .eq('provider_id', provider.id)
            .order('starts_at_local'),
          db.from('menu_items').select('id,name,description,category,dietary_type,price_paise,meal_slot_id,is_add_on,max_quantity,active,day_of_week,item_kind').eq('provider_id', provider.id).eq('active', true).order('name'),
          db.from('provider_operating_hours').select('closed').eq('provider_id', provider.id).eq('weekday', todayWeekday).maybeSingle(),
        ]);

        let rawSlots: any[] | null = slotsPrimary.data as any[] | null;
        if (isUndefinedColumnError(slotsPrimary.error, 'single_meal_price_paise')) {
          const slotsFb = await db
            .from('meal_slots')
            .select('id,name,starts_at_local,ends_at_local,active')
            .eq('provider_id', provider.id)
            .order('starts_at_local');
          rawSlots = slotsFb.data as any[] | null;
        }

        const isOpenToday = isKitchenOpenFromRecord({
          status: provider.status,
          is_accepting_orders: provider.is_accepting_orders,
          todayHours: todayHour,
        });
        platformStore.providerStatuses.set(provider.id, isOpenToday);

        const slots = (rawSlots ?? [])
          .filter((s) => String(s.name || '').trim().toLowerCase() !== 'all')
          .sort((a, b) => (SLOT_ORDER[String(a.name).toLowerCase()] ?? 99) - (SLOT_ORDER[String(b.name).toLowerCase()] ?? 99));

        let filteredItems = dbItems ?? [];
        if (dayFilter && dayFilter !== 'Daily') {
          const dayMatched = filteredItems.filter((it: any) => !it.day_of_week || it.day_of_week === dayFilter || it.day_of_week === 'Daily');
          filteredItems = dayMatched;
        }

        const providerPayload = {
          id: provider.id,
          name: provider.display_name,
          address: [provider.address_line1, provider.locality, provider.city].filter(Boolean).join(', '),
          locality: provider.locality,
          city: provider.city,
          phone: provider.public_phone,
          public_email: provider.public_email,
          description: provider.description,
          cover_path: provider.cover_path,
          logo_path: provider.logo_path,
          supports_pickup: provider.supports_pickup,
          supports_delivery: provider.supports_delivery,
          status: provider.status,
          is_open_today: isOpenToday,
        };

        if (slot && slots.length) {
          const targetSlot = slots.find((s) => s.name.toLowerCase() === slot.toLowerCase());
          const slotItems = targetSlot
            ? filteredItems.filter((i: any) => i.meal_slot_id === targetSlot.id || (!i.meal_slot_id && (i.description || '').toLowerCase().includes(slot.toLowerCase())))
            : [];
          const included = slotItems.filter((i: any) => !i.is_add_on && Number(i.price_paise || 0) === 0);
          const extra = slotItems.filter((i: any) => i.is_add_on || Number(i.price_paise || 0) > 0);
          return NextResponse.json({
            success: true,
            provider: providerPayload,
            slot: slot.toUpperCase(),
            meal_slot_id: targetSlot?.id ?? null,
            menu: {
              items_included: included,
              items_extra: extra,
              items: [...included, ...extra],
            },
          });
        }

        // Return grouped menus across active slots cleanly from DB
        const activeSlots = slots.filter((s) => s.active !== false);
        const timings = Object.fromEntries(
          slots.map((s) => {
            const slotPaise = s.single_meal_price_paise != null ? Number(s.single_meal_price_paise) : null;
            return [
              String(s.name).toLowerCase(),
              {
                enabled: s.active !== false,
                start: displayClock(s.starts_at_local),
                end: displayClock(s.ends_at_local),
                single_meal_price_paise: slotPaise,
                single_meal_price_inr: slotPaise != null && slotPaise > 0 ? Math.round(slotPaise / 100) : null,
              },
            ];
          })
        );
        const groupedMenus = activeSlots.map((s) => {
          const sItems = filteredItems.filter(
            (i: any) => i.meal_slot_id === s.id || (!i.meal_slot_id && (i.description || '').toLowerCase().includes(s.name.toLowerCase()))
          );
          const slotPaise = s.single_meal_price_paise != null ? Number(s.single_meal_price_paise) : null;
          return {
            slot: s.name.toUpperCase(),
            slot_id: s.id,
            starts_at_local: s.starts_at_local,
            ends_at_local: s.ends_at_local,
            enabled: s.active !== false,
            single_meal_price_paise: slotPaise,
            single_meal_price_inr: slotPaise != null && slotPaise > 0 ? Math.round(slotPaise / 100) : null,
            items_included: sItems.filter((i: any) => !i.is_add_on).map((i: any) => i.name),
            items_extra: sItems
              .filter((i: any) => i.is_add_on)
              .map((i: any) => ({
                id: i.id,
                name: i.name,
                kind: i.item_kind || 'addon',
                price_paise: Number(i.price_paise || 0),
                price: Number(i.price_paise || 0) / 100,
              })),
            items: sItems,
          };
        });

        return NextResponse.json(
          {
            success: true,
            provider: providerPayload,
            day: dayFilter || 'Daily',
            timings,
            menus: groupedMenus,
          },
          { headers: { 'Cache-Control': 'private, no-store' } }
        );
      }
    } catch (e: any) {
      console.warn('Mess menu DB error:', e?.message);
    }
  }

  // Only check real persisted entries in platformStore (no fabricated menu items!)
  const keyDay = dayFilter || 'Daily';
  const storeProv = platformStore.providers.get(providerId);
  const storeOpen = platformStore.providerStatuses.has(providerId)
    ? platformStore.providerStatuses.get(providerId)!
    : storeProv?.is_open_today !== false;
  const storeProviderObj = storeProv
    ? {
        id: storeProv.id,
        name: storeProv.display_name,
        address: storeProv.address,
        phone: storeProv.phone,
        status: storeProv.status,
        is_open_today: storeOpen,
      }
    : { id: providerId, name: 'Mess Partner', is_open_today: storeOpen };

  if (!slot) {
    const slotsToCheck = ['BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER'];
    const storeMenus = slotsToCheck
      .map((sName) => {
        const m = platformStore.menus.get(`${providerId}_${keyDay}_${sName}`) || platformStore.menus.get(`${providerId}_Daily_${sName}`);
        if (!m) return null;
        return {
          slot: sName,
          slot_id: `slot-${sName.toLowerCase()}`,
          enabled: true,
          items_included: m.items_included || [],
          items_extra: (m.items_extra || []).map((e, i) => ({
            id: `ext-${i}`,
            name: e.name,
            kind: 'addon',
            price_paise: Math.round((e.price || 0) * 100),
            price: e.price || 0,
          })),
          items: [
            ...(m.items_included || []).map((name, i) => ({ id: `inc-${i}`, name, price_paise: 0, is_add_on: false, active: true })),
            ...(m.items_extra || []).map((e, i) => ({
              id: `ext-${i}`,
              name: e.name,
              price_paise: Math.round((e.price || 0) * 100),
              is_add_on: true,
              active: true,
            })),
          ],
        };
      })
      .filter(Boolean);

    return NextResponse.json({
      success: true,
      provider: storeProviderObj,
      day: keyDay,
      menus: storeMenus,
    });
  }

  const targetSlot = slot.toUpperCase();
  const storeMenu = platformStore.menus.get(`${providerId}_${keyDay}_${targetSlot}`) || platformStore.menus.get(`${providerId}_Daily_${targetSlot}`);

  return NextResponse.json({
    success: true,
    provider: storeProviderObj,
    day: keyDay,
    slot: targetSlot,
    menu: {
      items_included: (storeMenu?.items_included || []).map((name, i) => ({
        id: `inc-${i}`,
        name,
        price_paise: 0,
        active: true,
      })),
      items_extra: (storeMenu?.items_extra || []).map((e, i) => ({
        id: `ext-${i}`,
        name: e.name,
        price_paise: Math.round((e.price || 0) * 100),
        price: e.price || 0,
        active: true,
      })),
    },
  });
}
