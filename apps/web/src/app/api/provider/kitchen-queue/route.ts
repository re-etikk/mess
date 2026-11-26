import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { getIndiaDateString } from '@/lib/crypto';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id')?.trim() || '';
  const serviceDate = params.get('date')?.trim() || getIndiaDateString();
  const slotFilter = (params.get('slot') || 'LUNCH').toUpperCase().trim();

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  let subs: any[] = [];
  let events: any[] = [];
  let supportsDelivery = false;

  if (admin) {
    try {
      const [subsRes, evRes, provRes] = await Promise.all([
        admin
          .from('subscriptions')
          .select('*, profiles:customer_id(id,display_name,phone_e164,default_address,default_locality)')
          .eq('provider_id', providerId)
          .eq('status', 'active')
          .order('created_at', { ascending: false }),
        admin
          .from('daily_meal_events')
          .select('*')
          .eq('provider_id', providerId)
          .eq('service_date', serviceDate)
          .then((r) => r, () => ({ data: [] as any[] })),
        admin
          .from('providers')
          .select('supports_delivery')
          .eq('id', providerId)
          .maybeSingle(),
      ]);
      subs = subsRes.data ?? [];
      events = (evRes as any)?.data ?? [];
      supportsDelivery = provRes?.data?.supports_delivery === true;
    } catch (e: any) {
      console.warn('provider/kitchen-queue GET error:', e?.message);
    }
  }

  if (subs.length === 0) {
    for (const s of platformStore.subscriptions.values()) {
      if (s.provider_id === providerId && s.status === 'active') {
        subs.push(s);
      }
    }
    for (const ev of platformStore.dailyMealEvents.values()) {
      if (ev.provider_id === providerId && ev.service_date === serviceDate) events.push(ev);
    }
  }

  const dowJs = new Date(`${serviceDate}T12:00:00+05:30`).getUTCDay();
  const dow1To7 = dowJs === 0 ? 7 : dowJs;

  const queue = subs
    .filter((s) => {
      const startIso = s.starts_at ? String(s.starts_at).slice(0, 10) : '';
      const endIso = s.expires_at ? String(s.expires_at).slice(0, 10) : '';
      if (startIso && serviceDate < startIso) return false;
      if (endIso && serviceDate > endIso) return false;

      if (s.selected_slots && typeof s.selected_slots === 'object' && Object.keys(s.selected_slots).length > 0) {
        const cfg = s.selected_slots[slotFilter.toLowerCase()];
        if (!cfg || (typeof cfg === 'object' && cfg.enabled === false)) return false;
      }

      const rDays = Array.isArray(s.repeat_days) && s.repeat_days.length > 0 ? s.repeat_days.map((x: any) => Number(x)) : [1, 2, 3, 4, 5, 6, 7];
      return rDays.includes(dow1To7);
    })
    .map((s) => {
      const profile = Array.isArray(s.profiles) ? s.profiles[0] : s.profiles;
      const ev = events.find((e) => e.subscription_id === s.id && e.slot === slotFilter);
      const slotCfg = s.selected_slots?.[slotFilter.toLowerCase()] || {};
      const fMode =
        ev?.fulfillment_mode ||
        s.fulfillment_mode ||
        (s.packaging_preference === 'dine_in' ? 'pickup' : (supportsDelivery ? 'delivery' : 'pickup'));
      const dropAddr =
        ev?.delivery_address ||
        s.delivery_address ||
        [profile?.default_address, profile?.default_locality].filter(Boolean).join(', ');
      return {
        subscription_id: s.id,
        customer_id: s.customer_id,
        customer_name: profile?.display_name || s.customer_name || 'Subscriber',
        customer_phone: profile?.phone_e164 || s.customer_phone || '',
        plan_name: s.plan_name_snapshot || s.plan_name || 'Plan',
        slot: slotFilter,
        service_date: serviceDate,
        status: ev?.status || 'scheduled',
        fulfillment_mode: fMode,
        delivery_address: dropAddr,
        rider_id: ev?.rider_id || null,
        rider_name: ev?.rider_name || null,
        rider_phone: ev?.rider_phone || null,
        rider_lat: ev?.rider_lat != null ? Number(ev.rider_lat) : null,
        rider_lng: ev?.rider_lng != null ? Number(ev.rider_lng) : null,
        rider_updated_at: ev?.rider_updated_at || null,
        eta_minutes: ev?.eta_minutes != null ? Number(ev.eta_minutes) : null,
        time_window: ev?.custom_time_slot || slotCfg.time_slot || '',
        instructions: ev?.instructions || s.delivery_instructions || '',
        packaging_preference: s.packaging_preference || 'reusable_tiffin',
        addons: ev?.addons_snapshot || slotCfg.addons || [],
      };
    });

  return NextResponse.json(
    {
      success: true,
      date: serviceDate,
      slot: slotFilter,
      supports_delivery: supportsDelivery,
      counts: {
        total: queue.length,
        scheduled: queue.filter((q) => q.status === 'scheduled').length,
        preparing: queue.filter((q) => q.status === 'preparing').length,
        out: queue.filter((q) => q.status === 'out_for_delivery' || q.status === 'ready_at_counter').length,
        delivered: queue.filter((q) => q.status === 'delivered').length,
        skipped: queue.filter((q) => q.status === 'skipped').length,
      },
      queue,
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = String(body.provider_id || '').trim();
  const subscriptionId = String(body.subscription_id || '').trim();
  const customerId = String(body.customer_id || '').trim();
  const serviceDate = String(body.service_date || getIndiaDateString()).trim();
  const slot = String(body.slot || 'LUNCH').toUpperCase().trim();
  const status = String(body.status || '').trim();
  const etaMinutes = body.eta_minutes != null ? Number(body.eta_minutes) : null;

  const allowed = ['scheduled', 'preparing', 'out_for_delivery', 'ready_at_counter', 'delivered', 'cancelled_by_kitchen'];
  if (!providerId || !subscriptionId || !customerId || !allowed.includes(status)) {
    return NextResponse.json(
      { success: false, error: 'provider_id, subscription_id, customer_id, and valid status are required.' },
      { status: 400 }
    );
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  const nowIso = new Date().toISOString();

  if (admin) {
    const { data: ownedSub } = await admin
      .from('subscriptions')
      .select('id')
      .eq('id', subscriptionId)
      .eq('provider_id', providerId)
      .maybeSingle();
    if (!ownedSub) {
      return NextResponse.json({ success: false, error: 'Subscription not found for this kitchen.' }, { status: 404 });
    }
    const { data: ev, error } = await admin
      .from('daily_meal_events')
      .upsert(
        {
          subscription_id: subscriptionId,
          customer_id: customerId,
          provider_id: providerId,
          service_date: serviceDate,
          slot,
          status,
          eta_minutes: etaMinutes,
          updated_at: nowIso,
        },
        { onConflict: 'subscription_id,service_date,slot' }
      )
      .select('*')
      .single();

    await admin
      .from('customer_notifications')
      .insert({
        customer_id: customerId,
        title: `${slot.slice(0, 1) + slot.slice(1).toLowerCase()} Update`,
        message: `Your meal status is now: ${status.replace(/_/g, ' ')}.`,
        notification_type: 'meal_redemption',
        action_route: '/meals',
      })
      .then(() => null, () => null);

    if (!error && ev) {
      return NextResponse.json({ success: true, event: ev });
    }
  }

  const memKey = `${subscriptionId}_${serviceDate}_${slot}`;
  const prev = platformStore.dailyMealEvents.get(memKey) || {};
  const ev = {
    ...prev,
    id: memKey,
    subscription_id: subscriptionId,
    customer_id: customerId,
    provider_id: providerId,
    service_date: serviceDate,
    slot,
    status,
    eta_minutes: etaMinutes,
    updated_at: nowIso,
  };
  platformStore.dailyMealEvents.set(memKey, ev);
  return NextResponse.json({ success: true, event: ev });
}
