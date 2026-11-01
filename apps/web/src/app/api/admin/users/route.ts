import { NextRequest, NextResponse } from 'next/server';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const params = new URL(req.url).searchParams;
  const page = Math.min(100000, Math.max(1, Number(params.get('page')) || 1));
  const pageSize = Math.min(50, Math.max(1, Number(params.get('page_size')) || 20));
  const query = params.get('q')?.trim().slice(0, 80) ?? '';
  const from = (page - 1) * pageSize;
  let request = access.admin
    .from('profiles')
    .select('id,display_name,phone_e164,created_at,user_roles!user_roles_user_id_fkey!inner(role,revoked_at)', { count: 'exact' })
    .eq('user_roles.role', 'customer')
    .is('user_roles.revoked_at', null)
    .order('created_at', { ascending: false })
    .range(from, from + pageSize - 1);
  if (query) {
    request = /^[0-9a-f-]{36}$/i.test(query)
      ? request.eq('id', query)
      : request.ilike('display_name', `%${query.replace(/[%_,]/g, '')}%`);
  }
  const { data, error, count } = await request;

  if (error) {
    console.error('Admin user directory query failed:', error.message);
    return NextResponse.json({ success: false, error: 'User directory could not be loaded.' }, { status: 503 });
  }

  const users = (data ?? []).map((profile: any) => ({
    id: profile.id,
    name: profile.display_name,
    phone_masked: maskPhone(profile.phone_e164),
    role: 'customer',
    created_at: profile.created_at,
  }));
  return NextResponse.json({ success: true, total: count ?? 0, page, page_size: pageSize, users }, { headers: { 'Cache-Control': 'private, no-store' } });
}

function maskPhone(value: string | null) {
  if (!value) return null;
  const digits = value.replace(/\D/g, '');
  return digits.length < 4 ? '••••' : `••••••${digits.slice(-4)}`;
}
