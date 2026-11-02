import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { resolveRequestedPortalRole } from '@/lib/auth/portal-role';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  let body: { email?: string; password?: string; role?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }

  const email = body.email?.trim().toLowerCase();
  const password = body.password;
  if (!email || !password || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return NextResponse.json({ success: false, error: 'A valid email and password are required.' }, { status: 400 });
  }

  try {
    const supabase = await createClient();
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error || !data.user) {
      return NextResponse.json({ success: false, error: 'Invalid email or password.' }, { status: 401 });
    }

    const [{ data: roles, error: rolesError }, { data: memberships, error: membershipsError }] = await Promise.all([
      supabase.from('user_roles').select('role').eq('user_id', data.user.id).is('revoked_at', null),
      supabase.from('provider_memberships').select('provider_id,role').eq('user_id', data.user.id).eq('active', true),
    ]);
    if (rolesError || membershipsError) {
      await supabase.auth.signOut();
      return NextResponse.json({ success: false, error: 'Account permissions could not be verified.' }, { status: 503 });
    }

    const roleNames = new Set((roles ?? []).map((row) => row.role));
    const activeMemberships = memberships ?? [];
    const managementMemberships = activeMemberships.filter((membership) => ['owner', 'manager'].includes(membership.role));
    const requestedRole = body.role;
    const resolvedRole = resolveRequestedPortalRole(requestedRole, roleNames, managementMemberships.length);

    if (!resolvedRole || (requestedRole && !['admin', 'provider', 'customer'].includes(requestedRole))) {
      await supabase.auth.signOut();
      return NextResponse.json({ success: false, error: 'This account is not authorized for that portal.' }, { status: 403 });
    }

    const profileResult = await supabase.from('profiles').select('display_name').eq('id', data.user.id).maybeSingle();
    const providerId = managementMemberships[0]?.provider_id;
    const { data: provider } = providerId
      ? await supabase.from('providers').select('id,display_name,status').eq('id', providerId).maybeSingle()
      : { data: null };

    return NextResponse.json({
      success: true,
      user: {
        id: data.user.id,
        email: data.user.email,
        name: profileResult.data?.display_name || data.user.email?.split('@')[0] || '',
        role: resolvedRole,
        provider_id: provider?.id,
        provider_name: provider?.display_name,
        provider_status: provider?.status,
      },
      // Real Supabase session tokens are returned for authenticated mobile API clients.
      token: data.session?.access_token,
      refresh_token: data.session?.refresh_token,
      expires_at: data.session?.expires_at,
      message: 'Login successful.',
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'Authentication is unavailable.';
    return NextResponse.json({ success: false, error: message }, { status: 503 });
  }
}
