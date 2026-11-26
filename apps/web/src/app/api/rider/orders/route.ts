import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { getIndiaDateString } from '@/lib/crypto';
import { addPartnerNotification } from '@/lib/partner-notifications';
import {
  getClientIp,
  requireRiderIdentity,
  signRiderToken,
  timingSafeStringEqual,
} from '@/lib/auth-session';
import { checkRateLimit } from '@/lib/rate-limiter';

export const dynamic = 'force-dynamic';

async function authenticateRiderWithPin(phoneRaw: string, pinRaw: string) {
  const phone10 = phoneRaw.replace(/\D/g, '').slice(-10);
  const pin = pinRaw.trim();
  if (phone10.length !== 10 || !/^\d{4}$/.test(pin)) return null;

  const admin = getAdminClient();
  if (admin) {
    try {
      const { data: candidates } = await admin
        .from('provider_riders')
        .select('*, providers:provider_id(id,display_name,locality,city,public_phone)')
        .eq('phone', phone10)
        .eq('is_active', true)
        .order('created_at', { ascending: false })
        .limit(5);

      for (const rider of candidates ?? []) {
        if (timingSafeStringEqual(String(rider.pin_code || ''), pin)) {
          return rider;
        }
      }
    } catch {}
  }

  for (const r of platformStore.providerRiders.values()) {
    if (
      String(r.phone || '').slice(-10) === phone10 &&
      r.is_active !== false &&
      timingSafeStringEqual(String(r.pin_code || ''), pin)
    ) {
      const prov = platformStore.providers.get(r.provider_id);
      return {
        ...r,
        providers: prov
          ? {
              id: prov.id,
              display_name: prov.display_name,
              locality: prov.locality,
              city: prov.city,
              public_phone: prov.phone,
            }
          : { id: r.provider_id, display_name: 'Mess Kitchen' },
      };
    }
  }
  return null;
}

export async function GET(req: NextRequest) {
  const auth = requireRiderIdentity(req);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  const params = new URL(req.url).searchParams;
  const slotFilter = (params.get('slot') || 'LUNCH').toUpperCase().trim();
  const serviceDate = params.get('date')?.trim() || getIndiaDateString();

  const providerId = auth.providerId;
  const admin = getAdminClient();

  let riderInfo: any = { id: auth.riderId, name: auth.name, phone: auth.phone };
  let providerInfo: any = { id: providerId, display_name: 'Mess Kitchen', locality: '', city: '', phone: '' };
  let subs: any[] = [];
  let events: any[] = [];

  if (admin) {
    const [riderRes, provRes, subsRes, evRes] = await Promise.all([
      admin
        .from('provider_riders')
        .select('id,name,phone,is_active,last_lat,last_lng,last_location_at')
        .eq('id', auth.riderId)
        .eq('provider_id', providerId)
        .maybeSingle(),
      admin.from('providers').select('id,display_name,locality,city,public_phone').eq('id', providerId).maybeSingle(),
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

    if (!riderRes.data || riderRes.data.is_active === false) {
      return NextResponse.json({ success: false, error: 'Rider access has been revoked.' }, { status: 401 });
    }
    riderInfo = riderRes.data;
    if (provRes.data) {
      providerInfo = {
        id: provRes.data.id,
        display_name: provRes.data.display_name,
        locality: provRes.data.locality || '',
        city: provRes.data.city || '',
        phone: provRes.data.public_phone || '',
      };
    }
    subs = subsRes.data ?? [];
    events = (evRes as any)?.data ?? [];
  } else {
    const rMem = platformStore.providerRiders.get(auth.riderId);
    if (!rMem || rMem.is_active === false) {
      return NextResponse.json({ success: false, error: 'Rider access has been revoked.' }, { status: 401 });
    }
    riderInfo = rMem;
    const pMem = platformStore.providers.get(providerId);
    if (pMem) {
      providerInfo = {
        id: pMem.id,
        display_name: pMem.display_name,
        locality: pMem.locality || '',
        city: pMem.city || '',
        phone: pMem.phone || '',
      };
    }
    for (const s of platformStore.subscriptions.values()) {
      if (s.provider_id === providerId && s.status === 'active') subs.push(s);
    }
    for (const ev of platformStore.dailyMealEvents.values()) {
      if (ev.provider_id === providerId && ev.service_date === serviceDate) events.push(ev);
    }
  }

  const dowJs = new Date(`${serviceDate}T12:00:00+05:30`).getUTCDay();
  const dow1To7 = dowJs === 0 ? 7 : dowJs;
  const serviceStartMs = new Date(`${serviceDate}T23:59:59+05:30`).getTime();
  const serviceEndMs = new Date(`${serviceDate}T00:00:00+05:30`).getTime();

  const orders = subs
    .filter((s) => {
      if (s.starts_at && new Date(s.starts_at).getTime() > serviceStartMs) return false;
      if (s.expires_at && new Date(s.expires_at).getTime() < serviceEndMs) return false;
      const cfg = s.selected_slots;
      if (cfg && typeof cfg === 'object' && Object.keys(cfg).length > 0 && !cfg[slotFilter.toLowerCase()]) {
        return false;
      }
      const rDays =
        Array.isArray(s.repeat_days) && s.repeat_days.length > 0
          ? s.repeat_days.map((x: any) => Number(x))
          : [1, 2, 3, 4, 5, 6, 7];
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
        eta_minutes: ev?.eta_minutes ?? null,
        instructions: ev?.instructions || s.delivery_instructions || '',
        packaging_preference: s.packaging_preference || 'reusable_tiffin',
        rider_id: ev?.rider_id || null,
        rider_name: ev?.rider_name || null,
      };
    })
    .filter(
      (item) =>
        item.fulfillment_mode === 'delivery' &&
        item.status !== 'skipped' &&
        item.status !== 'cancelled_by_kitchen' &&
        (!item.rider_id || item.rider_id === auth.riderId)
    );

  return NextResponse.json(
    {
      success: true,
      date: serviceDate,
      slot: slotFilter,
      rider: {
        id: riderInfo.id,
        name: riderInfo.name,
        phone: riderInfo.phone,
        last_lat: riderInfo.last_lat ?? null,
        last_lng: riderInfo.last_lng ?? null,
        last_location_at: riderInfo.last_location_at ?? null,
      },
      provider: providerInfo,
      orders,
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const action = String(body.action || '').trim();

  if (action === 'login') {
    const phone = String(body.phone || '').trim();
    const pin = String(body.pin || '').trim();
    const phone10 = phone.replace(/\D/g, '').slice(-10);

    const rl = checkRateLimit(`rider_login:${getClientIp(req)}:${phone10 || 'unknown'}`, 8, 15 * 60 * 1000);
    if (!rl.isAllowed) {
      return NextResponse.json(
        { success: false, error: 'Too many login attempts. Wait 15 minutes and retry.' },
        { status: 429 }
      );
    }

    const rider = await authenticateRiderWithPin(phone, pin);
    if (!rider) {
      return NextResponse.json({ success: false, error: 'Invalid mobile number or 4-digit staff PIN.' }, { status: 401 });
    }

    const provider = Array.isArray(rider.providers) ? rider.providers[0] : rider.providers;
    const riderToken = signRiderToken({
      riderId: rider.id,
      providerId: rider.provider_id,
      phone: rider.phone,
      name: rider.name,
    });

    return NextResponse.json(
      {
        success: true,
        rider_token: riderToken,
        rider: { id: rider.id, name: rider.name, phone: rider.phone, provider_id: rider.provider_id },
        provider: {
          id: rider.provider_id,
          display_name: provider?.display_name || 'Mess Kitchen',
          locality: provider?.locality || '',
          city: provider?.city || '',
        },
      },
      { headers: { 'Cache-Control': 'no-store' } }
    );
  }

  // Authenticated rider session required for GPS updates and status transitions
  const auth = requireRiderIdentity(req);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  const admin = getAdminClient();
  const nowIso = new Date().toISOString();

  if (action === 'location_ping') {
    const lat = Number(body.lat);
    const lng = Number(body.lng);
    if (!isFinite(lat) || !isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return NextResponse.json({ success: false, error: 'Valid GPS coordinates are required.' }, { status: 400 });
    }
    if (admin) {
      await admin
        .from('provider_riders')
        .update({ last_lat: lat, last_lng: lng, last_location_at: nowIso, updated_at: nowIso })
        .eq('id', auth.riderId)
        .eq('provider_id', auth.providerId);

      // Update rider-assigned active deliveries OR unassigned out_for_delivery orders for this kitchen
      await admin
        .from('daily_meal_events')
        .update({ rider_lat: lat, rider_lng: lng, rider_updated_at: nowIso })
        .eq('provider_id', auth.providerId)
        .eq('status', 'out_for_delivery')
        .or(`rider_id.eq.${auth.riderId},rider_id.is.null`);
    } else {
      const rMem = platformStore.providerRiders.get(auth.riderId);
      if (rMem) {
        rMem.last_lat = lat;
        rMem.last_lng = lng;
        rMem.last_location_at = nowIso;
      }
      for (const ev of platformStore.dailyMealEvents.values()) {
        if (
          ev.provider_id === auth.providerId &&
          ev.status === 'out_for_delivery' &&
          (!ev.rider_id || ev.rider_id === auth.riderId)
        ) {
          ev.rider_lat = lat;
          ev.rider_lng = lng;
          ev.rider_updated_at = nowIso;
        }
      }
    }
    return NextResponse.json({ success: true, updated_at: nowIso });
  }

  if (action === 'update_status') {
    const subscriptionId = String(body.subscription_id || '').trim();
    const customerId = String(body.customer_id || '').trim();
    const slot = String(body.slot || 'LUNCH').toUpperCase().trim();
    const serviceDate = String(body.service_date || getIndiaDateString()).trim();
    const status = String(body.status || '').trim();
    const etaMinutes = body.eta_minutes != null ? Number(body.eta_minutes) : status === 'out_for_delivery' ? 20 : null;
    const lat = body.lat != null && isFinite(Number(body.lat)) ? Number(body.lat) : null;
    const lng = body.lng != null && isFinite(Number(body.lng)) ? Number(body.lng) : null;

    if (!subscriptionId || !customerId || !['out_for_delivery', 'delivered'].includes(status)) {
      return NextResponse.json({ success: false, error: 'Invalid status update payload.' }, { status: 400 });
    }

    if (admin) {
      // Strictly verify the subscription belongs to the rider's kitchen & specified customer
      const { data: subRow } = await admin
        .from('subscriptions')
        .select('id,provider_id,customer_id')
        .eq('id', subscriptionId)
        .eq('provider_id', auth.providerId)
        .eq('customer_id', customerId)
        .maybeSingle();
      if (!subRow) {
        return NextResponse.json({ success: false, error: 'Order not found for your kitchen.' }, { status: 404 });
      }

      const { data: existingEv } = await admin
        .from('daily_meal_events')
        .select('rider_id')
        .eq('subscription_id', subscriptionId)
        .eq('service_date', serviceDate)
        .eq('slot', slot)
        .maybeSingle();
      if (existingEv?.rider_id && existingEv.rider_id !== auth.riderId) {
        return NextResponse.json({ success: false, error: 'This delivery is assigned to another rider.' }, { status: 403 });
      }

      await admin.from('daily_meal_events').upsert(
        {
          subscription_id: subscriptionId,
          customer_id: customerId,
          provider_id: auth.providerId,
          service_date: serviceDate,
          slot,
          status,
          fulfillment_mode: 'delivery',
          eta_minutes: etaMinutes,
          rider_id: auth.riderId,
          rider_name: auth.name,
          rider_phone: auth.phone,
          ...(lat != null ? { rider_lat: lat } : {}),
          ...(lng != null ? { rider_lng: lng } : {}),
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
              ? `${auth.name} is on the way with your ${slot.toLowerCase()} tiffin${etaMinutes ? ` (~${etaMinutes} mins)` : ''}.`
              : `Your ${slot.toLowerCase()} tiffin has been delivered by ${auth.name}.`,
          notification_type: 'meal_redemption',
          action_route: '/meals',
        })
        .then(() => null, () => null);
    } else {
      const subMem = platformStore.subscriptions.get(subscriptionId);
      if (!subMem || subMem.provider_id !== auth.providerId || subMem.customer_id !== customerId) {
        return NextResponse.json({ success: false, error: 'Order not found for your kitchen.' }, { status: 404 });
      }
      const memKey = `${subscriptionId}_${serviceDate}_${slot}`;
      const prev = platformStore.dailyMealEvents.get(memKey) || {};
      if (prev.rider_id && prev.rider_id !== auth.riderId) {
        return NextResponse.json({ success: false, error: 'This delivery is assigned to another rider.' }, { status: 403 });
      }
      platformStore.dailyMealEvents.set(memKey, {
        ...prev,
        id: memKey,
        subscription_id: subscriptionId,
        customer_id: customerId,
        provider_id: auth.providerId,
        service_date: serviceDate,
        slot,
        status,
        fulfillment_mode: 'delivery',
        eta_minutes: etaMinutes,
        rider_id: auth.riderId,
        rider_name: auth.name,
        rider_phone: auth.phone,
        rider_lat: lat,
        rider_lng: lng,
        rider_updated_at: nowIso,
        updated_at: nowIso,
      });
    }

    addPartnerNotification({
      provider_id: auth.providerId,
      type: 'info',
      title: status === 'out_for_delivery' ? 'Rider Started Delivery' : 'Tiffin Delivered by Staff',
      message: `${auth.name} marked ${slot.toLowerCase()} order as ${status.replace(/_/g, ' ')}.`,
      subscription_id: subscriptionId,
    });

    return NextResponse.json({ success: true, status, updated_at: nowIso });
  }

  return NextResponse.json({ success: false, error: 'Unsupported action.' }, { status: 400 });
}
