import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id') || new URL(req.url).searchParams.get('providerId');
  if (!providerId) return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  const db = getAdminClient();
  if (!db) return NextResponse.json({ success: false, error: 'Database is not configured.' }, { status: 503 });
  const { data: provider, error } = await db.from('providers').select('id,display_name,status').eq('id', providerId).maybeSingle();
  if (error) return NextResponse.json({ success: false, error: 'Provider status is unavailable.' }, { status: 503 });
  if (!provider) return NextResponse.json({ success: false, error: 'Provider not found.' }, { status: 404 });
  const weekdayName = new Intl.DateTimeFormat('en-US', { timeZone: 'Asia/Kolkata', weekday: 'short' }).format(new Date());
  const weekday = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(weekdayName);
  const { data: hours, error: hoursError } = await db.from('provider_operating_hours').select('opens_at,closes_at,closed').eq('provider_id', providerId).eq('weekday', weekday).maybeSingle();
  if (hoursError) return NextResponse.json({ success: false, error: 'Operating hours are unavailable.' }, { status: 503 });
  const localTime = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).format(new Date());
  const currentMinutes = Number(localTime.slice(0, 2)) * 60 + Number(localTime.slice(3, 5));
  const parse = (value?: string | null) => value ? Number(value.slice(0, 2)) * 60 + Number(value.slice(3, 5)) : null;
  const opens = parse(hours?.opens_at);
  const closes = parse(hours?.closes_at);
  const isOpen = provider.status === 'active' && Boolean(hours && !hours.closed && opens !== null && closes !== null && currentMinutes >= opens && currentMinutes < closes);
  return NextResponse.json({ success: true, provider_id: provider.id, display_name: provider.display_name, is_open_today: isOpen, status_label: provider.status !== 'active' ? 'NOT ACTIVE' : isOpen ? 'OPEN / SERVING TODAY' : hours ? 'CLOSED / OFF HOURS' : 'HOURS NOT SET' }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function POST() {
  return NextResponse.json({ success: false, error: 'Use persisted operating-hours settings; live open/closed overrides are not configured.' }, { status: 503 });
}
