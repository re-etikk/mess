import { NextRequest, NextResponse } from 'next/server';
import { platformStore, MenuData } from '@/lib/platform-service';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';
  const slot = searchParams.get('slot')?.toUpperCase();

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

    // Enforce Tenant Authorization / IDOR Protection
    const auth = await requireProviderOwnership(req, providerId);
    if (!auth.ok) {
      return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
    }

    const slot = (body.slot || 'LUNCH').toUpperCase();
    const dayOfWeek = body.day_of_week || 'Daily';
    const action = body.action || 'set_menu';

    const key = `${providerId}_${dayOfWeek}_${slot}`;
    let menu = platformStore.menus.get(key);

    if (!menu) {
      menu = {
        id: `menu-${providerId}-${slot.toLowerCase()}`,
        provider_id: providerId,
        day_of_week: dayOfWeek,
        slot,
        items_included: [],
        items_extra: [],
        items_unavailable: [],
        is_active: true,
        updated_at: new Date().toISOString(),
      };
    }

    if (action === 'add_item') {
      const itemName = (body.name || body.item_name)?.trim();
      const isExtra = body.is_extra === true || body.type === 'extra';
      const price = Number(body.price) || 0;

      if (!itemName) {
        return NextResponse.json({ success: false, error: 'Item name is required.' }, { status: 400 });
      }

      if (isExtra) {
        menu.items_extra = menu.items_extra.filter((i) => i.name.toLowerCase() !== itemName.toLowerCase());
        menu.items_extra.push({ name: itemName, price, limit: body.limit || 3, is_available: true });
      } else {
        if (!menu.items_included.some((i) => i.toLowerCase() === itemName.toLowerCase())) {
          menu.items_included.push(itemName);
        }
      }
      menu.updated_at = new Date().toISOString();
      platformStore.menus.set(key, menu);

      return NextResponse.json({
        success: true,
        menu,
        message: `✅ "${itemName}" added to ${slot} menu!`,
      });
    }

    if (action === 'remove_item') {
      const itemName = (body.name || body.item_name)?.trim();
      if (!itemName) {
        return NextResponse.json({ success: false, error: 'Item name is required.' }, { status: 400 });
      }

      menu.items_included = menu.items_included.filter((i) => i.toLowerCase() !== itemName.toLowerCase());
      menu.items_extra = menu.items_extra.filter((i) => i.name.toLowerCase() !== itemName.toLowerCase());
      menu.items_unavailable = (menu.items_unavailable || []).filter((i) => i.toLowerCase() !== itemName.toLowerCase());
      menu.updated_at = new Date().toISOString();
      platformStore.menus.set(key, menu);

      return NextResponse.json({
        success: true,
        menu,
        message: `🗑️ "${itemName}" removed from ${slot} menu.`,
      });
    }

    if (action === 'toggle_availability') {
      const itemName = (body.name || body.item_name)?.trim();
      if (!itemName) {
        return NextResponse.json({ success: false, error: 'Item name is required.' }, { status: 400 });
      }

      menu.items_unavailable = menu.items_unavailable || [];
      const isUnavailable = menu.items_unavailable.some((i) => i.toLowerCase() === itemName.toLowerCase());

      if (isUnavailable) {
        menu.items_unavailable = menu.items_unavailable.filter((i) => i.toLowerCase() !== itemName.toLowerCase());
      } else {
        menu.items_unavailable.push(itemName);
      }
      menu.updated_at = new Date().toISOString();
      platformStore.menus.set(key, menu);

      return NextResponse.json({
        success: true,
        menu,
        message: `Updated availability for "${itemName}".`,
      });
    }

    // Default: full replace
    const itemsIncluded = Array.isArray(body.items_included) ? body.items_included : menu.items_included;
    const itemsExtra = Array.isArray(body.items_extra) ? body.items_extra : menu.items_extra;

    menu.items_included = itemsIncluded;
    menu.items_extra = itemsExtra;
    menu.updated_at = new Date().toISOString();
    platformStore.menus.set(key, menu);

    return NextResponse.json({
      success: true,
      menu,
      message: `${slot} menu updated successfully!`,
    });
  } catch (err: any) {
    return NextResponse.json(
      { success: false, error: err.message || 'Failed to update menu' },
      { status: 500 }
    );
  }
}
