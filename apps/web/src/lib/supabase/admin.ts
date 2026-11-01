import { createClient as createSupabaseClient, type SupabaseClient } from '@supabase/supabase-js';
import { createClient as createSessionClient } from './server';
import type { NextRequest } from 'next/server';

export type AdminAccess =
  | { ok: true; userId: string; admin: SupabaseClient<any> }
  | { ok: false; status: 401 | 403 | 503; error: string };

/** Server-only client. Never return this client or its credential to the browser. */
export function getAdminClient(): SupabaseClient<any> | null {
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!serviceKey || !url) return null;
  return createSupabaseClient<any>(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
}

/** Admin access is granted only by a non-revoked database role, never metadata or a client-supplied token. */
export async function requireAdmin(_req?: NextRequest): Promise<AdminAccess> {
  let session;
  try {
    session = await createSessionClient();
  } catch {
    return { ok: false, status: 503, error: 'Authentication is not configured.' };
  }

  const { data: { user }, error } = await session.auth.getUser();
  if (error || !user) return { ok: false, status: 401, error: 'Administrator authentication required.' };

  const { data: role, error: roleError } = await session
    .from('user_roles')
    .select('id')
    .eq('user_id', user.id)
    .eq('role', 'admin')
    .is('revoked_at', null)
    .limit(1)
    .maybeSingle();

  if (roleError) return { ok: false, status: 503, error: 'Administrator permissions could not be verified.' };
  if (!role) return { ok: false, status: 403, error: 'Administrator privileges required.' };

  const admin = getAdminClient();
  if (!admin) return { ok: false, status: 503, error: 'Admin data access is not configured.' };
  return { ok: true, userId: user.id, admin };
}
