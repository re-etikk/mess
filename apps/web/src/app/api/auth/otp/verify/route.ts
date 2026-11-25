import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import crypto from 'crypto';

export const dynamic = 'force-dynamic';

async function findAuthUserByEmail(
  admin: NonNullable<ReturnType<typeof getAdminClient>>,
  email: string
) {
  const perPage = 200;
  for (let page = 1; page <= 100; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage });
    if (error) throw error;
    const user = data.users.find((candidate) => candidate.email?.toLowerCase() === email);
    if (user) return user;
    if (data.users.length < perPage) return null;
  }
  throw new Error('Unable to complete email account lookup.');
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

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(raw)) {
    return NextResponse.json({ success: false, error: 'A valid email address is required. Phone OTP is disabled.' }, { status: 400 });
  }
  const identifier = raw.toLowerCase();

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
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (error || !record) {
      return NextResponse.json(
        { success: false, error: 'No OTP requested for this number or email. Request a new OTP.' },
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

    if (record.otp_code !== otpCode) {
      await admin.from('auth_otps').update({ attempts: (record.attempts || 0) + 1 }).eq('id', record.id);
      return NextResponse.json({ success: false, error: 'Incorrect OTP code. Please check and try again.' }, { status: 400 });
    }

    const secret = process.env.QR_HMAC_SECRET || 'thali-otp-secret-2026';
    const verificationToken = `vt_${crypto.createHmac('sha256', secret).update(`${identifier}:${Date.now()}`).digest('hex')}`;

    await admin
      .from('auth_otps')
      .update({
        verified: true,
        verification_token: verificationToken,
      })
      .eq('id', record.id);

    if (!createSession) {
      return NextResponse.json({
        success: true,
        verified: true,
        verification_token: verificationToken,
        message: 'OTP verified successfully.',
      });
    }

    // Resolve or provision real Supabase user + profile for passwordless OTP login
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
        user_metadata: { role: requestedRole, auth_method: 'otp' },
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

    // Ensure role exists
    await admin
      .from('user_roles')
      .upsert({ user_id: userId, role: requestedRole }, { onConflict: 'user_id,role' })
      .then(() => null, () => null);

    // If partner portal requested, look up owned/managed provider
    if (requestedRole === 'provider') {
      const { data: prov } = await admin
        .from('providers')
        .select('id,display_name,status,locality,city')
        .or(`owner_user_id.eq.${userId},public_email.ilike.${resolvedEmail}`)
        .limit(1)
        .maybeSingle();
      if (prov) providerInfo = prov;
      if (!providerInfo) {
        const { data: mem } = await admin
          .from('provider_memberships')
          .select('provider_id,providers(id,display_name,status,locality,city)')
          .eq('user_id', userId)
          .eq('active', true)
          .limit(1)
          .maybeSingle();
        if (mem?.providers) {
          providerInfo = Array.isArray(mem.providers) ? mem.providers[0] : mem.providers;
        }
      }
      if (!providerInfo && platformStore.providers.size > 0) {
        const inStore = Array.from(platformStore.providers.values()).find((p) => p.email?.toLowerCase() === resolvedEmail);
        if (inStore) providerInfo = { id: inStore.id, display_name: inStore.display_name, status: inStore.status };
      }
    }

    const token = `jwt_session_${Buffer.from(
      JSON.stringify({
        userId,
        email: resolvedEmail,
        role: requestedRole,
        providerId: providerInfo?.id || '',
        provider_id: providerInfo?.id || '',
        verifiedAt: Date.now(),
      })
    ).toString('base64url')}`;

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
        role: requestedRole,
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
