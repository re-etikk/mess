import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const q = (searchParams.get('q') || '').toLowerCase().trim();
  const city = searchParams.get('city');
  const cuisine = searchParams.get('cuisine')?.toLowerCase();
  const dietary = searchParams.get('dietary')?.toLowerCase();
  const sortBy = searchParams.get('sort') || 'rating'; // 'rating' | 'distance' | 'popular'

  let results = Array.from(platformStore.providers.values()).filter(
    (p) => p.status === 'active'
  );

  if (city) {
    results = results.filter((p) => p.city.toLowerCase() === city.toLowerCase());
  }

  if (dietary) {
    results = results.filter((p) =>
      p.dietary_types.some((d) => d.toLowerCase() === dietary)
    );
  }

  if (cuisine) {
    results = results.filter((p) =>
      p.cuisines.some((c) => c.toLowerCase().includes(cuisine))
    );
  }

  if (q) {
    results = results.filter((p) => {
      const matchName = p.display_name.toLowerCase().includes(q);
      const matchLocality = p.locality.toLowerCase().includes(q);
      const matchDesc = p.description.toLowerCase().includes(q);
      const matchCuisine = p.cuisines.some((c) => c.toLowerCase().includes(q));

      // check if any menu items match
      const menus = Array.from(platformStore.menus.values()).filter((m) => m.provider_id === p.id);
      const matchMenu = menus.some((m) =>
        m.items_included.some((item) => item.toLowerCase().includes(q)) ||
        m.items_extra.some((extra) => extra.name.toLowerCase().includes(q))
      );

      return matchName || matchLocality || matchDesc || matchCuisine || matchMenu;
    });
  }

  // Sorting
  if (sortBy === 'distance') {
    results.sort((a, b) => (a.distance_km ?? 99) - (b.distance_km ?? 99));
  } else if (sortBy === 'popular') {
    results.sort((a, b) => b.total_reviews - a.total_reviews);
  } else {
    // Default: rating high to low
    results.sort((a, b) => b.rating - a.rating);
  }

  const enriched = results.map((provider) => {
    const plans = Array.from(platformStore.plans.values()).filter((plan) => plan.provider_id === provider.id && plan.is_active);
    const menus = Array.from(platformStore.menus.values()).filter((menu) => menu.provider_id === provider.id);
    const reviews = Array.from(platformStore.reviews.values()).filter((r) => r.provider_id === provider.id);
    return {
      ...provider,
      plans,
      menus,
      reviews_preview: reviews.slice(0, 3),
    };
  });

  return NextResponse.json({
    success: true,
    total: enriched.length,
    providers: enriched,
  });
}
