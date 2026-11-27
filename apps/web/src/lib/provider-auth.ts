import type { NextRequest } from 'next/server';
import { createClient as createSessionClient } from '@/lib/supabase/server';
import { getAdminClient, requireAdmin } from '@/lib/supabase/admin';
import {
  verifyAdminOrServiceBearer,
  verifySignedSessionToken,
} from '@/lib/auth-session';

export type ProviderAuthResult =
  | { ok: true; userId: string; providerId: string; isAdmin: boolean; email?: string }
  | { ok: false; status: 400 | 401 | 403 | 503; error: string };

async function checkDbProviderOwnership(
  userId: string,
  userEmail: string | undefined,
  targetProviderId: string
): Promise<boolean> {
  const db = getAdminClient();
  if (!db || !userId) return false;

  // 1. Admin role check
  try {
    const { data: adminRole } = await db
      .from('user_roles')
      .select('role')
      .eq('user_id', userId)
      .eq('role', 'admin')
      .is('revoked_at', null)
      .maybeSingle();
    if (adminRole) return true;
  } catch {}

  // 2. Explicit owner/manager membership
  try {
    const { data: mem } = await db
      .from('provider_memberships')
      .select('id')
      .eq('provider_id', targetProviderId)
      .eq('user_id', userId)
      .eq('active', true)
      .in('role', ['owner', 'manager'])
      .limit(1)
      .maybeSingle();
    if (mem) return true;
  } catch {}

  // 3. Direct provider owner_user_id or exact verified email match (never substring match)
  try {
    const { data: byOwner } = await db
      .from('providers')
      .select('id, owner_user_id, public_email')
      .eq('id', targetProviderId)
      .maybeSingle();

    if (byOwner) {
      if (byOwner.owner_user_id && byOwner.owner_user_id === userId) {
        return true;
      }
      if (
        userEmail &&
        byOwner.public_email &&
        byOwner.public_email.toLowerCase() === userEmail.toLowerCase() &&
        !byOwner.owner_user_id
      ) {
        return true;
      }
    }
  } catch {}

  return false;
}

/**
 * Validates that the caller is authenticated and authorized to manage `targetProviderId`.
 * Fails closed: rejects unauthenticated callers (401), unverified tokens (401),
 * and callers who do not own or manage the target kitchen (403).
 */
export async function requireProviderOwnership(
  req: NextRequest,
  targetProviderId: string
): Promise<ProviderAuthResult> {
  if (!targetProviderId) {
    return { ok: false, status: 400, error: 'Provider ID is required.' };
  }

  const authHeader = req.headers.get('authorization');
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7).trim();
    if (!token) {
      return { ok: false, status: 401, error: 'Authorization token is empty.' };
    }

    // 1. Service / Admin API secret (constant-time)
    if (verifyAdminOrServiceBearer(token)) {
      return { ok: true, userId: 'admin-service', providerId: targetProviderId, isAdmin: true };
    }

    // 2. HMAC-signed Thali mobile/OTP session token
    const signed = verifySignedSessionToken(token, 'thali_tok_');
    if (signed) {
      if (signed.role === 'admin') {
        return { ok: true, userId: signed.userId, providerId: targetProviderId, isAdmin: true, email: signed.email };
      }
      if (signed.providerId && signed.providerId === targetProviderId) {
        return { ok: true, userId: signed.userId, providerId: targetProviderId, isAdmin: false, email: signed.email };
      }
      const owns = await checkDbProviderOwnership(signed.userId, signed.email, targetProviderId);
      if (owns) {
        return { ok: true, userId: signed.userId, providerId: targetProviderId, isAdmin: false, email: signed.email };
      }
      return { ok: false, status: 403, error: 'You do not have permission to manage this kitchen.' };
    }

    // 3. Cryptographically verified Supabase access JWT (via auth.getUser — never unverified decode)
    const adminClient = getAdminClient();
    if (adminClient) {
      try {
        const {
          data: { user },
          error: tokenError,
        } = await adminClient.auth.getUser(token);
        if (!tokenError && user) {
          const { data: adminRole } = await adminClient
            .from('user_roles')
            .select('role')
            .eq('user_id', user.id)
            .eq('role', 'admin')
            .is('revoked_at', null)
            .maybeSingle();
          if (adminRole) {
            return { ok: true, userId: user.id, providerId: targetProviderId, isAdmin: true, email: user.email };
          }

          const owns = await checkDbProviderOwnership(user.id, user.email, targetProviderId);
          if (owns) {
            return { ok: true, userId: user.id, providerId: targetProviderId, isAdmin: false, email: user.email };
          }
          return { ok: false, status: 403, error: 'You do not have permission to manage this kitchen.' };
        }
      } catch {}
    }

    return { ok: false, status: 401, error: 'Invalid or expired partner token. Please sign in again.' };
  }

  // 4. Web SSR Admin session
  const admin = await requireAdmin(req);
  if (admin.ok) {
    return { ok: true, userId: admin.userId, providerId: targetProviderId, isAdmin: true };
  }

  // 5. Web SSR Supabase cookie session or HttpOnly signed thali_session_token cookie
  try {
    const tokenCookie = req.cookies.get('thali_session_token')?.value?.trim();
    if (tokenCookie) {
      const signedCookie = verifySignedSessionToken(tokenCookie, 'thali_tok_');
      if (signedCookie) {
        if (signedCookie.role === 'admin') {
          return { ok: true, userId: signedCookie.userId, providerId: targetProviderId, isAdmin: true, email: signedCookie.email };
        }
        if (signedCookie.providerId && signedCookie.providerId === targetProviderId) {
          return { ok: true, userId: signedCookie.userId, providerId: targetProviderId, isAdmin: false, email: signedCookie.email };
        }
        const owns = await checkDbProviderOwnership(signedCookie.userId, signedCookie.email, targetProviderId);
        if (owns) {
          return { ok: true, userId: signedCookie.userId, providerId: targetProviderId, isAdmin: false, email: signedCookie.email };
        }
      }
    }
  } catch {}

  try {
    const session = await createSessionClient();
    const {
      data: { user },
      error,
    } = await session.auth.getUser();
    if (!error && user) {
      const { data: membership } = await session
        .from('provider_memberships')
        .select('id')
        .eq('provider_id', targetProviderId)
        .eq('user_id', user.id)
        .eq('active', true)
        .in('role', ['owner', 'manager'])
        .limit(1)
        .maybeSingle();
      if (membership) {
        return { ok: true, userId: user.id, providerId: targetProviderId, isAdmin: false, email: user.email };
      }

      const { data: owned } = await session
        .from('providers')
        .select('id')
        .eq('id', targetProviderId)
        .eq('owner_user_id', user.id)
        .maybeSingle();
      if (owned) {
        return { ok: true, userId: user.id, providerId: targetProviderId, isAdmin: false, email: user.email };
      }

      return { ok: false, status: 403, error: 'You do not have permission to manage this kitchen.' };
    }
  } catch {}

  return { ok: false, status: 401, error: 'Authentication required. Please sign in.' };
}
