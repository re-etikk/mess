import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { publicErrorMessage } from '@/lib/auth-session';
import { platformStore } from '@/lib/platform-service';
import { getIstWeekday, isKitchenOpenFromRecord, isUndefinedColumnError } from '@/lib/kitchen-status';

export const dynamic = 'force-dynamic';
export const fetchCache = 'force-no-store';

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id') || new URL(req.url).searchParams.get('providerId');
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });

  const db = getAdminClient();
  const weekday = getIstWeekday();

  if (db) {
    let { data: provider, error } = await db
      .from('providers')
      .select('id,display_name,status,is_accepting_orders')
      .eq('id', providerId)
      .maybeSingle();

    if (isUndefinedColumnError(error, 'is_accepting_orders')) {
      const fallback = await db
        .from('providers')
        .select('id,display_name,status')
        .eq('id', providerId)
        .maybeSingle();
      provider = fallback.data ? { ...fallback.data, is_accepting_orders: true } : null;
      error = fallback.error;
    }

    if (error) {
      console.error('Kitchen status GET error:', error.message);
      return NextResponse.json(
        { success: false, error: publicErrorMessage(error, 'Unable to load kitchen status. Please try again.') },
        { status: 503 }
      );
    }

    if (provider) {
      const { data: hours, error: hoursError } = await db
        .from('provider_operating_hours')
        .select('opens_at,closes_at,closed')
        .eq('provider_id', providerId)
        .eq('weekday', weekday)
        .maybeSingle();

      if (hoursError) {
        console.warn('Operating hours GET warning:', hoursError.message);
      }

      const isOpen = isKitchenOpenFromRecord({
        status: provider.status,
        is_accepting_orders: provider.is_accepting_orders,
        todayHours: hours,
      });

      platformStore.providerStatuses.set(providerId, isOpen);

      return NextResponse.json(
        {
          success: true,
          provider_id: provider.id,
          display_name: provider.display_name,
          is_open_today: isOpen,
          status_label: isOpen ? 'OPEN / SERVING TODAY' : 'CLOSED / OFF TODAY',
        },
        { headers: { 'Cache-Control': 'private, no-store' } }
      );
    }
  }

  // Fallback for test/in-memory stores when DB has no row or is unconfigured
  const storeProv = platformStore.providers.get(providerId);
  const manualOpen = platformStore.providerStatuses.has(providerId)
    ? platformStore.providerStatuses.get(providerId)!
    : storeProv?.is_open_today !== false;

  return NextResponse.json(
    {
      success: true,
      provider_id: providerId,
      display_name: storeProv?.display_name || 'Mess Partner',
      is_open_today: manualOpen,
      status_label: manualOpen ? 'OPEN / SERVING TODAY' : 'CLOSED / OFF TODAY',
    },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }

  const providerId = String(body.provider_id || body.providerId || '').trim();
  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const isOpen = body.is_open === true || body.isOpen === true;
  const db = getAdminClient();
  const weekday = getIstWeekday();
  const nowIso = new Date().toISOString();

  if (db) {
    let providerWriteOk = false;
    let providerWriteErr: any = null;

    const { error: provErr } = await db
      .from('providers')
      .update({ is_accepting_orders: isOpen, updated_at: nowIso })
      .eq('id', providerId);

    if (!provErr) {
      providerWriteOk = true;
    } else if (!isUndefinedColumnError(provErr, 'is_accepting_orders')) {
      providerWriteErr = provErr;
    }

    let hoursWriteOk = false;
    let hoursWriteErr: any = null;

    const { data: existing, error: lookupErr } = await db
      .from('provider_operating_hours')
      .select('id,opens_at,closes_at')
      .eq('provider_id', providerId)
      .eq('weekday', weekday)
      .maybeSingle();

    if (lookupErr) {
      hoursWriteErr = lookupErr;
    } else {
      const hasValidWindow =
        existing?.opens_at &&
        existing?.closes_at &&
        existing.opens_at !== existing.closes_at;

      const opensAt = isOpen ? (hasValidWindow ? existing.opens_at : '07:00:00') : '00:00:00';
      const closesAt = isOpen ? (hasValidWindow ? existing.closes_at : '22:30:00') : '00:00:00';

      const { error: upsertErr } = existing
        ? await db
            .from('provider_operating_hours')
            .update({
              closed: !isOpen,
              opens_at: opensAt,
              closes_at: closesAt,
              updated_at: nowIso,
            })
            .eq('id', existing.id)
        : await db.from('provider_operating_hours').insert({
            provider_id: providerId,
            weekday,
            opens_at: opensAt,
            closes_at: closesAt,
            closed: !isOpen,
          });

      if (!upsertErr) {
        hoursWriteOk = true;
      } else {
        hoursWriteErr = upsertErr;
      }
    }

    // Never pretend success if Postgres rejected updating open/closed state
    if (!hoursWriteOk || (!providerWriteOk && providerWriteErr)) {
      console.error('Kitchen status persist failed:', hoursWriteErr?.message || providerWriteErr?.message);
      return NextResponse.json(
        {
          success: false,
          error: publicErrorMessage(hoursWriteErr || providerWriteErr, 'Could not update kitchen status right now. Please try again.'),
        },
        { status: 503 }
      );
    }
  }

  platformStore.providerStatuses.set(providerId, isOpen);
  const inStore = platformStore.providers.get(providerId);
  if (inStore) {
    inStore.is_open_today = isOpen;
  }

  return NextResponse.json(
    {
      success: true,
      provider_id: providerId,
      is_open_today: isOpen,
      status_label: isOpen ? 'OPEN / SERVING TODAY' : 'CLOSED / OFF TODAY',
      message: isOpen ? 'Kitchen marked OPEN & SERVING TODAY' : 'Kitchen marked CLOSED / OFF TODAY',
    },
    { headers: { 'Cache-Control': 'no-store' } }
  );
}
