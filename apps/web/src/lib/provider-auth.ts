import type { NextRequest } from 'next/server';
import { createClient as createSessionClient } from '@/lib/supabase/server';
import { getAdminClient, requireAdmin } from '@/lib/supabase/admin';

export type ProviderAuthResult =
  | { ok: true; userId: string; providerId: string; isAdmin: boolean }
  | { ok: false; status: 400 | 401 | 403 | 503; error: string };

/** Provider mutations require a valid Supabase user and an active persisted membership. */
export async function requireProviderOwnership(
  req: NextRequest,
  targetProviderId: string,
): Promise<ProviderAuthResult> {
  if (!targetProviderId) return { ok: false, status: 400, error: 'Provider ID is required.' };

  const authHeader = req.headers.get('authorization');
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7).trim();
    const adminClient = getAdminClient();
    if (!adminClient || !token || token.startsWith('jwt_')) {
      return { ok: false, status: adminClient ? 401 : 503, error: 'A valid Supabase access token is required.' };
    }
    const { data: { user }, error: tokenError } = await adminClient.auth.getUser(token);
    if (tokenError || !user) return { ok: false, status: 401, error: 'Authentication required.' };

    const { data: roles, error: roleError } = await adminClient.from('user_roles').select('id')
      .eq('user_id', user.id).eq('role', 'admin').is('revoked_at', null).limit(1);
    if (roleError) return { ok: false, status: 503, error: 'Permissions could not be verified.' };
    if (roles?.length) return { ok: true, userId: user.id, providerId: targetProviderId, isAdmin: true };

    const { data: memberships, error: membershipError } = await adminClient.from('provider_memberships').select('id')
      .eq('provider_id', targetProviderId).eq('user_id', user.id).eq('active', true)
      .in('role', ['owner', 'manager']).limit(1);
    if (membershipError) return { ok: false, status: 503, error: 'Provider permissions could not be verified.' };
    if (memberships?.length) return { ok: true, userId: user.id, providerId: targetProviderId, isAdmin: false };
    return { ok: false, status: 403, error: 'You do not have permission to manage this provider.' };
  }

  const admin = await requireAdmin(req);
  if (admin.ok) return { ok: true, userId: admin.userId, providerId: targetProviderId, isAdmin: true };
  if (admin.status === 503) return admin;

  let session;
  try {
    session = await createSessionClient();
  } catch {
    return { ok: false, status: 503, error: 'Authentication is not configured.' };
  }

  const { data: { user }, error } = await session.auth.getUser();
  if (error || !user) return { ok: false, status: 401, error: 'Authentication required.' };

  const { data: membership, error: membershipError } = await session
    .from('provider_memberships')
    .select('id')
    .eq('provider_id', targetProviderId)
    .eq('user_id', user.id)
    .eq('active', true)
    .in('role', ['owner', 'manager'])
    .limit(1)
    .maybeSingle();

  if (membershipError) return { ok: false, status: 503, error: 'Provider access could not be verified.' };
  if (!membership) return { ok: false, status: 403, error: 'You do not have permission to manage this provider.' };
  return { ok: true, userId: user.id, providerId: targetProviderId, isAdmin: false };
}
