import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import crypto from 'crypto';
import {
  getClientIp,
  signSessionToken,
  timingSafeStringEqual,
} from '@/lib/auth-session';
import { checkRateLimit } from '@/lib/rate-limiter';

export const dynamic = 'force-dynamic';

async function findAuthUserByEmail(
  admin: NonNullable<ReturnType<typeof getAdminClient>>,
  email: string
) {
  const perPage = 200;
  for (let page = 1; page <= 25; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage });
    if (error) throw error;
    const user = data.users.find((candidate) => candidate.email?.toLowerCase() === email);
    if (user) return user;
    if (data.users.length < perPage) return null;
  }
  return null;
}

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body' }, { status: 400 });
  }

  const raw = String(body.identifier || body.email || body.phone || '').trim();
  const otpCode = String(body.otp || body.code || '').trim();
  const createSession = body.create_session === true || body.purpose === 'signin' || body.purpose === 'login';
  const requestedRole = body.role === 'provider' ? 'provider' : 'customer';

  if (!raw || !otpCode) {
    return NextResponse.json({ success: false, error: 'Identifier and OTP code are required.' }, { status: 400 });
  }

  if (Boolean(body.phone) || (!raw.includes('@') && /^\+?[\d\s\-]{7,}$/.test(raw))) {
    return NextResponse.json(
      { success: false, error: 'Phone OTP is disabled. Please sign in with your email address.' },
      { status: 400 }
    );
  }

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(raw)) {
    return NextResponse.json({ success: false, error: 'A valid email address is required.' }, { status: 400 });
  }
  const identifier = raw.toLowerCase();

  const rl = checkRateLimit(`otp_verify:${getClientIp(req)}:${identifier}`, 10, 15 * 60 * 1000);
  if (!rl.isAllowed) {
    return NextResponse.json(
      { success: false, error: 'Too many OTP verification attempts. Request a new code later.' },
      { status: 429 }
    );
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json(
      { success: false, error: 'Authentication service is not configured on this server.' },
      { status: 503 }
    );
  }

  try {
    const { data: record, error } = await admin
      .from('auth_otps')
      .select('*')
      .eq('identifier', identifier)
      .eq('verified', false)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error || !record) {
      return NextResponse.json(
        { success: false, error: 'No active OTP found for this email. Request a new code.' },
        { status: 400 }
      );
    }

    if (new Date(record.expires_at).getTime() < Date.now()) {
      return NextResponse.json({ success: false, error: 'OTP has expired. Please request a new one.' }, { status: 400 });
    }

    if ((record.attempts || 0) >= 5) {
      return NextResponse.json(
        { success: false, error: 'Too many invalid attempts. Please request a new OTP.' },
        { status: 429 }
      );
    }

    const expectedOtp = String(record.otp_code || '').trim();
    if (!timingSafeStringEqual(expectedOtp, otpCode)) {
      await admin
        .from('auth_otps')
        .update({ attempts: (record.attempts || 0) + 1 })
        .eq('id', record.id)
        .eq('verified', false);
      return NextResponse.json({ success: false, error: 'Incorrect OTP code. Please check and try again.' }, { status: 400 });
    }

    const secret =
      process.env.SESSION_SIGNING_SECRET ||
      process.env.QR_SIGNING_SECRET ||
      process.env.QR_HMAC_SECRET ||
      process.env.SUPABASE_SERVICE_ROLE_KEY ||
      (process.env.NODE_ENV === 'test' ? 'test-only-otp-key' : '');
    if (!secret) {
      return NextResponse.json({ success: false, error: 'Verification signing key is not configured.' }, { status: 503 });
    }
    const verificationToken = `vt_${crypto.createHmac('sha256', secret).update(`${identifier}:${record.id}:${Date.now()}`).digest('hex')}`;

    // Single-use claim: conditional update prevents concurrent OTP replay races
    const { data: claimedRow, error: claimErr } = await admin
      .from('auth_otps')
      .update({
        verified: true,
        verification_token: verificationToken,
      })
      .eq('id', record.id)
      .eq('verified', false)
      .select('id')
      .maybeSingle();

    if (claimErr || !claimedRow) {
      return NextResponse.json(
        { success: false, error: 'This OTP has already been used. Please request a new one.' },
        { status: 400 }
      );
    }

    if (!createSession) {
      return NextResponse.json({
        success: true,
        verified: true,
        verification_token: verificationToken,
        message: 'OTP verified successfully.',
      });
    }

    let userId: string | null = null;
    const resolvedEmail = identifier;
    let profile: any = null;
    let providerInfo: any = null;

    const { data: existingProfiles, error: profileLookupError } = await admin
      .from('profiles')
      .select('*')
      .eq('email', identifier)
      .limit(2);
    if (profileLookupError) throw profileLookupError;

    if (existingProfiles?.length === 1) {
      profile = existingProfiles[0];
      userId = profile.id;
    } else {
      const existingUser = await findAuthUserByEmail(admin, identifier);
      if (existingUser) userId = existingUser.id;
      if (existingProfiles?.length) {
        profile = existingProfiles.find((candidate: any) => candidate.id === userId) || null;
      }
    }

    if (existingProfiles?.length && !userId) {
      return NextResponse.json(
        { success: false, error: 'This email has conflicting account records. Please contact support.' },
        { status: 409 }
      );
    }

    if (!userId) {
      const { data: created, error: createErr } = await admin.auth.admin.createUser({
        email: resolvedEmail,
        email_confirm: true,
        user_metadata: { role: 'customer', auth_method: 'otp' },
      });
      if (!createErr && created?.user) {
        userId = created.user.id;
      } else {
        const existingUser = await findAuthUserByEmail(admin, identifier);
        if (existingUser) {
          userId = existingUser.id;
        } else if (createErr) {
          throw createErr;
        }
      }
    }

    if (!userId) {
      return NextResponse.json({ success: false, error: 'Could not provision account. Please try again.' }, { status: 500 });
    }

    if (!profile) {
      const { data: pRow } = await admin.from('profiles').select('*').eq('id', userId).maybeSingle();
      if (pRow) {
        profile = pRow;
      } else {
        const { data: ins, error: insertProfileError } = await admin
          .from('profiles')
          .insert({
            id: userId,
            display_name: '',
            email: resolvedEmail,
            locale: 'en-IN',
            timezone: 'Asia/Kolkata',
          })
          .select('*')
          .single();
        profile = ins;
        if (insertProfileError) {
          const { data: concurrentProfile, error: reloadProfileError } = await admin
            .from('profiles')
            .select('*')
            .eq('id', userId)
            .maybeSingle();
          if (reloadProfileError || !concurrentProfile) throw insertProfileError;
          profile = concurrentProfile;
        }
      }
    }

    if (profile?.email !== resolvedEmail) {
      const { data: updatedProfile, error: profileUpdateError } = await admin
        .from('profiles')
        .update({ email: resolvedEmail })
        .eq('id', userId)
        .select('*')
        .maybeSingle();
      if (profileUpdateError) throw profileUpdateError;
      if (updatedProfile) profile = updatedProfile;
    }

    // Ensure baseline customer role without self-granting provider/admin arbitrarily
    await admin
      .from('user_roles')
      .upsert({ user_id: userId, role: 'customer' }, { onConflict: 'user_id,role' })
      .then(() => null, () => null);

    let effectiveRole: 'customer' | 'provider' = 'customer';

    if (requestedRole === 'provider') {
      const { data: mem } = await admin
        .from('provider_memberships')
        .select('provider_id,providers(id,display_name,status,locality,city)')
        .eq('user_id', userId)
        .eq('active', true)
        .in('role', ['owner', 'manager'])
        .limit(1)
        .maybeSingle();

      if (mem?.providers) {
        providerInfo = Array.isArray(mem.providers) ? mem.providers[0] : mem.providers;
        effectiveRole = 'provider';
      } else {
        const { data: owned } = await admin
          .from('providers')
          .select('id,display_name,status,locality,city')
          .eq('owner_user_id', userId)
          .limit(1)
          .maybeSingle();
        if (owned) {
          providerInfo = owned;
          effectiveRole = 'provider';
        }
      }

      if (!providerInfo && platformStore.providers.size > 0) {
        const inStore = Array.from(platformStore.providers.values()).find(
          (p) => p.owner_user_id === userId || p.email?.toLowerCase() === resolvedEmail
        );
        if (inStore) {
          providerInfo = { id: inStore.id, display_name: inStore.display_name, status: inStore.status };
          effectiveRole = 'provider';
        }
      }
    }

    const token = signSessionToken({
      userId,
      email: resolvedEmail,
      role: effectiveRole,
      providerId: providerInfo?.id,
      name: profile?.display_name || resolvedEmail.split('@')[0],
    });

    const needsProfileSetup = !profile?.display_name || String(profile.display_name).trim().length === 0;

    return NextResponse.json({
      success: true,
      verified: true,
      verification_token: verificationToken,
      token,
      needs_profile_setup: Boolean(needsProfileSetup),
      user: {
        id: userId,
        email: profile?.email || resolvedEmail,
        phone: profile?.phone_e164 || '',
        name: profile?.display_name || '',
        role: effectiveRole,
        provider_id: providerInfo?.id || null,
        provider_name: providerInfo?.display_name || null,
      },
      profile,
      provider: providerInfo,
      message: 'OTP verified successfully.',
    });
  } catch (e: any) {
    console.error('OTP verify error:', e?.message);
    return NextResponse.json({ success: false, error: 'Unable to verify OTP. Please try again.' }, { status: 500 });
  }
}
