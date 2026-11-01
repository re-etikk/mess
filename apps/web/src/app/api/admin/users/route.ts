import { NextRequest, NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const page = Math.max(1, Number(new URL(req.url).searchParams.get('page')) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(new URL(req.url).searchParams.get('page_size')) || 50));
  const from = (page - 1) * pageSize;
  const { data, error, count } = await access.admin
    .from('profiles')
    .select('id,display_name,phone_e164,created_at,user_roles(role,revoked_at)', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(from, from + pageSize - 1);

  if (error) {
    console.error('Admin user directory query failed:', error.message);
    return NextResponse.json({ success: false, error: 'User directory could not be loaded.' }, { status: 503 });
  }

  const users = (data ?? []).map((profile: any) => ({
    id: profile.id,
    name: profile.display_name,
    phone: profile.phone_e164,
    role: (profile.user_roles ?? []).filter((role: any) => !role.revoked_at).map((role: any) => role.role),
    created_at: profile.created_at,
  }));
  return NextResponse.json({ success: true, total: count ?? 0, page, page_size: pageSize, users }, { headers: { 'Cache-Control': 'private, no-store' } });
}
