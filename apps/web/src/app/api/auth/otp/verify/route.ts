import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import crypto from 'crypto';

export const dynamic = 'force-dynamic';

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

  const isEmail = raw.includes('@');
  const cleanPhone = raw.replace(/\D/g, '');
  const identifier = isEmail ? raw.toLowerCase() : cleanPhone.slice(-10);

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
    let resolvedEmail = isEmail ? identifier : `${identifier}@phone.thali.store`;
    let profile: any = null;
    let providerInfo: any = null;

    if (isEmail) {
      const { data: existingProf } = await admin
        .from('profiles')
        .select('*')
        .ilike('email', identifier)
        .maybeSingle()
        .then((r) => r, () => ({ data: null }));
      if (existingProf) {
        userId = existingProf.id;
        profile = existingProf;
      }
      if (!userId) {
        const { data: usersList } = await admin.auth.admin.listUsers({ perPage: 200 });
        const matched = usersList?.users?.find((u) => u.email?.toLowerCase() === identifier);
        if (matched) userId = matched.id;
      }
    } else {
      const { data: existingProf } = await admin
        .from('profiles')
        .select('*')
        .ilike('phone_e164', `%${identifier}%`)
        .limit(1)
        .maybeSingle();
      if (existingProf) {
        userId = existingProf.id;
        profile = existingProf;
      }
    }

    if (!userId) {
      const { data: created, error: createErr } = await admin.auth.admin.createUser({
        email: resolvedEmail,
        email_confirm: true,
        phone: isEmail ? undefined : `+91${identifier}`,
        user_metadata: { role: requestedRole, auth_method: 'otp' },
      });
      if (!createErr && created?.user) {
        userId = created.user.id;
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
        const { data: ins } = await admin
          .from('profiles')
          .insert({
            id: userId,
            display_name: '',
            phone_e164: isEmail ? null : `+91${identifier}`,
            locale: 'en-IN',
            timezone: 'Asia/Kolkata',
          })
          .select('*')
          .single();
        profile = ins;
      }
      // Best-effort save email column if migration ran
      if (isEmail) {
        await admin.from('profiles').update({ email: resolvedEmail }).eq('id', userId).then(() => null, () => null);
      }
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
        phone: profile?.phone_e164 || (isEmail ? '' : `+91${identifier}`),
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
