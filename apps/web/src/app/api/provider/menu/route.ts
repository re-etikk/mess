import { NextRequest, NextResponse } from 'next/server';
import { platformStore, MenuData } from '@/lib/platform-service';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';
  const slot = searchParams.get('slot');

  let menus = Array.from(platformStore.menus.values()).filter(
    (m) => m.provider_id === providerId
  );

  if (slot) {
    menus = menus.filter((m) => m.slot === slot);
  }

  return NextResponse.json({
    success: true,
    menus,
  });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || 'prov-radhe-001';
    const slot = (body.slot || 'LUNCH').toUpperCase();
    const dayOfWeek = body.day_of_week || 'Daily';
    const itemsIncluded = Array.isArray(body.items_included) ? body.items_included : [];
    const itemsExtra = Array.isArray(body.items_extra) ? body.items_extra : [];

    const key = `${providerId}_${dayOfWeek}_${slot}`;
    const menuData: MenuData = {
      id: `menu-${providerId}-${slot.toLowerCase()}`,
      provider_id: providerId,
      day_of_week: dayOfWeek,
      slot,
      items_included: itemsIncluded,
      items_extra: itemsExtra,
      is_active: true,
      updated_at: new Date().toISOString(),
    };

    platformStore.menus.set(key, menuData);

    return NextResponse.json({
      success: true,
      menu: menuData,
      message: `${slot} menu updated successfully!`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to update menu' },
      { status: 500 }
    );
  }
}
