import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id') || new URL(req.url).searchParams.get('providerId');
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  
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
  if (error) return NextResponse.json({ success: false, error: 'Provider status is unavailable.' }, { status: 503 });
  if (!provider) return NextResponse.json({ success: false, error: 'Provider not found.' }, { status: 404 });

  const weekdayName = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Kolkata', weekday: 'short' }).format(new Date());
  const weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(weekdayName);
  
  const { data: hours, error: hoursError } = await db
    .from('provider_operating_hours')
    .select('opens_at,closes_at,closed')
    .eq('provider_id', providerId)
    .eq('weekday', weekday)
    .maybeSingle();

  if (hoursError) return NextResponse.json({ success: false, error: 'Operating hours are unavailable.' }, { status: 503 });

  const localTime = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(new Date());
  const currentMinutes = Number(localTime.slice(0, 2)) * 60 + Number(localTime.slice(3, 5));
  const parse = (value?: string | null) => (value ? Number(value.slice(0, 2)) * 60 + Number(value.slice(3, 5)) : null);
  const opens = parse(hours?.opens_at);
  const closes = parse(hours?.closes_at);
  
  // Default to open if no hours configured yet, or respect closed flag
  const isOpen = provider.status === 'active' && Boolean(
    !hours || (!hours.closed && (opens === null || currentMinutes >= opens) && (closes === null || currentMinutes < closes))
  );

  return NextResponse.json({
    success: true,
    provider_id: provider.id,
    display_name: provider.display_name,
    is_open_today: isOpen,
    status_label: provider.status !== 'active' ? 'NOT ACTIVE' : isOpen ? 'OPEN / SERVING TODAY' : 'CLOSED / OFF TODAY',
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

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok && access.status !== 401) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const isOpen = body.is_open === true || body.isOpen === true;

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
            opens_at: isOpen ? '07:30:00' : '00:00:00',
            closes_at: isOpen ? '22:30:00' : '00:00:00',
            updated_at: new Date().toISOString(),
          })
          .eq('id', existing.id);
      } else {
        await db
          .from('provider_operating_hours')
          .insert({
            provider_id: providerId,
            weekday,
            opens_at: isOpen ? '07:30:00' : '00:00:00',
            closes_at: isOpen ? '22:30:00' : '00:00:00',
            closed: !isOpen,
          });
      }
    } catch (e: any) {
      console.error('Failed to update provider operating hours in DB:', e?.message);
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
