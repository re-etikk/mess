import { createClient as createSupabaseClient, type SupabaseClient } from '@supabase/supabase-js';
import { createClient as createSessionClient } from './server';
import type { NextRequest } from 'next/server';
import { hasAdminCapability, type AdminCapability, type AdminSubRole } from '../admin-rbac';

export type AdminAccess =
  | { ok: true; userId: string; adminRole: AdminSubRole; admin: SupabaseClient<any> }
  | { ok: false; status: 401 | 403 | 503; error: string };

/** Forces Next.js Data Cache bypass on all Supabase REST queries. */
export const noStoreFetch: typeof fetch = (input, init) =>
  fetch(input, { ...init, cache: 'no-store' });

/** Server-only client. Never return this client or its credential to the browser. */
export function getAdminClient(): SupabaseClient<any> | null {
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!serviceKey || !url) return null;
  return createSupabaseClient<any>(url, serviceKey, {
    global: { fetch: noStoreFetch },
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
}

/** Admin access is granted only by a non-revoked database role, never metadata or an unverified client token. */
export async function requireAdmin(
  _req?: NextRequest,
  requiredCapability?: AdminCapability
): Promise<AdminAccess> {
  let session;
  try {
    session = await createSessionClient();
  } catch {
    return { ok: false, status: 503, error: 'Authentication is not configured.' };
  }

  const {
    data: { user },
    error,
  } = await session.auth.getUser();
  if (error || !user) return { ok: false, status: 401, error: 'Administrator authentication required.' };

  const { data: roles, error: roleError } = await session
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id)
    .in('role', ['admin', 'support'])
    .is('revoked_at', null);

  if (roleError) return { ok: false, status: 503, error: 'Administrator permissions could not be verified.' };
  if (!roles || roles.length === 0) {
    return { ok: false, status: 403, error: 'Administrator privileges required.' };
  }

  const admin = getAdminClient();
  if (!admin) return { ok: false, status: 503, error: 'Admin data access is not configured.' };

  let adminRole: AdminSubRole = roles.some((r) => r.role === 'admin') ? 'super_admin' : 'support';
  try {
    const { data: perm, error: permErr } = await admin
      .from('admin_team_permissions')
      .select('admin_role,revoked_at')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!permErr && perm) {
      if (perm.revoked_at) {
        return { ok: false, status: 403, error: 'Administrator access for this account has been revoked.' };
      }
      if (perm.admin_role) {
        adminRole = perm.admin_role as AdminSubRole;
      }
    }
  } catch {}

  if (!hasAdminCapability(adminRole, requiredCapability)) {
    return { ok: false, status: 403, error: 'Your admin role does not permit this action.' };
  }

  return { ok: true, userId: user.id, adminRole, admin };
}
