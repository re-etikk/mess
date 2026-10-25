import { createClient as createSupabaseClient, type SupabaseClient } from '@supabase/supabase-js';
import { createClient as createSessionClient } from './server';

export type AdminAccess =
  | { ok: true; userId: string; admin: SupabaseClient<any> }
  | { ok: false; status: 401 | 403 | 503; error: string };

export async function requireAdmin(): Promise<AdminAccess> {
  if (process.env.NEXT_PUBLIC_BACKEND_ENABLED !== 'true') {
    return { ok: false, status: 503, error: 'Backend is not configured.' };
  }

  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!serviceKey || !url) {
    return { ok: false, status: 503, error: 'Admin backend is not configured.' };
  }

  try {
    const session = await createSessionClient();
    const { data: { user }, error: authError } = await session.auth.getUser();
    if (authError || !user) return { ok: false, status: 401, error: 'Sign in required.' };

    const { data: role, error: roleError } = await session
      .from('user_roles')
      .select('id')
      .eq('user_id', user.id)
      .eq('role', 'admin')
      .is('revoked_at', null)
      .maybeSingle();
    if (roleError) return { ok: false, status: 503, error: 'Admin authorization could not be verified.' };
    if (!role) return { ok: false, status: 403, error: 'Admin access required.' };

    const admin = createSupabaseClient<any>(url, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
    });
    return { ok: true, userId: user.id, admin };
  } catch {
    return { ok: false, status: 503, error: 'Admin backend is unavailable.' };
  }
}
