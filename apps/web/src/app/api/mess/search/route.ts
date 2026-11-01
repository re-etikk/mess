import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const query = params.get('q')?.trim().slice(0, 100) || '';
  const city = params.get('city')?.trim().slice(0, 100) || '';
  const cuisine = params.get('cuisine')?.trim();
  const dietary = params.get('dietary')?.trim().toLowerCase();
  if (cuisine) return NextResponse.json({ success: false, error: 'Cuisine filtering is not supported by the current verified database schema.' }, { status: 422 });

  try {
    const supabase = await createClient();
    let providersQuery = supabase.from('providers')
      .select('id,display_name,slug,description,public_phone,public_email,address_line1,locality,city,state,pincode,latitude,longitude,status,created_at')
      .eq('status', 'active').order('display_name').limit(500);
    if (city) providersQuery = providersQuery.ilike('city', city.replace(/[\\%_]/g, '\\$&'));
    const [{ data: providers, error: providersError }, { data: menuMatches, error: menuError }] = await Promise.all([
      providersQuery,
      query ? supabase.from('menu_items').select('provider_id,name,dietary_type').eq('active', true).ilike('name', `%${query.replace(/[\\%_]/g, '\\$&')}%`).limit(1000) : Promise.resolve({ data: [], error: null }),
    ]);
    if (providersError || menuError) throw providersError || menuError;
    const matchingMenuIds = new Set((menuMatches ?? []).map((item) => item.provider_id));
    let filtered = (providers ?? []).filter((provider) => {
      if (!query) return true;
      const text = `${provider.display_name} ${provider.description || ''} ${provider.locality} ${provider.city} ${provider.state}`.toLowerCase();
      return text.includes(query.toLowerCase()) || matchingMenuIds.has(provider.id);
    });

    if (dietary) {
      const accepted = dietary === 'veg' ? ['vegetarian', 'vegan'] : dietary === 'non_veg' ? ['non_vegetarian'] : dietary === 'jain' ? ['jain'] : [dietary];
      const { data: dietaryItems, error } = await supabase.from('menu_items').select('provider_id')
        .eq('active', true).in('dietary_type', accepted).limit(1000);
      if (error) throw error;
      const providerIds = new Set((dietaryItems ?? []).map((item) => item.provider_id));
      filtered = filtered.filter((provider) => providerIds.has(provider.id));
    }

    const ids = filtered.map((provider) => provider.id);
    const [{ data: plans, error: plansError }, { data: slots, error: slotsError }] = ids.length ? await Promise.all([
      supabase.from('subscription_plans').select('id,provider_id,name,description,plan_type,duration_months,meal_credits,price_paise,currency,promo_price_paise,daily_meal_limit,published,active').in('provider_id', ids).eq('published', true).eq('active', true),
      supabase.from('meal_slots').select('id,provider_id,name,starts_at_local,ends_at_local,active').in('provider_id', ids).eq('active', true),
    ]) : [{ data: [], error: null }, { data: [], error: null }];
    if (plansError || slotsError) throw plansError || slotsError;

    const results = filtered.map((provider) => ({
      ...provider,
      rating: null,
      total_reviews: null,
      cuisines: [],
      dietary_types: [...new Set((menuMatches ?? []).filter((item) => item.provider_id === provider.id).map((item) => item.dietary_type))],
      distance_km: null,
      plans: (plans ?? []).filter((plan) => plan.provider_id === provider.id),
      meal_slots: (slots ?? []).filter((slot) => slot.provider_id === provider.id),
    }));

    return NextResponse.json({ success: true, total: results.length, providers: results }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Provider search failed:', error instanceof Error ? error.message : 'unknown error');
    return NextResponse.json({ success: false, error: 'Search is temporarily unavailable. Please retry.' }, { status: 503 });
  }
}
