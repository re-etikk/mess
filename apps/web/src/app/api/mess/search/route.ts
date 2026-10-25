import { NextRequest, NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const q = (searchParams.get('q') || '').toLowerCase().trim();
  const city = searchParams.get('city');

  let results = Array.from(platformStore.providers.values()).filter(
    (p) => p.status === 'active'
  );

  if (city) {
    results = results.filter((p) => p.city.toLowerCase() === city.toLowerCase());
  }

  if (q) {
    results = results.filter((p) => {
      const matchName = p.display_name.toLowerCase().includes(q);
      const matchLocality = p.locality.toLowerCase().includes(q);
      const matchDesc = p.description.toLowerCase().includes(q);

      // check if any menu items match
      const menus = Array.from(platformStore.menus.values()).filter((m) => m.provider_id === p.id);
      const matchMenu = menus.some((m) =>
        m.items_included.some((item) => item.toLowerCase().includes(q)) ||
        m.items_extra.some((extra) => extra.name.toLowerCase().includes(q))
      );

      return matchName || matchLocality || matchDesc || matchMenu;
    });
  }

  const enriched = results.map((provider) => {
    const plans = Array.from(platformStore.plans.values()).filter((plan) => plan.provider_id === provider.id && plan.is_active);
    const menus = Array.from(platformStore.menus.values()).filter((menu) => menu.provider_id === provider.id);
    return {
      ...provider,
      plans,
      menus,
    };
  });

  return NextResponse.json({
    success: true,
    total: enriched.length,
    providers: enriched,
  });
}
