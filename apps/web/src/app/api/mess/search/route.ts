import { NextRequest, NextResponse } from 'next/server';
import { createClient as createSupabaseClient } from '@supabase/supabase-js';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://mrbtwsrknqofjkrbssww.supabase.co';
const SUPABASE_ANON = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1yYnR3c3JrbnFvZmprcmJzc3d3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI5MzEzNDcsImV4cCI6MjEwODUwNzM0N30.TzKjZ593n_ku_81ZCAuzOkeHl-7pGmQjylzIP3cHssc';

function getFallbackClient() {
  return createSupabaseClient(SUPABASE_URL, SUPABASE_ANON, {
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
    let supabase = getAdminClient();
    if (!supabase) {
      try {
        supabase = await createClient();
      } catch (_) {}
    }
    supabase = supabase || getFallbackClient();

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

    // Filter providers first by query before querying children
    const matchedProviders = allProviders.filter((provider) => {
      if (!query) return true;
      const q = query.toLowerCase();
      return (
        (provider.display_name && provider.display_name.toLowerCase().includes(q)) ||
        (provider.description && provider.description.toLowerCase().includes(q)) ||
        (provider.locality && provider.locality.toLowerCase().includes(q)) ||
        (provider.city && provider.city.toLowerCase().includes(q))
      );
    });

    const targetProviders = matchedProviders.length > 0 ? matchedProviders.slice(0, 50) : allProviders.slice(0, 50);
    const targetIds = targetProviders.map((p) => p.id);

    // Fetch related records in parallel for target providers
    const [plansRes, slotsRes, itemsRes, hoursRes] = await Promise.all([
      supabase
        .from('subscription_plans')
        .select('*')
        .in('provider_id', targetIds)
        .eq('active', true),
      supabase
        .from('meal_slots')
        .select('*')
        .in('provider_id', targetIds)
        .eq('active', true),
      supabase
        .from('menu_items')
        .select('*')
        .in('provider_id', targetIds)
        .eq('active', true),
      supabase
        .from('provider_operating_hours')
        .select('*')
        .in('provider_id', targetIds),
    ]);

    const allPlans = plansRes.data ?? [];
    const allSlots = slotsRes.data ?? [];
    const allItems = itemsRes.data ?? [];
    const allHours = hoursRes.data ?? [];

    // Filter providers based on search query or dietary filter
    const filtered = targetProviders.filter((provider) => {
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
          const durDays = plan.duration_days || durMonths * 30;
          const pricePaise = Number(plan.price_paise || 0);
          return {
            ...plan,
            duration_days: durDays,
            price_paise: pricePaise,
            price: pricePaise / 100,
          };
        });

      // Merge platformStore plans
      for (const [, sp] of platformStore.plans.entries()) {
        if (sp.provider_id === pId && sp.is_active !== false) {
          if (!pPlans.some((p) => p.id === sp.id || p.name.toLowerCase() === sp.name.toLowerCase())) {
            pPlans.push({
              id: sp.id,
              provider_id: pId,
              name: sp.name,
              description: sp.description,
              plan_type: sp.plan_type,
              duration_days: sp.duration_days,
              duration_months: Math.max(1, Math.round(sp.duration_days / 30)),
              meal_credits: sp.meal_credits,
              price_paise: sp.price_paise,
              price: sp.price_paise / 100,
            });
          }
        }
      }

      // Group menus by slot for mobile app, merging platformStore dishes
      const menus = pSlots.map((slot) => {
        const slotNameUpper = slot.name.toUpperCase();
        const storeMenu = platformStore.menus.get(`${pId}_Daily_${slotNameUpper}`);
        const slotItems = pItems.filter((item) =>
          item.meal_slot_id === slot.id ||
          (item.description && item.description.toLowerCase().includes(slot.name.toLowerCase()))
        );

        const dbIncluded = slotItems.filter((item) => !item.is_add_on).map((item) => item.name);
        const storeIncluded = storeMenu?.items_included || [];
        const combinedIncluded = Array.from(new Set([...dbIncluded, ...storeIncluded]));

        const dbExtra = slotItems.filter((item) => item.is_add_on).map((item) => ({
          id: item.id,
          name: item.name,
          price: Number(item.price_paise || 0) / 100,
          price_paise: Number(item.price_paise || 0),
        }));
        const storeExtra = (storeMenu?.items_extra || []).map((e) => ({
          id: `ext-${e.name.toLowerCase().replace(/\s+/g, '-')}`,
          name: e.name,
          price: e.price || 30,
          price_paise: Math.round((e.price || 30) * 100),
        }));
        const combinedExtra = [...dbExtra];
        for (const se of storeExtra) {
          if (!combinedExtra.some((x) => x.name.toLowerCase() === se.name.toLowerCase())) {
            combinedExtra.push(se);
          }
        }

        return {
          id: slot.id,
          slot: slotNameUpper,
          slot_id: slot.id,
          starts_at_local: slot.starts_at_local,
          ends_at_local: slot.ends_at_local,
          items_included: combinedIncluded,
          items_extra: combinedExtra,
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
