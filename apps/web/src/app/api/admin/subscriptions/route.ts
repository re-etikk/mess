import { NextRequest, NextResponse } from 'next/server';
import { requireAdmin, getAdminClient } from '@/lib/supabase/admin';

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req);
  if (!auth.ok) return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  const db = getAdminClient();
  if (!db) return NextResponse.json({ success: false, error: 'Database is not configured.' }, { status: 503 });
  const { data, error, count } = await db.from('subscriptions').select('*', { count: 'exact' }).order('created_at', { ascending: false }).limit(100);
  if (error) return NextResponse.json({ success: false, error: 'Could not load persisted subscriptions.' }, { status: 503 });
  return NextResponse.json({ success: true, total: count ?? 0, active: data.filter((item) => item.status === 'active').length, subscriptions: data }, { headers: { 'Cache-Control': 'private, no-store' } });
}
