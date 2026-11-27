import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { resolveRequestedPortalRole } from '@/lib/auth/portal-role';
import { platformStore } from '@/lib/platform-service';
import {
  getClientIp,
  sanitizePostgrestSearch,
  signSessionToken,
} from '@/lib/auth-session';
import { checkRateLimit } from '@/lib/rate-limiter';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  let body: { email?: string; phone?: string; password?: string; role?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }

  const rawIdentifier = (body.email || body.phone || '').trim();
  const password = body.password;
  const requestedRole = body.role?.trim().toLowerCase();

  if (!rawIdentifier || !password) {
    return NextResponse.json({ success: false, error: 'Email or phone and password are required.' }, { status: 400 });
  }

  const ip = getClientIp(req);
  const rl = checkRateLimit(`login:${ip}:${rawIdentifier.toLowerCase()}`, 10, 15 * 60 * 1000);
  if (!rl.isAllowed) {
    return NextResponse.json(
      { success: false, error: 'Too many login attempts. Please wait a few minutes and try again.' },
      { status: 429 }
    );
  }

  const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(rawIdentifier);
  let email = isEmail ? rawIdentifier.toLowerCase() : '';
  const cleanDigits = rawIdentifier.replace(/\D/g, '');
  const cleanId = sanitizePostgrestSearch(rawIdentifier);

  const admin = getAdminClient();

  if (!email && admin) {
    try {
      if (cleanDigits.length >= 10) {
        const { data: matchedProfile } = await admin
          .from('profiles')
          .select('id,email,phone_e164')
          .ilike('phone_e164', `%${cleanDigits.slice(-10)}`)
          .limit(1)
          .maybeSingle();

        if (matchedProfile?.email) {
          email = matchedProfile.email.toLowerCase();
        } else if (matchedProfile?.id) {
          const { data: userRecord } = await admin.auth.admin.getUserById(matchedProfile.id);
          if (userRecord?.user?.email) {
            email = userRecord.user.email.toLowerCase();
          }
        }
      }

      if (!email && cleanDigits.length >= 10) {
        const { data: matchedProv } = await admin
          .from('providers')
          .select('id,public_email,owner_user_id')
          .ilike('public_phone', `%${cleanDigits.slice(-10)}`)
          .limit(1)
          .maybeSingle();

        if (matchedProv?.public_email) {
          email = matchedProv.public_email.toLowerCase();
        } else if (matchedProv?.owner_user_id) {
          const { data: userRecord } = await admin.auth.admin.getUserById(matchedProv.owner_user_id);
          if (userRecord?.user?.email) {
            email = userRecord.user.email.toLowerCase();
          }
        }
      }
    } catch {}
  }

  if (!email && isEmail && cleanId) {
    email = rawIdentifier.toLowerCase();
  }

  let authUser: { id: string; email?: string } | null = null;
  let authSession: { access_token?: string; refresh_token?: string; expires_at?: number } | null = null;

  if (email) {
    try {
      const supabase = await createClient();
      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (!error && data.user) {
        authUser = data.user;
        authSession = data.session;
      }
    } catch {}
  }

  if (!authUser) {
    return NextResponse.json(
      { success: false, error: 'Invalid email/phone or password. Please verify credentials or sign in via OTP.' },
      { status: 401 }
    );
  }

  const resolvedEmail = (authUser.email || email || rawIdentifier).toLowerCase();
  let resolvedRole: 'customer' | 'provider' | 'admin' = 'customer';
  let providerInfo: { id: string; display_name: string; status: string } | null = null;
  let profileInfo: {
    display_name?: string;
    phone_e164?: string;
    food_preference?: string;
    default_locality?: string;
    default_city?: string;
  } | null = null;

  if (admin && authUser.id) {
    try {
      const [{ data: roles }, { data: memberships }, { data: profile }] = await Promise.all([
        admin.from('user_roles').select('role').eq('user_id', authUser.id).is('revoked_at', null),
        admin.from('provider_memberships').select('provider_id,role').eq('user_id', authUser.id).eq('active', true),
        admin
          .from('profiles')
          .select('display_name,phone_e164,food_preference,default_locality,default_city')
          .eq('id', authUser.id)
          .maybeSingle(),
      ]);

      profileInfo = profile || null;
      const roleNames = new Set((roles ?? []).map((row) => row.role));
      const managementMemberships = (memberships ?? []).filter((m) => ['owner', 'manager'].includes(m.role));

      const calculatedRole = resolveRequestedPortalRole(requestedRole, roleNames, managementMemberships.length);
      if (calculatedRole === 'admin' || calculatedRole === 'provider' || calculatedRole === 'customer') {
        resolvedRole = calculatedRole;
      }

      if (requestedRole === 'provider' && resolvedRole !== 'provider' && resolvedRole !== 'admin') {
        const { data: ownedProv } = await admin
          .from('providers')
          .select('id,display_name,status')
          .eq('owner_user_id', authUser.id)
          .limit(1)
          .maybeSingle();
        if (ownedProv) {
          providerInfo = ownedProv;
          resolvedRole = 'provider';
        }
      } else if (managementMemberships[0]?.provider_id) {
        const { data: prov } = await admin
          .from('providers')
          .select('id,display_name,status')
          .eq('id', managementMemberships[0].provider_id)
          .maybeSingle();
        if (prov) providerInfo = prov;
      }
    } catch {}
  }

  if (!providerInfo && resolvedRole === 'provider' && admin) {
    try {
      const { data: directProv } = await admin
        .from('providers')
        .select('id,display_name,status')
        .eq('owner_user_id', authUser.id)
        .limit(1)
        .maybeSingle();
      if (directProv) providerInfo = directProv;
    } catch {}
  }

  if (!providerInfo && resolvedRole === 'provider') {
    const inStore = platformStore.providers.get(authUser.id);
    if (inStore && inStore.owner_user_id === authUser.id) {
      providerInfo = { id: inStore.id, display_name: inStore.display_name, status: inStore.status || 'active' };
    }
  }

  const token =
    authSession?.access_token ||
    signSessionToken({
      userId: authUser.id,
      email: resolvedEmail,
      role: resolvedRole,
      providerId: providerInfo?.id,
      name: profileInfo?.display_name || resolvedEmail.split('@')[0],
    });

  return NextResponse.json({
    success: true,
    user: {
      id: authUser.id,
      email: resolvedEmail,
      phone: profileInfo?.phone_e164 || '',
      name: profileInfo?.display_name || resolvedEmail.split('@')[0],
      role: resolvedRole,
      provider_id: providerInfo?.id || null,
      provider_name: providerInfo?.display_name || null,
      provider_status: providerInfo?.status || null,
      food_preference: profileInfo?.food_preference || 'veg',
      locality: profileInfo?.default_locality || '',
      city: profileInfo?.default_city || '',
    },
    provider: providerInfo,
    token,
    refresh_token: authSession?.refresh_token || '',
    expires_at: authSession?.expires_at,
    message: 'Login successful.',
  });
}
