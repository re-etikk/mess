import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { getIndiaDateString } from '@/lib/crypto';
import { addPartnerNotification } from '@/lib/partner-notifications';
import { requireCustomerIdentity } from '@/lib/auth-session';

export const dynamic = 'force-dynamic';
export const fetchCache = 'force-no-store';

function isoDayOfWeek1To7(dateStr: string): number {
  const d = new Date(`${dateStr}T12:00:00+05:30`);
  const day = d.getUTCDay();
  return day === 0 ? 7 : day;
}

function addDays(dateStr: string, offset: number): string {
  const d = new Date(`${dateStr}T12:00:00+05:30`);
  d.setUTCDate(d.getUTCDate() + offset);
  return d.toISOString().slice(0, 10);
}

function displayClock(val?: string | null): string {
  if (!val) return '';
  const [hStr, mStr] = val.split(':');
  const h = Number(hStr);
  if (isNaN(h)) return val;
  const suf = h >= 12 ? 'PM' : 'AM';
  const h12 = h % 12 || 12;
  return `${h12}:${(mStr || '00').slice(0, 2)} ${suf}`;
}

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const customerIdParam = params.get('customer_id')?.trim() || '';
  const dateStr = params.get('date')?.trim() || getIndiaDateString();

  if (!customerIdParam) {
    return NextResponse.json({ success: false, error: 'customer_id is required.' }, { status: 400 });
  }

  const auth = await requireCustomerIdentity(req, customerIdParam);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }
  const customerId = auth.userId;

  const admin = getAdminClient();
  let subs: any[] = [];
  let events: any[] = [];
  let redemptions: any[] = [];
  let providerSlots: any[] = [];
  let providerMenuItems: any[] = [];

  if (admin) {
    try {
      const { data: dbSubs } = await admin
        .from('subscriptions')
        .select('*, providers:provider_id(id,display_name,locality,city,public_phone,latitude,longitude,supports_pickup,supports_delivery)')
        .eq('customer_id', customerId)
        .in('status', ['active', 'paused'])
        .order('created_at', { ascending: false });

      subs = dbSubs ?? [];

      if (subs.length > 0) {
        const providerIds = Array.from(new Set(subs.map((s) => s.provider_id)));
        const weekStart = addDays(dateStr, -3);
        const weekEnd = addDays(dateStr, 6);

        const [evRes, redRes, slotsRes, itemsRes] = await Promise.all([
          admin
            .from('daily_meal_events')
            .select('*')
            .eq('customer_id', customerId)
            .gte('service_date', weekStart)
            .lte('service_date', weekEnd)
            .then((r) => r, () => ({ data: [] as any[] })),
          admin
            .from('meal_redemptions')
            .select('id,provider_id,redeemed_at,meal_bookings(service_date,meal_slots(name))')
            .eq('customer_id', customerId)
            .order('redeemed_at', { ascending: false })
            .limit(40)
            .then((r) => r, () => ({ data: [] as any[] })),
          admin.from('meal_slots').select('*').in('provider_id', providerIds).eq('active', true),
          admin.from('menu_items').select('*').in('provider_id', providerIds).eq('active', true),
        ]);

        events = (evRes as any)?.data ?? [];
        redemptions = (redRes as any)?.data ?? [];
        providerSlots = (slotsRes.data ?? []).filter((s: any) => String(s.name || '').trim().toLowerCase() !== 'all');
        providerMenuItems = itemsRes.data ?? [];
      }
    } catch (e: any) {
      console.warn('customer/meals GET error:', e?.message);
    }
  }

  if (subs.length === 0) {
    for (const s of platformStore.subscriptions.values()) {
      if (s.customer_id === customerId && (s.status === 'active' || (s as any).status === 'paused')) {
        const prov = platformStore.providers.get(s.provider_id);
        subs.push({
          ...s,
          providers: prov
            ? { id: prov.id, display_name: prov.display_name, locality: prov.locality, city: prov.city, public_phone: prov.phone }
            : { id: s.provider_id, display_name: 'Mess Partner' },
        });
      }
    }
    for (const ev of platformStore.dailyMealEvents.values()) {
      if (ev.customer_id === customerId) events.push(ev);
    }
  }

  if (subs.length === 0) {
    return NextResponse.json({
      success: true,
      date: dateStr,
      has_active_subscription: false,
      is_break_day: true,
      week_days: [],
      meals: [],
    });
  }

  const primarySub = subs[0];
  const provider = Array.isArray(primarySub.providers) ? primarySub.providers[0] : primarySub.providers;
  const repeatDays: number[] =
    Array.isArray(primarySub.repeat_days) && primarySub.repeat_days.length > 0
      ? primarySub.repeat_days.map((n: any) => Number(n))
      : [1, 2, 3, 4, 5, 6, 7];

  const isPausedOnDate = (dStr: string) => {
    if (primarySub.status === 'paused') {
      const pStart = primarySub.pause_started_at || primarySub.pause_starts_at;
      if (pStart && primarySub.pause_ends_at) {
        return dStr >= pStart.slice(0, 10) && dStr <= primarySub.pause_ends_at.slice(0, 10);
      }
      return true;
    }
    return false;
  };

  const dow = isoDayOfWeek1To7(dateStr);
  const mondayStr = addDays(dateStr, -(dow - 1));
  const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const weekDays = dayNames.map((label, idx) => {
    const dIso = addDays(mondayStr, idx);
    const dNum = idx + 1;
    const dayEvents = events.filter((e) => e.service_date === dIso);
    const hasSkip = dayEvents.some((e) => e.status === 'skipped');
    const allDelivered = dayEvents.length > 0 && dayEvents.every((e) => e.status === 'delivered');
    const isOff = !repeatDays.includes(dNum) || isPausedOnDate(dIso);

    let indicator = 'scheduled';
    if (isOff) indicator = 'break_day';
    else if (allDelivered) indicator = 'completed';
    else if (hasSkip) indicator = 'skipped';

    return {
      date: dIso,
      day_label: label,
      day_number: Number(dIso.slice(8, 10)),
      is_selected: dIso === dateStr,
      indicator,
    };
  });

  const targetDow = isoDayOfWeek1To7(dateStr);
  const startDateIso = primarySub.starts_at ? String(primarySub.starts_at).slice(0, 10) : '';
  const endDateIso = primarySub.expires_at ? String(primarySub.expires_at).slice(0, 10) : '';
  const outsideValidity = Boolean((startDateIso && dateStr < startDateIso) || (endDateIso && dateStr > endDateIso));
  const isBreakDay = outsideValidity || !repeatDays.includes(targetDow) || isPausedOnDate(dateStr);

  if (isBreakDay) {
    return NextResponse.json({
      success: true,
      date: dateStr,
      has_active_subscription: true,
      subscription_id: primarySub.id,
      is_break_day: true,
      is_paused: isPausedOnDate(dateStr),
      week_days: weekDays,
      meals: [],
    });
  }

  const slotDefs =
    providerSlots.length > 0
      ? providerSlots
      : [
          { id: 'breakfast', name: 'BREAKFAST', starts_at_local: '07:30:00', ends_at_local: '09:30:00', booking_cutoff_minutes: 90 },
          { id: 'lunch', name: 'LUNCH', starts_at_local: '12:00:00', ends_at_local: '14:00:00', booking_cutoff_minutes: 90 },
          { id: 'dinner', name: 'DINNER', starts_at_local: '19:30:00', ends_at_local: '21:30:00', booking_cutoff_minutes: 90 },
        ];

  const selectedSlotsConfig: Record<string, any> =
    primarySub.selected_slots && typeof primarySub.selected_slots === 'object' ? primarySub.selected_slots : {};
  const hasSlotSelection = Object.keys(selectedSlotsConfig).length > 0;

  const activeSlotDefs = hasSlotSelection
    ? slotDefs.filter((slotRow) => {
        const key = String(slotRow.name || '').toLowerCase();
        return Boolean(selectedSlotsConfig[key]);
      })
    : slotDefs;

  const meals = (activeSlotDefs.length > 0 ? activeSlotDefs : slotDefs).map((slotRow) => {
    const slotUpper = String(slotRow.name || '').toUpperCase();
    const slotKey = slotUpper.toLowerCase();
    const ev = events.find((e) => e.subscription_id === primarySub.id && e.service_date === dateStr && e.slot === slotUpper);
    const redeemed = redemptions.some(
      (r: any) =>
        r.meal_bookings?.service_date === dateStr &&
        String(r.meal_bookings?.meal_slots?.name || '').toUpperCase() === slotUpper
    );

    const slotMenuItems = providerMenuItems
      .filter((i: any) => !i.is_add_on && (i.meal_slot_id === slotRow.id || (i.description || '').toLowerCase().includes(slotKey)))
      .map((i: any) => i.name);

    const storeMenu = platformStore.menus.get(`${primarySub.provider_id}_Daily_${slotUpper}`);
    const itemsSummary =
      slotMenuItems.length > 0
        ? slotMenuItems.join(' · ')
        : storeMenu?.items_included?.join(' · ') || 'Menu not published yet';

    const preferredWindow =
      ev?.custom_time_slot ||
      selectedSlotsConfig[slotKey]?.time_slot ||
      `${displayClock(slotRow.starts_at_local)} - ${displayClock(slotRow.ends_at_local)}`;

    const status = redeemed ? 'delivered' : ev?.status || 'scheduled';

    const effectiveFulfillment =
      ev?.fulfillment_mode ||
      primarySub.fulfillment_mode ||
      (primarySub.packaging_preference === 'dine_in'
        ? 'pickup'
        : provider?.supports_delivery === true
          ? 'delivery'
          : 'pickup');

    return {
      id: ev?.id || `${primarySub.id}_${dateStr}_${slotUpper}`,
      subscription_id: primarySub.id,
      provider_id: primarySub.provider_id,
      provider_name: provider?.display_name || 'Mess Partner',
      provider_locality: provider?.locality || '',
      provider_phone: provider?.public_phone || '',
      provider_lat: provider?.latitude ? Number(provider.latitude) : null,
      provider_lng: provider?.longitude ? Number(provider.longitude) : null,
      supports_delivery: provider?.supports_delivery === true,
      service_date: dateStr,
      slot: slotUpper,
      slot_label: slotUpper.slice(0, 1) + slotUpper.slice(1).toLowerCase(),
      menu_summary: itemsSummary,
      time_window: preferredWindow,
      status,
      fulfillment_mode: effectiveFulfillment,
      instructions: ev?.instructions || primarySub.delivery_instructions || '',
      eta_minutes: ev?.eta_minutes || null,
      rider_name: ev?.rider_name || null,
      rider_phone: ev?.rider_phone || null,
      rider_lat: ev?.rider_lat != null ? Number(ev.rider_lat) : null,
      rider_lng: ev?.rider_lng != null ? Number(ev.rider_lng) : null,
      rider_updated_at: ev?.rider_updated_at || null,
      cutoff_time: displayClock(slotRow.starts_at_local),
    };
  });

  const skipAllowance = Number(primarySub.skip_allowance ?? 2);
  const skipsUsed = Number(primarySub.skips_used ?? 0);

  return NextResponse.json(
    {
      success: true,
      date: dateStr,
      has_active_subscription: true,
      subscription_id: primarySub.id,
      provider_id: primarySub.provider_id,
      provider_name: provider?.display_name || 'Mess Partner',
      provider_phone: provider?.public_phone || '',
      is_break_day: false,
      skip_allowance: skipAllowance,
      skips_used: skipsUsed,
      remaining_skips: Math.max(0, skipAllowance - skipsUsed),
      week_days: weekDays,
      meals,
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const action = String(body.action || '').trim();
  const subscriptionId = String(body.subscription_id || '').trim();
  const claimedCustomerId = String(body.customer_id || '').trim();
  const providerId = String(body.provider_id || '').trim();
  const serviceDate = String(body.service_date || getIndiaDateString()).trim();
  const slot = String(body.slot || '').toUpperCase().trim();

  if (!action || !subscriptionId || !claimedCustomerId || !providerId || !slot) {
    return NextResponse.json(
      { success: false, error: 'action, subscription_id, customer_id, provider_id, and slot are required.' },
      { status: 400 }
    );
  }

  const auth = await requireCustomerIdentity(req, claimedCustomerId);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }
  const customerId = auth.userId;

  const admin = getAdminClient();
  const memKey = `${subscriptionId}_${serviceDate}_${slot}`;
  const nowIso = new Date().toISOString();

  // Verify subscription ownership before any mutation (`skip`, `reschedule`, or `instruction`)
  let verifiedSub: any = null;
  if (admin) {
    const { data: sub } = await admin
      .from('subscriptions')
      .select('id,skip_allowance,skips_used,customer_id,provider_id,status')
      .eq('id', subscriptionId)
      .maybeSingle();
    verifiedSub = sub;
  }
  if (!verifiedSub) {
    verifiedSub = platformStore.subscriptions.get(subscriptionId) || null;
  }
  if (!verifiedSub) {
    return NextResponse.json({ success: false, error: 'Subscription not found.' }, { status: 404 });
  }
  if (!auth.isAdmin && verifiedSub.customer_id !== customerId) {
    return NextResponse.json({ success: false, error: 'You cannot modify this meal.' }, { status: 403 });
  }
  if (verifiedSub.provider_id && verifiedSub.provider_id !== providerId) {
    return NextResponse.json({ success: false, error: 'Subscription does not match kitchen.' }, { status: 400 });
  }

  if (action === 'skip') {
    const skipAllowance = Number(verifiedSub.skip_allowance ?? 2);
    const skipsUsed = Number(verifiedSub.skips_used ?? 0);

    if (admin) {
      const { data: existingEv } = await admin
        .from('daily_meal_events')
        .select('id,status')
        .eq('subscription_id', subscriptionId)
        .eq('service_date', serviceDate)
        .eq('slot', slot)
        .maybeSingle();

      if (existingEv?.status === 'skipped') {
        return NextResponse.json({
          success: true,
          event: existingEv,
          remaining_skips: Math.max(0, skipAllowance - skipsUsed),
          message: `${slot} is already skipped for ${serviceDate}.`,
        });
      }

      if (skipsUsed >= skipAllowance) {
        return NextResponse.json(
          { success: false, error: `You have already used all ${skipAllowance} skips allowed for this plan.` },
          { status: 400 }
        );
      }
      await admin.from('subscriptions').update({ skips_used: skipsUsed + 1 }).eq('id', subscriptionId);

      const { data: ev, error } = await admin
        .from('daily_meal_events')
        .upsert(
          {
            subscription_id: subscriptionId,
            customer_id: customerId,
            provider_id: providerId,
            service_date: serviceDate,
            slot,
            status: 'skipped',
            skipped_at: nowIso,
            skip_reason: body.reason ? String(body.reason).slice(0, 240) : 'Skipped by customer',
            updated_at: nowIso,
          },
          { onConflict: 'subscription_id,service_date,slot' }
        )
        .select('*')
        .single();

      addPartnerNotification({
        provider_id: providerId,
        type: 'info',
        title: `Meal Skipped (${slot})`,
        message: `A subscriber skipped ${slot.toLowerCase()} for ${serviceDate}.`,
        subscription_id: subscriptionId,
      });

      if (!error && ev) {
        return NextResponse.json({
          success: true,
          event: ev,
          remaining_skips: Math.max(0, skipAllowance - (skipsUsed + 1)),
          message: `${slot} skipped for ${serviceDate}.`,
        });
      }
    }

    const existingMem = platformStore.dailyMealEvents.get(memKey);
    if (existingMem?.status === 'skipped') {
      return NextResponse.json({
        success: true,
        event: existingMem,
        remaining_skips: Math.max(0, skipAllowance - skipsUsed),
      });
    }
    if (skipsUsed >= skipAllowance) {
      return NextResponse.json(
        { success: false, error: `You have already used all ${skipAllowance} skips allowed for this plan.` },
        { status: 400 }
      );
    }
    (verifiedSub as any).skips_used = skipsUsed + 1;
    const memEv = {
      id: memKey,
      subscription_id: subscriptionId,
      customer_id: customerId,
      provider_id: providerId,
      service_date: serviceDate,
      slot,
      status: 'skipped',
      skipped_at: nowIso,
    };
    platformStore.dailyMealEvents.set(memKey, memEv);
    return NextResponse.json({ success: true, event: memEv, remaining_skips: Math.max(0, skipAllowance - (skipsUsed + 1)) });
  }

  if (action === 'reschedule') {
    const customTimeSlot = String(body.custom_time_slot || body.time_window || '').trim().slice(0, 80);
    if (!customTimeSlot) {
      return NextResponse.json({ success: false, error: 'custom_time_slot is required.' }, { status: 400 });
    }
    if (admin) {
      const { data: ev, error } = await admin
        .from('daily_meal_events')
        .upsert(
          {
            subscription_id: subscriptionId,
            customer_id: customerId,
            provider_id: providerId,
            service_date: serviceDate,
            slot,
            custom_time_slot: customTimeSlot,
            updated_at: nowIso,
          },
          { onConflict: 'subscription_id,service_date,slot' }
        )
        .select('*')
        .single();
      if (!error && ev) {
        return NextResponse.json({ success: true, event: ev, message: 'Meal slot rescheduled.' });
      }
    }
    const existing = platformStore.dailyMealEvents.get(memKey) || {
      id: memKey,
      subscription_id: subscriptionId,
      customer_id: customerId,
      provider_id: providerId,
      service_date: serviceDate,
      slot,
      status: 'scheduled',
    };
    existing.custom_time_slot = customTimeSlot;
    platformStore.dailyMealEvents.set(memKey, existing);
    return NextResponse.json({ success: true, event: existing, message: 'Meal slot rescheduled.' });
  }

  if (action === 'instruction') {
    const instructions = String(body.instructions || '').trim().slice(0, 500);
    if (admin) {
      const { data: ev, error } = await admin
        .from('daily_meal_events')
        .upsert(
          {
            subscription_id: subscriptionId,
            customer_id: customerId,
            provider_id: providerId,
            service_date: serviceDate,
            slot,
            instructions,
            updated_at: nowIso,
          },
          { onConflict: 'subscription_id,service_date,slot' }
        )
        .select('*')
        .single();
      if (!error && ev) {
        return NextResponse.json({ success: true, event: ev, message: 'Delivery instruction saved.' });
      }
    }
    const existing = platformStore.dailyMealEvents.get(memKey) || {
      id: memKey,
      subscription_id: subscriptionId,
      customer_id: customerId,
      provider_id: providerId,
      service_date: serviceDate,
      slot,
      status: 'scheduled',
    };
    existing.instructions = instructions;
    platformStore.dailyMealEvents.set(memKey, existing);
    return NextResponse.json({ success: true, event: existing, message: 'Delivery instruction saved.' });
  }

  return NextResponse.json({ success: false, error: 'Unsupported action.' }, { status: 400 });
}
