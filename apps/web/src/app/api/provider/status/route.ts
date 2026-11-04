import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id') || new URL(req.url).searchParams.get('providerId');
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });

  // 1. Check explicit manual provider status override in platformStore
  if (platformStore.providerStatuses.has(providerId)) {
    const manualOpen = platformStore.providerStatuses.get(providerId)!;
    const storeProv = platformStore.providers.get(providerId);
    return NextResponse.json({
      success: true,
      provider_id: providerId,
      display_name: storeProv?.display_name || 'Mess Partner',
      is_open_today: manualOpen,
      status_label: manualOpen ? 'OPEN / SERVING TODAY' : 'CLOSED / OFF TODAY',
    }, { headers: { 'Cache-Control': 'private, no-store' } });
  }

  const db = getAdminClient();
  if (!db) {
    const storeProv = platformStore.providers.get(providerId);
    return NextResponse.json({
      success: true,
      provider_id: providerId,
      display_name: storeProv?.display_name || 'Mess',
      is_open_today: true,
      status_label: 'OPEN / SERVING TODAY',
    });
  }

  const { data: provider, error } = await db.from('providers').select('id,display_name,status').eq('id', providerId).maybeSingle();
  if (error || !provider) {
    return NextResponse.json({
      success: true,
      provider_id: providerId,
      display_name: 'Mess Partner',
      is_open_today: true,
      status_label: 'OPEN / SERVING TODAY',
    });
  }

  const weekdayName = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Kolkata', weekday: 'short' }).format(new Date());
  const weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(weekdayName);

  const { data: hours } = await db
    .from('provider_operating_hours')
    .select('opens_at,closes_at,closed')
    .eq('provider_id', providerId)
    .eq('weekday', weekday)
    .maybeSingle();

  // If closed explicitly in DB, false; otherwise default to open
  const isOpen = provider.status !== 'suspended' && Boolean(!hours || !hours.closed);

  return NextResponse.json({
    success: true,
    provider_id: provider.id,
    display_name: provider.display_name,
    is_open_today: isOpen,
    status_label: isOpen ? 'OPEN / SERVING TODAY' : 'CLOSED / OFF TODAY',
  }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function POST(req: NextRequest) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }

  const providerId = body.provider_id || body.providerId;
  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const isOpen = body.is_open === true || body.isOpen === true;

  // 1. Immediately store in memory so GET returns this manual choice
  platformStore.providerStatuses.set(providerId, isOpen);

  const db = getAdminClient();
  const weekdayName = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Kolkata', weekday: 'short' }).format(new Date());
  const weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(weekdayName);

  if (db) {
    try {
      const { data: existing } = await db
        .from('provider_operating_hours')
        .select('id')
        .eq('provider_id', providerId)
        .eq('weekday', weekday)
        .maybeSingle();

      if (existing) {
        await db
          .from('provider_operating_hours')
          .update({
            closed: !isOpen,
            opens_at: isOpen ? '00:00:00' : '00:00:00',
            closes_at: isOpen ? '23:59:59' : '00:00:00',
            updated_at: new Date().toISOString(),
          })
          .eq('id', existing.id);
      } else {
        await db
          .from('provider_operating_hours')
          .insert({
            provider_id: providerId,
            weekday,
            opens_at: isOpen ? '00:00:00' : '00:00:00',
            closes_at: isOpen ? '23:59:59' : '00:00:00',
            closed: !isOpen,
          });
      }
    } catch (e: any) {
      console.warn('Operating hours DB update error:', e?.message);
    }
  }

  // Update in-memory platform store
  const inStore = platformStore.providers.get(providerId);
  if (inStore) {
    inStore.status = 'active';
  }

  return NextResponse.json({
    success: true,
    provider_id: providerId,
    is_open_today: isOpen,
    status_label: isOpen ? 'OPEN / SERVING TODAY' : 'CLOSED / OFF TODAY',
    message: isOpen ? 'Kitchen marked OPEN & SERVING TODAY' : 'Kitchen marked CLOSED / OFF TODAY',
  }, { headers: { 'Cache-Control': 'no-store' } });
}
