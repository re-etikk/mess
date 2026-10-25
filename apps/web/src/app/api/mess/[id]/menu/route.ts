import { NextRequest, NextResponse } from 'next/server';
import { platformStore, getCurrentMealSlot } from '@/lib/platform-service';

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const providerId = params.id;
  const { searchParams } = new URL(req.url);
  const slot = searchParams.get('slot') || getCurrentMealSlot();

  const provider = platformStore.providers.get(providerId);
  if (!provider) {
    return NextResponse.json(
      { success: false, error: 'Mess provider not found.' },
      { status: 404 }
    );
  }

  // Find slot menu or daily fallback
  const menuKey = `${providerId}_Daily_${slot}`;
  const menu = platformStore.menus.get(menuKey) || Array.from(platformStore.menus.values()).find(
    (m) => m.provider_id === providerId
  );

  return NextResponse.json({
    success: true,
    provider: {
      id: provider.id,
      name: provider.display_name,
      address: provider.address,
      phone: provider.phone,
    },
    slot,
    menu: menu || {
      slot,
      items_included: ['Dal Tadka', 'Rice', '4 Rotis', 'Sabzi'],
      items_extra: [
        { name: 'Paneer Butter Masala', price: 40 },
        { name: 'Extra Roti (2)', price: 15 },
      ],
    },
  });
}
