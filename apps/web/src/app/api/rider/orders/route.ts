import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { getIndiaDateString } from '@/lib/crypto';
import { addPartnerNotification } from '@/lib/partner-notifications';

export const dynamic = 'force-dynamic';

async function resolveRider(phoneRaw: string, pinRaw: string) {
  const phone10 = phoneRaw.replace(/\D/g, '').slice(-10);
  const pin = pinRaw.trim();
  if (phone10.length !== 10 || pin.length < 4) return null;

  const admin = getAdminClient();
  if (admin) {
    try {
      const { data: rider } = await admin
        .from('provider_riders')
        .select('*, providers:provider_id(id,display_name,locality,city,public_phone)')
        .eq('phone', phone10)
        .eq('pin_code', pin)
        .eq('is_active', true)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      if (rider) return rider;
    } catch {}
  }

  for (const r of platformStore.providerRiders.values()) {
    if (String(r.phone).slice(-10) === phone10 && r.pin_code === pin && r.is_active !== false) {
      const prov = platformStore.providers.get(r.provider_id);
      return {
        ...r,
        providers: prov
          ? { id: prov.id, display_name: prov.display_name, locality: prov.locality, city: prov.city, public_phone: prov.phone }
          : { id: r.provider_id, display_name: 'Mess Kitchen' },
      };
    }
  }
  return null;
}

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const phone = params.get('phone')?.trim() || '';
  const pin = params.get('pin')?.trim() || '';
  const slotFilter = (params.get('slot') || 'LUNCH').toUpperCase().trim();
  const serviceDate = params.get('date')?.trim() || getIndiaDateString();

  const rider = await resolveRider(phone, pin);
  if (!rider) {
    return NextResponse.json({ success: false, error: 'Invalid mobile number or 4-digit staff PIN.' }, { status: 401 });
  }

  const provider = Array.isArray(rider.providers) ? rider.providers[0] : rider.providers;
  const providerId = rider.provider_id;
  const admin = getAdminClient();

  let subs: any[] = [];
  let events: any[] = [];

  if (admin) {
    const [subsRes, evRes] = await Promise.all([
      admin
        .from('subscriptions')
        .select('*, profiles:customer_id(id,display_name,phone_e164,default_address,default_locality,default_city,latitude,longitude)')
        .eq('provider_id', providerId)
        .eq('status', 'active')
        .order('created_at', { ascending: false }),
      admin
        .from('daily_meal_events')
        .select('*')
        .eq('provider_id', providerId)
        .eq('service_date', serviceDate)
        .then((r) => r, () => ({ data: [] as any[] })),
    ]);
    subs = subsRes.data ?? [];
    events = (evRes as any)?.data ?? [];
  } else {
    for (const s of platformStore.subscriptions.values()) {
      if (s.provider_id === providerId && s.status === 'active') subs.push(s);
    }
    for (const ev of platformStore.dailyMealEvents.values()) {
      if (ev.provider_id === providerId && ev.service_date === serviceDate) events.push(ev);
    }
  }

  const dowJs = new Date(`${serviceDate}T12:00:00+05:30`).getUTCDay();
  const dow1To7 = dowJs === 0 ? 7 : dowJs;

  const orders = subs
    .filter((s) => {
      const rDays = Array.isArray(s.repeat_days) && s.repeat_days.length > 0 ? s.repeat_days.map((x: any) => Number(x)) : [1, 2, 3, 4, 5, 6, 7];
      return rDays.includes(dow1To7);
    })
    .map((s) => {
      const profile = Array.isArray(s.profiles) ? s.profiles[0] : s.profiles;
      const ev = events.find((e) => e.subscription_id === s.id && e.slot === slotFilter);
      const fulfillmentMode =
        ev?.fulfillment_mode ||
        s.fulfillment_mode ||
        (s.packaging_preference === 'dine_in' ? 'pickup' : 'delivery');

      return {
        subscription_id: s.id,
        customer_id: s.customer_id,
        customer_name: profile?.display_name || s.customer_name || 'Subscriber',
        customer_phone: profile?.phone_e164 || s.customer_phone || '',
        address:
          ev?.delivery_address ||
          s.delivery_address ||
          [profile?.default_address, profile?.default_locality, profile?.default_city].filter(Boolean).join(', ') ||
          'Address not set',
        lat: profile?.latitude ? Number(profile.latitude) : null,
        lng: profile?.longitude ? Number(profile.longitude) : null,
        slot: slotFilter,
        service_date: serviceDate,
        status: ev?.status || 'scheduled',
        fulfillment_mode: fulfillmentMode,
        instructions: ev?.instructions || s.delivery_instructions || '',
        packaging_preference: s.packaging_preference || 'reusable_tiffin',
        rider_id: ev?.rider_id || null,
        rider_name: ev?.rider_name || null,
      };
    })
    .filter((item) => item.fulfillment_mode === 'delivery' && item.status !== 'skipped' && item.status !== 'cancelled_by_kitchen');

  return NextResponse.json(
    {
      success: true,
      date: serviceDate,
      slot: slotFilter,
      rider: {
        id: rider.id,
        name: rider.name,
        phone: rider.phone,
        last_lat: rider.last_lat,
        last_lng: rider.last_lng,
        last_location_at: rider.last_location_at,
      },
      provider: {
        id: providerId,
        display_name: provider?.display_name || 'Mess Kitchen',
        locality: provider?.locality || '',
        city: provider?.city || '',
        phone: provider?.public_phone || '',
      },
      orders,
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const action = String(body.action || '').trim(); // 'login' | 'update_status' | 'location_ping'
  const phone = String(body.phone || '').trim();
  const pin = String(body.pin || '').trim();

  const rider = await resolveRider(phone, pin);
  if (!rider) {
    return NextResponse.json({ success: false, error: 'Invalid mobile number or 4-digit staff PIN.' }, { status: 401 });
  }

  const provider = Array.isArray(rider.providers) ? rider.providers[0] : rider.providers;
  const admin = getAdminClient();
  const nowIso = new Date().toISOString();

  if (action === 'login') {
    return NextResponse.json({
      success: true,
      rider: { id: rider.id, name: rider.name, phone: rider.phone, provider_id: rider.provider_id },
      provider: {
        id: rider.provider_id,
        display_name: provider?.display_name || 'Mess Kitchen',
        locality: provider?.locality || '',
        city: provider?.city || '',
      },
    });
  }

  if (action === 'location_ping') {
    const lat = Number(body.lat);
    const lng = Number(body.lng);
    if (!isFinite(lat) || !isFinite(lng)) {
      return NextResponse.json({ success: false, error: 'Valid GPS coordinates are required.' }, { status: 400 });
    }
    if (admin) {
      await admin
        .from('provider_riders')
        .update({ last_lat: lat, last_lng: lng, last_location_at: nowIso, updated_at: nowIso })
        .eq('id', rider.id);

      await admin
        .from('daily_meal_events')
        .update({ rider_lat: lat, rider_lng: lng, rider_updated_at: nowIso })
        .eq('provider_id', rider.provider_id)
        .eq('rider_id', rider.id)
        .eq('status', 'out_for_delivery');
    }
    return NextResponse.json({ success: true, updated_at: nowIso });
  }

  if (action === 'update_status') {
    const subscriptionId = String(body.subscription_id || '').trim();
    const customerId = String(body.customer_id || '').trim();
    const slot = String(body.slot || 'LUNCH').toUpperCase().trim();
    const serviceDate = String(body.service_date || getIndiaDateString()).trim();
    const status = String(body.status || '').trim();
    const etaMinutes = body.eta_minutes != null ? Number(body.eta_minutes) : (status === 'out_for_delivery' ? 20 : null);
    const lat = body.lat != null ? Number(body.lat) : rider.last_lat ?? null;
    const lng = body.lng != null ? Number(body.lng) : rider.last_lng ?? null;

    if (!subscriptionId || !customerId || !['out_for_delivery', 'delivered'].includes(status)) {
      return NextResponse.json({ success: false, error: 'Invalid status update payload.' }, { status: 400 });
    }

    if (admin) {
      await admin.from('daily_meal_events').upsert(
        {
          subscription_id: subscriptionId,
          customer_id: customerId,
          provider_id: rider.provider_id,
          service_date: serviceDate,
          slot,
          status,
          fulfillment_mode: 'delivery',
          eta_minutes: etaMinutes,
          rider_id: rider.id,
          rider_name: rider.name,
          rider_phone: rider.phone,
          rider_lat: lat,
          rider_lng: lng,
          rider_updated_at: nowIso,
          updated_at: nowIso,
        },
        { onConflict: 'subscription_id,service_date,slot' }
      );

      await admin
        .from('customer_notifications')
        .insert({
          customer_id: customerId,
          title: status === 'out_for_delivery' ? 'Tiffin Out for Delivery' : 'Tiffin Delivered',
          message:
            status === 'out_for_delivery'
              ? `${rider.name} is on the way with your ${slot.toLowerCase()} tiffin${etaMinutes ? ` (~${etaMinutes} mins)` : ''}.`
              : `Your ${slot.toLowerCase()} tiffin has been delivered by ${rider.name}.`,
          notification_type: 'meal_redemption',
          action_route: '/meals',
        })
        .then(() => null, () => null);
    }

    addPartnerNotification({
      provider_id: rider.provider_id,
      type: 'info',
      title: status === 'out_for_delivery' ? 'Rider Started Delivery' : 'Tiffin Delivered by Staff',
      message: `${rider.name} marked ${slot.toLowerCase()} order as ${status.replace(/_/g, ' ')}.`,
      subscription_id: subscriptionId,
    });

    return NextResponse.json({ success: true, status, updated_at: nowIso });
  }

  return NextResponse.json({ success: false, error: 'Unsupported action.' }, { status: 400 });
}
