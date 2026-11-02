import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

function displayClock(value?: string | null): string {
  if (!value) return '';
  const [hourText, minuteText] = value.split(':');
  const hour = Number(hourText);
  if (isNaN(hour)) return value;
  const suffix = hour >= 12 ? 'PM' : 'AM';
  const hour12 = hour % 12 || 12;
  return `${String(hour12).padStart(2, '0')}:${minuteText || '00'} ${suffix}`;
}

const DEFAULT_SLOTS = [
  { name: 'breakfast', starts_at_local: '07:30:00', ends_at_local: '10:00:00' },
  { name: 'lunch', starts_at_local: '12:00:00', ends_at_local: '15:30:00' },
  { name: 'dinner', starts_at_local: '19:30:00', ends_at_local: '22:30:00' },
];

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const query = params.get('q')?.trim().slice(0, 100) || '';
  const city = params.get('city')?.trim().slice(0, 100) || '';
  const dietary = params.get('dietary')?.trim().toLowerCase();

  try {
    const admin = getAdminClient();
    const supabase = admin || (await createClient());

    let providersQuery = supabase
      .from('providers')
      .select('id,display_name,slug,description,public_phone,public_email,address_line1,locality,city,state,pincode,latitude,longitude,status,created_at')
      .eq('status', 'active')
      .order('display_name');

    if (city) {
      providersQuery = providersQuery.ilike('city', `%${city.replace(/[\\%_]/g, '\\$&')}%`);
    }

    const { data: dbProviders, error: providersError } = await providersQuery.limit(500);
    if (providersError) throw providersError;

    const allProviders = dbProviders ?? [];
    if (allProviders.length === 0) {
      return NextResponse.json({ success: true, total: 0, providers: [] });
    }

    const providerIds = allProviders.map((p) => p.id);

    // Fetch related records in parallel for all providers
    const [plansRes, slotsRes, itemsRes, hoursRes] = await Promise.all([
      supabase
        .from('subscription_plans')
        .select('*')
        .in('provider_id', providerIds)
        .eq('active', true),
      supabase
        .from('meal_slots')
        .select('*')
        .in('provider_id', providerIds)
        .eq('active', true),
      supabase
        .from('menu_items')
        .select('*')
        .in('provider_id', providerIds)
        .eq('active', true),
      supabase
        .from('provider_operating_hours')
        .select('*')
        .in('provider_id', providerIds),
    ]);

    const allPlans = plansRes.data ?? [];
    const allSlots = slotsRes.data ?? [];
    const allItems = itemsRes.data ?? [];
    const allHours = hoursRes.data ?? [];

    // Filter providers based on search query or dietary filter
    const filtered = allProviders.filter((provider) => {
      const pItems = allItems.filter((i) => i.provider_id === provider.id);

      if (dietary) {
        const allowedTypes = dietary === 'veg' ? ['vegetarian', 'vegan'] : dietary === 'non_veg' ? ['non_vegetarian'] : [dietary];
        const hasDietary = pItems.some((item) => allowedTypes.includes(item.dietary_type));
        if (!hasDietary && pItems.length > 0) return false;
      }

      if (!query) return true;

      const q = query.toLowerCase();
      const textMatch =
        (provider.display_name && provider.display_name.toLowerCase().includes(q)) ||
        (provider.description && provider.description.toLowerCase().includes(q)) ||
        (provider.locality && provider.locality.toLowerCase().includes(q)) ||
        (provider.city && provider.city.toLowerCase().includes(q));

      const dishMatch = pItems.some((item) => item.name && item.name.toLowerCase().includes(q));
      return textMatch || dishMatch;
    });

    const results = filtered.map((provider) => {
      const pId = provider.id;
      const pItems = allItems.filter((i) => i.provider_id === pId);
      let pSlots = allSlots.filter((s) => s.provider_id === pId);

      if (pSlots.length === 0) {
        pSlots = DEFAULT_SLOTS.map((s) => ({
          id: `slot-${s.name}-${pId.slice(0, 8)}`,
          provider_id: pId,
          name: s.name,
          starts_at_local: s.starts_at_local,
          ends_at_local: s.ends_at_local,
          active: true,
        }));
      }

      const pPlans = allPlans
        .filter((plan) => plan.provider_id === pId)
        .map((plan) => {
          const durMonths = plan.duration_months || 1;
          const durDays = durMonths * 30;
          const pricePaise = Number(plan.price_paise || 0);
          return {
            ...plan,
            duration_days: durDays,
            price_paise: pricePaise,
            price: pricePaise / 100,
          };
        });

      // Group menus by slot for mobile app
      const menus = pSlots.map((slot) => {
        const slotItems = pItems.filter((item) =>
          item.meal_slot_id === slot.id ||
          (item.description && item.description.toLowerCase().includes(slot.name.toLowerCase()))
        );

        return {
          id: slot.id,
          slot: slot.name.toUpperCase(),
          slot_id: slot.id,
          starts_at_local: slot.starts_at_local,
          ends_at_local: slot.ends_at_local,
          items_included: slotItems.filter((item) => !item.is_add_on).map((item) => item.name),
          items_extra: slotItems.filter((item) => item.is_add_on).map((item) => ({
            id: item.id,
            name: item.name,
            price: Number(item.price_paise || 0) / 100,
            price_paise: Number(item.price_paise || 0),
          })),
          items: slotItems,
        };
      });

      // Build timings map
      const timings: Record<string, { enabled: boolean; start: string; end: string }> = {};
      for (const slot of pSlots) {
        timings[slot.name.toLowerCase()] = {
          enabled: slot.active !== false,
          start: displayClock(slot.starts_at_local),
          end: displayClock(slot.ends_at_local),
        };
      }
      if (!timings.breakfast) timings.breakfast = { enabled: true, start: '07:30 AM', end: '10:00 AM' };
      if (!timings.lunch) timings.lunch = { enabled: true, start: '12:00 PM', end: '03:30 PM' };
      if (!timings.dinner) timings.dinner = { enabled: true, start: '07:30 PM', end: '10:30 PM' };

      return {
        ...provider,
        rating: 4.8,
        total_reviews: 24,
        distance_km: 0.8,
        is_open_today: true,
        cuisines: ['North Indian', 'Homestyle'],
        dietary_types: ['veg'],
        plans: pPlans,
        menus,
        timings,
        meal_slots: pSlots,
      };
    });

    return NextResponse.json({
      success: true,
      total: results.length,
      providers: results,
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error: any) {
    console.error('Provider search error:', error?.message);
    return NextResponse.json({ success: false, error: 'Failed to search providers.' }, { status: 500 });
  }
}
