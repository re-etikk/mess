import crypto from 'crypto';
import type { NextRequest } from 'next/server';
import { createClient as createSessionClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';

function getSessionSecret(): string {
  const secret =
    process.env.SESSION_SIGNING_SECRET ||
    process.env.QR_SIGNING_SECRET ||
    process.env.QR_HMAC_SECRET ||
    process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (secret && secret.trim().length >= 16) return secret.trim();
  if (process.env.NODE_ENV === 'test') {
    return 'test-only-thali-session-secret-0001';
  }
  throw new Error('SESSION_SIGNING_SECRET or QR_SIGNING_SECRET must be configured.');
}

export function timingSafeStringEqual(a: string, b: string): boolean {
  if (!a || !b) return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  return bufA.length === bufB.length && crypto.timingSafeEqual(bufA, bufB);
}

export interface SignedSessionPayload {
  userId: string;
  email: string;
  role: 'customer' | 'provider' | 'admin' | 'rider';
  providerId?: string;
  riderId?: string;
  phone?: string;
  name?: string;
  exp: number;
}

function signToken(prefix: 'thali_tok_' | 'thali_rider_', payload: SignedSessionPayload): string {
  const b64 = Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  const sig = crypto.createHmac('sha256', getSessionSecret()).update(`${prefix}${b64}`).digest('hex');
  return `${prefix}${b64}.${sig}`;
}

export function signSessionToken(input: {
  userId: string;
  email: string;
  role: 'customer' | 'provider' | 'admin';
  providerId?: string;
  name?: string;
  ttlSeconds?: number;
}): string {
  const exp = Math.floor(Date.now() / 1000) + (input.ttlSeconds ?? 30 * 86400);
  return signToken('thali_tok_', {
    userId: input.userId,
    email: input.email,
    role: input.role,
    ...(input.providerId ? { providerId: input.providerId } : {}),
    ...(input.name ? { name: input.name } : {}),
    exp,
  });
}

export function signRiderToken(input: {
  riderId: string;
  providerId: string;
  phone: string;
  name: string;
  ttlSeconds?: number;
}): string {
  const exp = Math.floor(Date.now() / 1000) + (input.ttlSeconds ?? 18 * 3600);
  return signToken('thali_rider_', {
    userId: input.riderId,
    riderId: input.riderId,
    providerId: input.providerId,
    phone: input.phone,
    name: input.name,
    email: '',
    role: 'rider',
    exp,
  });
}

export function verifySignedSessionToken(
  token: string,
  expectedPrefix?: 'thali_tok_' | 'thali_rider_'
): SignedSessionPayload | null {
  const trimmed = (token || '').trim();
  const prefix = trimmed.startsWith('thali_tok_')
    ? 'thali_tok_'
    : trimmed.startsWith('thali_rider_')
      ? 'thali_rider_'
      : null;
  if (!prefix) return null;
  if (expectedPrefix && prefix !== expectedPrefix) return null;

  const rest = trimmed.slice(prefix.length);
  const dotIdx = rest.indexOf('.');
  if (dotIdx <= 0) return null;

  const b64 = rest.slice(0, dotIdx);
  const sig = rest.slice(dotIdx + 1);
  if (!b64 || !sig) return null;

  try {
    const expectedSig = crypto
      .createHmac('sha256', getSessionSecret())
      .update(`${prefix}${b64}`)
      .digest('hex');
    if (!timingSafeStringEqual(sig, expectedSig)) return null;

    const payload = JSON.parse(Buffer.from(b64, 'base64url').toString('utf8')) as SignedSessionPayload;
    if (!payload || !payload.userId || !payload.exp) return null;
    if (Math.floor(Date.now() / 1000) > Number(payload.exp)) return null;
    return payload;
  } catch {
    return null;
  }
}

export function verifyAdminOrServiceBearer(token: string): boolean {
  const trimmed = (token || '').trim();
  if (!trimmed) return false;
  const candidates = [process.env.ADMIN_SECRET_KEY, process.env.SUPABASE_SERVICE_ROLE_KEY].filter(
    (v): v is string => Boolean(v && v.trim().length > 0)
  );
  return candidates.some((secret) => timingSafeStringEqual(trimmed, secret.trim()));
}

export type CustomerIdentityResult =
  | { ok: true; userId: string; email: string; isAdmin: boolean }
  | { ok: false; status: 401 | 403; error: string };

export async function requireCustomerIdentity(
  req: NextRequest,
  claimedCustomerId?: string | null
): Promise<CustomerIdentityResult> {
  const claimed = (claimedCustomerId || '').trim();
  const authHeader = req.headers.get('authorization');

  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7).trim();
    if (!token) {
      return { ok: false, status: 401, error: 'Authorization token is empty.' };
    }

    if (verifyAdminOrServiceBearer(token)) {
      return {
        ok: true,
        userId: claimed || 'admin-service',
        email: '',
        isAdmin: true,
      };
    }

    const signed = verifySignedSessionToken(token, 'thali_tok_');
    if (signed) {
      if (signed.role === 'admin') {
        return { ok: true, userId: claimed || signed.userId, email: signed.email, isAdmin: true };
      }
      if (claimed && signed.userId !== claimed) {
        return { ok: false, status: 403, error: 'You cannot access another customer account.' };
      }
      return { ok: true, userId: signed.userId, email: signed.email, isAdmin: false };
    }

    const admin = getAdminClient();
    if (admin) {
      try {
        const {
          data: { user },
          error,
        } = await admin.auth.getUser(token);
        if (!error && user) {
          if (claimed && user.id !== claimed) {
            const { data: adminRole } = await admin
              .from('user_roles')
              .select('role')
              .eq('user_id', user.id)
              .eq('role', 'admin')
              .is('revoked_at', null)
              .maybeSingle();
            if (!adminRole) {
              return { ok: false, status: 403, error: 'You cannot access another customer account.' };
            }
            return { ok: true, userId: claimed, email: user.email || '', isAdmin: true };
          }
          return { ok: true, userId: user.id, email: user.email || '', isAdmin: false };
        }
      } catch {}
    }

    return { ok: false, status: 401, error: 'Session expired or invalid. Please sign in again.' };
  }

  // Next.js SSR Supabase cookies
  try {
    const supabase = await createSessionClient();
    const {
      data: { user },
      error,
    } = await supabase.auth.getUser();
    if (!error && user) {
      if (claimed && user.id !== claimed) {
        return { ok: false, status: 403, error: 'You cannot access another customer account.' };
      }
      return { ok: true, userId: user.id, email: user.email || '', isAdmin: false };
    }
  } catch {}

  return { ok: false, status: 401, error: 'Authentication required. Please sign in.' };
}

export type RiderIdentityResult =
  | { ok: true; riderId: string; providerId: string; phone: string; name: string }
  | { ok: false; status: 401; error: string };

export function requireRiderIdentity(req: NextRequest): RiderIdentityResult {
  const authHeader = req.headers.get('authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return { ok: false, status: 401, error: 'Rider session required. Please log in with mobile and PIN.' };
  }
  const token = authHeader.slice(7).trim();
  const payload = verifySignedSessionToken(token, 'thali_rider_');
  if (!payload || !payload.riderId || !payload.providerId) {
    return { ok: false, status: 401, error: 'Rider session expired. Please sign in again.' };
  }
  return {
    ok: true,
    riderId: payload.riderId,
    providerId: payload.providerId,
    phone: payload.phone || '',
    name: payload.name || 'Rider',
  };
}

export function getClientIp(req: NextRequest): string {
  const xff = req.headers.get('x-forwarded-for');
  if (xff) return xff.split(',')[0].trim();
  const realIp = req.headers.get('x-real-ip');
  return realIp ? realIp.trim() : 'unknown';
}

export function escapeHtml(input: unknown): string {
  return String(input ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export function sanitizePostgrestSearch(input: string): string {
  return String(input || '')
    .replace(/[,().%_\\*]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 80);
}

export function isAllowedMediaUrl(url: string): boolean {
  const trimmed = (url || '').trim();
  if (!trimmed) return true;
  if (trimmed.startsWith('/')) return true;
  if (/^https:\/\//i.test(trimmed)) return true;
  if (/^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?\//i.test(trimmed)) return true;
  if (/^data:image\/(png|jpe?g|webp|gif);base64,[A-Za-z0-9+/=]+$/i.test(trimmed)) {
    return trimmed.length <= 3_000_000;
  }
  return false;
}

/**
 * Links active subscription_plans and active meal_slots in Postgres `plan_meal_slots`
 * so `redeem_meal_atomic` finds valid slot entitlements across plans cleanly.
 */
export async function ensurePlanSlotsLinked(
  admin: NonNullable<ReturnType<typeof getAdminClient>>,
  providerId: string
): Promise<void> {
  try {
    const [{ data: plans }, { data: slots }] = await Promise.all([
      admin.from('subscription_plans').select('id').eq('provider_id', providerId).eq('active', true),
      admin.from('meal_slots').select('id').eq('provider_id', providerId).eq('active', true),
    ]);
    if (!plans?.length || !slots?.length) return;
    const rows: Array<{ plan_id: string; meal_slot_id: string }> = [];
    for (const p of plans) {
      for (const s of slots) {
        rows.push({ plan_id: p.id, meal_slot_id: s.id });
      }
    }
    await admin.from('plan_meal_slots').upsert(rows, { onConflict: 'plan_id,meal_slot_id' });
  } catch {}
}
