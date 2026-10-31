import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const q = (searchParams.get('q') || '').toLowerCase().trim();
  const city = searchParams.get('city');
  const cuisine = searchParams.get('cuisine')?.toLowerCase();
  const dietary = searchParams.get('dietary')?.toLowerCase();
  const sortBy = searchParams.get('sort') || 'rating'; // 'rating' | 'distance' | 'popular'

  // 1. Fetch active providers across persistent storage
  try {
    const admin = getAdminClient();
    if (admin) {
      // From Auth metadata
      try {
        const { data: usersData } = await admin.auth.admin.listUsers({ perPage: 100 });
        if (usersData?.users) {
          for (const u of usersData.users) {
            const meta = u.user_metadata || {};
            if (meta.role === 'provider' && meta.application && meta.application.status === 'active') {
              const app = meta.application;
              const pId = app.id || u.id;
              if (!platformStore.providers.has(pId)) {
                platformStore.providers.set(pId, {
                  id: pId,
                  owner_user_id: u.id,
                  display_name: app.display_name || 'Mess Partner',
                  slug: app.slug || `mess-${pId.slice(0, 6)}`,
                  description: app.description || 'Authentic homestyle daily meals.',
                  phone: app.public_phone || meta.phone || '',
                  email: u.email || `${pId}@thali.mess`,
                  address: `${app.address_line1}, ${app.locality ? app.locality + ', ' : ''}${app.city}`,
                  locality: app.locality || app.city,
                  city: app.city,
                  rating: 5.0,
                  total_reviews: 0,
                  cuisines: ['North Indian', 'Homestyle'],
                  dietary_types: ['veg'],
                  distance_km: 1.0,
                  status: 'active',
                  created_at: app.created_at || u.created_at,
                });
              }
            }
          }
        }
      } catch {}

      // From PostgreSQL providers table
      try {
        const { data: dbProviders } = await admin
          .from('providers')
          .select('id,owner_user_id,display_name,slug,description,public_phone,public_email,address_line1,locality,city,state,pincode,status,created_at')
          .eq('status', 'active');

        if (dbProviders && dbProviders.length > 0) {
          for (const dbP of dbProviders) {
            if (!platformStore.providers.has(dbP.id)) {
              platformStore.providers.set(dbP.id, {
                id: dbP.id,
                owner_user_id: dbP.owner_user_id,
                display_name: dbP.display_name,
                slug: dbP.slug,
                description: dbP.description || 'Authentic homestyle daily meals.',
                phone: dbP.public_phone,
                email: dbP.public_email || `${dbP.slug}@thali.mess`,
                address: `${dbP.address_line1}, ${dbP.locality ? dbP.locality + ', ' : ''}${dbP.city}`,
                locality: dbP.locality || dbP.city,
                city: dbP.city,
                rating: 5.0,
                total_reviews: 0,
                cuisines: ['North Indian', 'Homestyle'],
                dietary_types: ['veg'],
                distance_km: 1.0,
                status: 'active',
                created_at: dbP.created_at,
              });
            }
          }
        }
      } catch {}
    }
  } catch (err) {
    console.warn('Failed to query active providers for search:', err);
  }

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
    results.sort((a, b) => b.rating - a.rating);
  }

  const enriched = results.map((provider) => {
    const plans = Array.from(platformStore.plans.values()).filter((plan) => plan.provider_id === provider.id && plan.is_active);
    const menus = Array.from(platformStore.menus.values()).filter((menu) => menu.provider_id === provider.id);
    const reviews = Array.from(platformStore.reviews.values()).filter((r) => r.provider_id === provider.id);
    const timings = platformStore.timings.get(provider.id) || null;
    return {
      ...provider,
      plans,
      menus,
      reviews_preview: reviews.slice(0, 3),
      timings,
    };
  });

  return NextResponse.json({
    success: true,
    total: enriched.length,
    providers: enriched,
  });
}
