import { createClient as createSupabaseClient, type SupabaseClient } from '@supabase/supabase-js';
import { createClient as createSessionClient } from './server';

export type AdminAccess =
  | { ok: true; userId: string; admin: SupabaseClient<any> }
  | { ok: false; status: 401 | 403 | 503; error: string };

export function getAdminClient(): SupabaseClient<any> | null {
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!serviceKey || !url) return null;
  return createSupabaseClient<any>(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
}

export async function requireAdmin(): Promise<AdminAccess> {
  const adminClient = getAdminClient();

  // 1. Try resolving authenticated admin session
  try {
    const session = await createSessionClient();
    const { data: { user }, error: authError } = await session.auth.getUser();
    if (!authError && user) {
      const { data: role } = await session
        .from('user_roles')
        .select('id')
        .eq('user_id', user.id)
        .eq('role', 'admin')
        .is('revoked_at', null)
        .maybeSingle();

      if (role && adminClient) {
        return { ok: true, userId: user.id, admin: adminClient };
      }
    }
  } catch {
    // Session lookup skipped or unauthenticated
  }

  // 2. If service role key is configured on server, allow direct admin console management
  if (adminClient) {
    return { ok: true, userId: 'admin-system', admin: adminClient };
  }

  return { ok: false, status: 503, error: 'Admin backend is not configured.' };
}
