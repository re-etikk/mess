import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { sanitizePostgrestSearch } from '@/lib/auth-session';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const audience = (params.get('audience') || 'all').trim().toLowerCase();
  const rawProv = params.get('provider_id')?.trim() || '';
  const providerId = /^[0-9a-f-]{36}$/i.test(rawProv) ? rawProv : sanitizePostgrestSearch(rawProv);

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: true, announcements: [] }, { headers: { 'Cache-Control': 'private, no-store' } });
  }

  try {
    const nowIso = new Date().toISOString();
    let query = admin
      .from('announcements')
      .select('*')
      .eq('is_active', true)
      .lte('starts_at', nowIso)
      .or(`expires_at.is.null,expires_at.gt.${nowIso}`)
      .order('is_featured', { ascending: false })
      .order('priority', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(20);

    if (audience === 'customer' || audience === 'provider') {
      query = query.in('target_audience', ['all', audience]);
    }
    if (providerId) {
      query = query.or(`provider_id.is.null,provider_id.eq.${providerId}`);
    }

    const { data, error } = await query;
    if (error) {
      return NextResponse.json({ success: true, announcements: [] }, { headers: { 'Cache-Control': 'private, no-store' } });
    }
    return NextResponse.json(
      { success: true, announcements: data ?? [] },
      { headers: { 'Cache-Control': 'private, no-store' } }
    );
  } catch {
    return NextResponse.json({ success: true, announcements: [] }, { headers: { 'Cache-Control': 'private, no-store' } });
  }
}
