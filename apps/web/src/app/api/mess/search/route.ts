import { NextRequest, NextResponse } from 'next/server';
import { createClient as createSupabaseClient } from '@supabase/supabase-js';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient, noStoreFetch } from '@/lib/supabase/admin';
import { sanitizePostgrestSearch } from '@/lib/auth-session';
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

function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  return Math.round(R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a)) * 100) / 100;
}

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const query = params.get('q')?.trim().slice(0, 100) || '';
  const city = params.get('city')?.trim().slice(0, 100) || '';
  const area = params.get('area')?.trim().slice(0, 100) || '';
  const dietary = params.get('dietary')?.trim().toLowerCase() || '';
  const slotFilter = params.get('slot')?.trim().toLowerCase() || '';
  const minRatingParam = Number(params.get('min_rating') || '0');
  const openNowOnly = params.get('open_now') === 'true';
  const deliveryOnly = params.get('delivery_only') === 'true';
  const sortBy = params.get('sort')?.trim().toLowerCase() || '';
  const userLat = params.get('lat') ? Number(params.get('lat')) : null;
  const userLng = params.get('lng') ? Number(params.get('lng')) : null;
  const hasUserCoords = userLat !== null && userLng !== null && !isNaN(userLat) && !isNaN(userLng);

  try {
    let supabase = getAdminClient();
    if (!supabase) {
      try {
        supabase = await createClient();
      } catch (_) {}
    }
    supabase = supabase || getFallbackClient();
    if (!supabase) {
      const storeProviders = Array.from(platformStore.providers.values())
        .filter((p) => p.status === 'active')
        .map((p) => {
          const isOpen = platformStore.providerStatuses.has(p.id)
            ? platformStore.providerStatuses.get(p.id)!
            : p.is_open_today !== false;
          return {
            id: p.id,
            display_name: p.display_name,
            slug: p.id,
            description: p.description || '',
            locality: p.address || '',
            city: '',
            supports_pickup: (p as any).supports_pickup !== false,
            supports_delivery: (p as any).supports_delivery === true,
            status: p.status,
            is_open_today: isOpen,
            rating: null,
            total_reviews: 0,
            subscriber_count: 0,
            distance_km: null,
            dietary_types: [],
            starting_meal_price: null,
            plans: [],
            menus: [],
            timings: {},
            meal_slots: [],
          };
        })
        .filter((provider) => {
          if (query) {
            const q = query.toLowerCase();
            if (
              !provider.display_name.toLowerCase().includes(q) &&
              !provider.description.toLowerCase().includes(q) &&
              !provider.locality.toLowerCase().includes(q)
            ) {
              return false;
            }
          }
          if (openNowOnly && !provider.is_open_today) return false;
          if (deliveryOnly && !provider.supports_delivery) return false;
          return true;
        });

      return NextResponse.json(
        { success: true, total: storeProviders.length, providers: storeProviders },
        { headers: { 'Cache-Control': 'private, no-store' } }
      );
    }

    const applySearchFilters = (q: any) => {
      if (city) {
        const safeCity = sanitizePostgrestSearch(city);
        if (safeCity) {
          q = q.ilike('city', `%${safeCity}%`);
        }
      }
      if (area) {
        const esc = sanitizePostgrestSearch(area);
        if (esc) {
          q = q.or(`locality.ilike.%${esc}%,city.ilike.%${esc}%,address_line1.ilike.%${esc}%`);
        }
      }
      return q;
    };

    const primaryRes = await applySearchFilters(
      supabase
        .from('providers')
        .select(
          'id,display_name,slug,description,logo_path,cover_path,public_phone,public_email,address_line1,address_line2,locality,city,state,pincode,latitude,longitude,supports_pickup,supports_delivery,status,is_accepting_orders,created_at'
        )
        .eq('status', 'active')
        .order('display_name')
    ).limit(200);

    let dbProviders: any[] | null = primaryRes.data as any[] | null;
    let providersError = primaryRes.error;

    if (isUndefinedColumnError(providersError, 'is_accepting_orders')) {
      const fallbackRes = await applySearchFilters(
        supabase
          .from('providers')
          .select(
            'id,display_name,slug,description,logo_path,cover_path,public_phone,public_email,address_line1,address_line2,locality,city,state,pincode,latitude,longitude,supports_pickup,supports_delivery,status,created_at'
          )
          .eq('status', 'active')
          .order('display_name')
      ).limit(200);
      dbProviders = fallbackRes.data as any[] | null;
      providersError = fallbackRes.error;
    }
    if (providersError) throw providersError;

    const allProviders = dbProviders ?? [];
    if (allProviders.length === 0) {
      return NextResponse.json({ success: true, total: 0, providers: [] }, { headers: { 'Cache-Control': 'private, no-store' } });
    }

    const targetIds = allProviders.map((p) => p.id);

    const [plansRes, slotsRes, itemsRes, hoursRes, reviewsRes, subsRes] = await Promise.all([
      supabase.from('subscription_plans').select('*').in('provider_id', targetIds).eq('active', true),
      supabase.from('meal_slots').select('*').in('provider_id', targetIds).eq('active', true),
      supabase.from('menu_items').select('*').in('provider_id', targetIds).eq('active', true),
      supabase.from('provider_operating_hours').select('*').in('provider_id', targetIds),
      supabase.from('mess_reviews').select('provider_id,rating').in('provider_id', targetIds).then((r) => r, () => ({ data: [] as any[], error: null })),
      supabase.from('subscriptions').select('provider_id').in('provider_id', targetIds).eq('status', 'active').then((r) => r, () => ({ data: [] as any[], error: null })),
    ]);

    const allPlans = plansRes.data ?? [];
    const allSlots = slotsRes.data ?? [];
    const allItems = itemsRes.data ?? [];
    const allHours = hoursRes.data ?? [];
    const allReviews = (reviewsRes as any)?.data ?? [];
    const allSubs = (subsRes as any)?.data ?? [];

    const todayWeekday = getIstWeekday();

    let results = allProviders
      .map((provider: any) => {
        const pId = provider.id;
        const pItems = allItems.filter((i: any) => i.provider_id === pId);
        const pSlots = allSlots
          .filter((s: any) => s.provider_id === pId && String(s.name || '').trim().toLowerCase() !== 'all')
          .sort((a: any, b: any) => (SLOT_ORDER[String(a.name).toLowerCase()] ?? 99) - (SLOT_ORDER[String(b.name).toLowerCase()] ?? 99));
        const pHours = allHours.filter((h: any) => h.provider_id === pId);
        const pReviews = allReviews.filter((r: any) => r.provider_id === pId);
        const dbSubCount = allSubs.filter((s: any) => s.provider_id === pId).length;

        const pPlans = allPlans
          .filter((plan: any) => plan.provider_id === pId && plan.published !== false)
          .map((plan: any) => {
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

        const menus = pSlots.map((slot: any) => {
          const slotNameUpper = String(slot.name || '').toUpperCase();
          const storeMenu = platformStore.menus.get(`${pId}_Daily_${slotNameUpper}`);
          const slotItems = pItems.filter(
            (item: any) =>
              item.meal_slot_id === slot.id ||
              (!item.meal_slot_id && item.description && item.description.toLowerCase().includes(String(slot.name).toLowerCase()))
          );

          const dbIncluded = slotItems.filter((item: any) => !item.is_add_on).map((item: any) => item.name);
          const combinedIncluded = dbIncluded.length > 0 ? dbIncluded : storeMenu?.items_included || [];

          const dbExtra = slotItems
            .filter((item: any) => item.is_add_on)
            .map((item: any) => ({
              id: item.id,
              name: item.name,
              kind: item.item_kind || 'addon',
              price: Number(item.price_paise || 0) / 100,
              price_paise: Number(item.price_paise || 0),
            }));
          const combinedExtra =
            dbExtra.length > 0
              ? dbExtra
              : (storeMenu?.items_extra || []).map((e: any) => ({
                  id: `ext-${e.name.toLowerCase().replace(/\s+/g, '-')}`,
                  name: e.name,
                  kind: 'addon',
                  price: e.price || 0,
                  price_paise: Math.round((e.price || 0) * 100),
                }));

          const slotPaise = (slot as any).single_meal_price_paise != null ? Number((slot as any).single_meal_price_paise) : null;
          return {
            id: slot.id,
            slot: slotNameUpper,
            slot_id: slot.id,
            starts_at_local: slot.starts_at_local,
            ends_at_local: slot.ends_at_local,
            single_meal_price_paise: slotPaise,
            single_meal_price_inr: slotPaise != null && slotPaise > 0 ? Math.round(slotPaise / 100) : null,
            items_included: combinedIncluded,
            items_extra: combinedExtra,
            items: slotItems,
          };
        });

        const timings: Record<string, { enabled: boolean; start: string; end: string }> = {};
        for (const slot of pSlots) {
          timings[String(slot.name).toLowerCase()] = {
            enabled: slot.active !== false,
            start: displayClock(slot.starts_at_local),
            end: displayClock(slot.ends_at_local),
          };
        }

        // Real aggregated rating (null when 0 reviews — NEVER hardcode 4.8)
        const totalReviews = pReviews.length;
        const avgRating =
          totalReviews > 0
            ? Math.round((pReviews.reduce((acc: number, r: any) => acc + Number(r.rating || 0), 0) / totalReviews) * 10) / 10
            : null;

        // Real Haversine distance (null unless both user & provider coordinates exist)
        const pLat = provider.latitude != null ? Number(provider.latitude) : null;
        const pLng = provider.longitude != null ? Number(provider.longitude) : null;
        const distanceKm =
          hasUserCoords && pLat != null && pLng != null && !isNaN(pLat) && !isNaN(pLng)
            ? haversineKm(userLat!, userLng!, pLat, pLng)
            : null;

        // Authoritative open today flag directly from Postgres state
        const todayHour = pHours.find((h: any) => Number(h.weekday) === todayWeekday);
        const isOpenToday = isKitchenOpenFromRecord({
          status: provider.status,
          is_accepting_orders: provider.is_accepting_orders,
          todayHours: todayHour,
        });
        platformStore.providerStatuses.set(pId, isOpenToday);

        // Real dietary types from active menu items
        const dietarySet = new Set<string>();
        for (const item of pItems) {
          if (item.dietary_type && item.dietary_type !== 'unspecified') {
            dietarySet.add(item.dietary_type);
          }
        }

        // Authoritative starting single-meal price in INR (slot rate -> priced base dish -> multi-day plan estimate >= ₹30)
        const slotRates = pSlots
          .map((s: any) => Number(s.single_meal_price_paise || 0))
          .filter((p: number) => p >= 100);
        const nonZeroMenuPrices = pItems
          .filter((i: any) => !i.is_add_on && Number(i.price_paise) >= 100)
          .map((i: any) => Number(i.price_paise));
        const dailyPlanPrices = pPlans
          .filter((pl: any) => Number(pl.price_paise) >= 3000)
          .map((pl: any) => Math.round(Number(pl.price_paise) / Math.max(1, Number(pl.duration_days || 30))))
          .filter((perMealPaise: number) => perMealPaise >= 1000);
        const explicitCandidates = [...slotRates, ...nonZeroMenuPrices];
        const minPaiseCandidates = explicitCandidates.length > 0 ? explicitCandidates : dailyPlanPrices;
        const startingMealPrice =
          minPaiseCandidates.length > 0 ? Math.max(1, Math.round(Math.min(...minPaiseCandidates) / 100)) : null;

        return {
          ...provider,
          rating: avgRating,
          total_reviews: totalReviews,
          subscriber_count: dbSubCount,
          distance_km: distanceKm,
          is_open_today: isOpenToday,
          dietary_types: Array.from(dietarySet),
          starting_meal_price: startingMealPrice,
          plans: pPlans,
          menus,
          timings,
          meal_slots: pSlots,
        };
      })
      .filter((provider: any) => {
        if (query) {
          const q = query.toLowerCase();
          const textMatch =
            (provider.display_name && provider.display_name.toLowerCase().includes(q)) ||
            (provider.description && provider.description.toLowerCase().includes(q)) ||
            (provider.locality && provider.locality.toLowerCase().includes(q)) ||
            (provider.city && provider.city.toLowerCase().includes(q));
          const dishMatch = (provider.menus || []).some(
            (m: any) =>
              (m.items_included || []).some((x: string) => x.toLowerCase().includes(q)) ||
              (m.items_extra || []).some((x: any) => String(x.name || '').toLowerCase().includes(q))
          );
          if (!textMatch && !dishMatch) return false;
        }
        if (dietary && dietary !== 'all') {
          const types = (provider.dietary_types as string[]) || [];
          if (types.length > 0) {
            if (dietary === 'veg' && !types.some((t) => t === 'vegetarian' || t === 'vegan' || t === 'jain')) return false;
            if (dietary === 'non_veg' && !types.includes('non_vegetarian')) return false;
          }
        }
        if (slotFilter) {
          const hasSlot = (provider.meal_slots || []).some((s: any) => String(s.name).toLowerCase() === slotFilter && s.active !== false);
          if (!hasSlot) return false;
        }
        if (minRatingParam > 0 && (provider.rating == null || provider.rating < minRatingParam)) {
          return false;
        }
        if (openNowOnly && !provider.is_open_today) {
          return false;
        }
        if (deliveryOnly && !provider.supports_delivery) {
          return false;
        }
        return true;
      });

    if (sortBy === 'rating') {
      results.sort((a: any, b: any) => (b.rating ?? -1) - (a.rating ?? -1));
    } else if (sortBy === 'price') {
      results.sort((a: any, b: any) => (a.starting_meal_price ?? 999999) - (b.starting_meal_price ?? 999999));
    } else if (sortBy === 'distance') {
      results.sort((a: any, b: any) => (a.distance_km ?? 999999) - (b.distance_km ?? 999999));
    } else {
      // Honest multi-signal ML relevance ranking: open kitchens first, Bayesian rating + distance + completeness
      const mlScore = (p: any): number => {
        const openBoost = p.is_open_today ? 1000 : 0;
        const revCount = Number(p.total_reviews || 0);
        const bayesianRating = revCount > 0 && p.rating != null
          ? (Number(p.rating) * revCount + 3.8 * 2) / (revCount + 2)
          : 3.6;
        const distPenalty = p.distance_km != null ? Math.min(20, Number(p.distance_km) * 1.5) : 5;
        const menuRichness = Math.min(5, (p.menus || []).filter((m: any) => (m.items_included || []).length > 0).length);
        const coverBoost = p.cover_path ? 3 : 0;
        return openBoost + bayesianRating * 10 + menuRichness * 2 + coverBoost - distPenalty;
      };
      results.sort((a: any, b: any) => mlScore(b) - mlScore(a));
    }

    return NextResponse.json(
      {
        success: true,
        total: results.length,
        providers: results,
      },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  } catch (error: any) {
    console.error('Provider search error:', error?.message);
    return NextResponse.json({ success: false, error: 'Failed to search providers.' }, { status: 500 });
  }
}
