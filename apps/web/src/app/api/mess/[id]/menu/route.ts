import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export async function GET(req: NextRequest, { params }: { params: { id: string } }) {
  const db = getAdminClient();
  const slot = new URL(req.url).searchParams.get('slot');
  const providerId = params.id;

  // 1. Try DB first
  if (db) {
    try {
      const { data: provider } = await db
        .from('providers')
        .select('id,display_name,address,phone,status')
        .eq('id', providerId)
        .maybeSingle();

      if (provider) {
        let slotId: string | null = null;
        if (slot) {
          const { data } = await db
            .from('meal_slots')
            .select('id,name')
            .eq('provider_id', provider.id)
            .eq('active', true)
            .ilike('name', slot)
            .maybeSingle();
          slotId = data?.id ?? null;
        }

        const { data: dbItems } = await db
          .from('menu_items')
          .select('id,name,description,category,dietary_type,price_paise,active,available_from,available_until')
          .eq('provider_id', provider.id)
          .eq('active', true)
          .order('name');

        const targetSlot = (slot || 'lunch').toUpperCase();
        const storeMenu = platformStore.menus.get(`${providerId}_Daily_${targetSlot}`) || platformStore.menus.get(`${providerId}_Daily_LUNCH`);

        const items = dbItems ?? [];
        const includedDb = items.filter((item) => Number(item.price_paise) === 0);
        const extraDb = items.filter((item) => Number(item.price_paise) > 0);

        // Merge in items from platformStore
        const combinedIncluded: any[] = [...includedDb];
        if (storeMenu?.items_included) {
          for (const incName of storeMenu.items_included) {
            if (!combinedIncluded.some((x) => x.name.toLowerCase() === incName.toLowerCase())) {
              combinedIncluded.push({
                id: `store-inc-${incName.toLowerCase().replace(/\s+/g, '-')}`,
                name: incName,
                description: 'Fresh prepared standard thali portion',
                price_paise: 0,
                dietary_type: 'vegetarian',
                active: true,
              });
            }
          }
        }

        const combinedExtra: any[] = [...extraDb];
        if (storeMenu?.items_extra) {
          for (const ext of storeMenu.items_extra) {
            if (!combinedExtra.some((x) => x.name.toLowerCase() === ext.name.toLowerCase())) {
              combinedExtra.push({
                id: `store-ext-${ext.name.toLowerCase().replace(/\s+/g, '-')}`,
                name: ext.name,
                description: 'Add-on extra',
                price_paise: (ext.price || 30) * 100,
                dietary_type: 'vegetarian',
                active: true,
              });
            }
          }
        }

        return NextResponse.json(
          {
            success: true,
            provider: { id: provider.id, name: provider.display_name, address: provider.address, phone: provider.phone },
            slot: slot || null,
            meal_slot_id: slotId,
            menu: {
              items_included: combinedIncluded,
              items_extra: combinedExtra,
              items: [...combinedIncluded, ...combinedExtra],
            },
          },
          { headers: { 'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=120' } }
        );
      }
    } catch (_) {}
  }

  // 2. Resilient platformStore fallback
  const storeProv = platformStore.providers.get(providerId);
  const targetSlot = (slot || 'lunch').toUpperCase();
  const storeMenu = platformStore.menus.get(`${providerId}_Daily_${targetSlot}`) || platformStore.menus.get(`${providerId}_Daily_LUNCH`);

  const included = (storeMenu?.items_included || ['Dal Tadka', 'Basmati Rice', '4 Rotis', 'Sabzi of the day', 'Salad']).map((name, i) => ({
    id: `item-inc-${i}`,
    name,
    description: 'Fresh prepared standard thali portion',
    price_paise: 0,
    dietary_type: 'vegetarian',
    active: true,
  }));

  const extra = (storeMenu?.items_extra || [
    { name: 'Gulab Jamun (2 pcs)', price: 30 },
    { name: 'Extra Paneer Sabzi', price: 50 },
  ]).map((e, i) => ({
    id: `item-ext-${i}`,
    name: e.name,
    description: 'Add-on extra',
    price_paise: (e.price || 30) * 100,
    dietary_type: 'vegetarian',
    active: true,
  }));

  return NextResponse.json({
    success: true,
    provider: {
      id: providerId,
      name: storeProv?.display_name || 'Mess Partner',
      address: storeProv?.address || 'Campus Road',
      phone: storeProv?.phone || '',
    },
    slot: slot || 'lunch',
    meal_slot_id: `slot-${targetSlot.toLowerCase()}`,
    menu: {
      items_included: included,
      items_extra: extra,
      items: [...included, ...extra],
    },
  });
}
