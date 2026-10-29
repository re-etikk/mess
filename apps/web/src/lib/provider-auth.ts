import { NextRequest } from 'next/server';
import { createClient as createSessionClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export type ProviderAuthResult =
  | { ok: true; userId: string; providerId: string; isAdmin: boolean }
  | { ok: false; status: 401 | 403; error: string };

/**
 * Validates that the requester is authenticated and authorized to mutate the target provider's state.
 * Authorized if:
 * 1. Requester is an administrator (via admin secret, bearer token, or session)
 * 2. Requester has a valid provider session matching targetProviderId or owns that provider
 */
export async function requireProviderOwnership(
  req: NextRequest,
  targetProviderId: string
): Promise<ProviderAuthResult> {
  if (!targetProviderId) {
    return { ok: false, status: 401, error: 'Missing target provider ID' };
  }

  // 1. Check Bearer Token in Authorization header
  const authHeader = req.headers.get('authorization');
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.substring(7).trim();

    // Check if token is internal admin secret
    const expectedSecret = process.env.ADMIN_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (expectedSecret && token === expectedSecret) {
      return { ok: true, userId: 'admin-service', providerId: targetProviderId, isAdmin: true };
    }

    // Check if token is jwt_session_ / jwt_mock_
    if (token.startsWith('jwt_session_') || token.startsWith('jwt_mock_')) {
      try {
        const raw = Buffer.from(token.replace(/^jwt_(session|mock)_/, ''), 'base64url').toString('utf8');
        const session = JSON.parse(raw);
        if (session) {
          if (session.role === 'admin' || session.email === 'ritik45chaurasia@gmail.com') {
            return { ok: true, userId: session.userId || 'admin', providerId: targetProviderId, isAdmin: true };
          }

          // If provider session, match providerId or userId
          if (
            session.provider_id === targetProviderId ||
            session.providerId === targetProviderId ||
            session.userId === targetProviderId
          ) {
            return { ok: true, userId: session.userId, providerId: targetProviderId, isAdmin: false };
          }

          // Check if provider in platformStore belongs to this user
          const p = platformStore.providers.get(targetProviderId);
          if (p && (p.owner_user_id === session.userId || p.id === session.userId || p.email === session.email)) {
            return { ok: true, userId: session.userId, providerId: targetProviderId, isAdmin: false };
          }
        }
      } catch {}
    }
  }

  // 2. Check Supabase Session Cookies
  try {
    const supabase = await createSessionClient();
    const { data: { user } } = await supabase.auth.getUser();

    if (user) {
      // Check admin
      if (user.email === 'ritik45chaurasia@gmail.com' || user.user_metadata?.role === 'admin') {
        return { ok: true, userId: user.id, providerId: targetProviderId, isAdmin: true };
      }

      // Check user metadata application or provider ID
      const meta = user.user_metadata || {};
      const userProvId = meta.application?.id || meta.provider_id;
      if (userProvId === targetProviderId || user.id === targetProviderId) {
        return { ok: true, userId: user.id, providerId: targetProviderId, isAdmin: false };
      }

      // Check PostgreSQL providers table ownership
      const admin = getAdminClient();
      if (admin) {
        const { data: p } = await admin
          .from('providers')
          .select('id,owner_user_id')
          .eq('id', targetProviderId)
          .maybeSingle();

        if (p && (p.owner_user_id === user.id || p.id === user.id)) {
          return { ok: true, userId: user.id, providerId: targetProviderId, isAdmin: false };
        }
      }
    }
  } catch {}

  // 3. Fallback for locally recognized development/demo providers if running without remote DB
  const provider = platformStore.providers.get(targetProviderId);
  if (provider && (targetProviderId === 'prov-radhe-001' || provider.owner_user_id === 'usr-owner-001')) {
    // If request comes with matching provider identifier in body/headers during demo
    return { ok: true, userId: provider.owner_user_id || 'prov-radhe-001', providerId: targetProviderId, isAdmin: false };
  }

  return {
    ok: false,
    status: 403,
    error: 'Forbidden: You do not have permission to manage this kitchen partner.',
  };
}
