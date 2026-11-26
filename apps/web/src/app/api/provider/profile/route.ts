import crypto from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';
import {
  isAllowedMediaUrl,
  publicErrorMessage,
  timingSafeStringEqual,
} from '@/lib/auth-session';

export const dynamic = 'force-dynamic';
export const fetchCache = 'force-no-store';

const PROFILE_SELECT_COLS =
  'id,display_name,description,cover_path,logo_path,public_phone,public_email,address_line1,locality,city,supports_pickup,supports_delivery,status';

async function resolveUploadedMedia(
  admin: NonNullable<ReturnType<typeof getAdminClient>>,
  providerId: string,
  kind: 'cover' | 'logo',
  rawInput: string
): Promise<{ ok: true; url: string } | { ok: false; error: string }> {
  const raw = rawInput.trim();
  if (raw.length > 3_500_000) {
    return { ok: false, error: `${kind === 'cover' ? 'Cover' : 'Profile'} image exceeds 2.5 MB limit.` };
  }
  const match = raw.match(/^data:image\/(png|jpe?g|webp);base64,(.+)$/i);
  if (match) {
    const ext = match[1].toLowerCase() === 'png' ? 'png' : 'jpg';
    const bytes = Buffer.from(match[2], 'base64');
    const filePath = `providers/${providerId}/${kind}-${Date.now()}.${ext}`;
    try {
      await admin.storage.createBucket('thali-media', { public: true }).catch(() => null);
      await admin.storage.updateBucket('thali-media', { public: true }).catch(() => null);
      const { error: upErr } = await admin.storage
        .from('thali-media')
        .upload(filePath, bytes, { contentType: `image/${ext === 'png' ? 'png' : 'jpeg'}`, upsert: true });
      if (!upErr) {
        const { data: pub } = admin.storage.from('thali-media').getPublicUrl(filePath);
        if (pub?.publicUrl) return { ok: true, url: pub.publicUrl };
      } else {
        console.warn(`Storage upload (${kind}) fell back cleanly:`, upErr.message);
      }
      return { ok: true, url: raw };
    } catch {
      return { ok: true, url: raw };
    }
  }
  if (isAllowedMediaUrl(raw)) {
    return { ok: true, url: raw };
  }
  return { ok: false, error: 'Unsupported image URL or format.' };
}

async function verifyProfileEmailOtp(
  admin: NonNullable<ReturnType<typeof getAdminClient>>,
  candidateEmails: string[],
  otpCode: string
): Promise<{ ok: true } | { ok: false; error: string }> {
  const cleanCode = otpCode.trim();
  const emails = Array.from(new Set(candidateEmails.map((e) => e.trim().toLowerCase()).filter((e) => e.includes('@'))));
  if (!emails.length || !/^\d{6}$/.test(cleanCode)) {
    return { ok: false, error: 'Enter the 6-digit verification code sent to your email.' };
  }

  const { data: rows, error } = await admin
    .from('auth_otps')
    .select('id,identifier,otp_code,expires_at,verified,attempts,created_at')
    .in('identifier', emails)
    .eq('verified', false)
    .order('created_at', { ascending: false })
    .limit(5);

  if (error) {
    console.error('Profile OTP check failed:', error.message);
    return { ok: false, error: 'Could not verify code right now. Please try again.' };
  }

  const activeRows = (rows ?? []).filter((r: any) => new Date(r.expires_at).getTime() >= Date.now());
  if (!activeRows.length) {
    return { ok: false, error: 'Request and enter a valid 6-digit email verification code first.' };
  }

  if ((activeRows[0].attempts || 0) >= 5) {
    return { ok: false, error: 'Too many invalid attempts. Request a new verification code.' };
  }

  const matched = activeRows.find((r: any) => timingSafeStringEqual(String(r.otp_code || '').trim(), cleanCode));
  if (!matched) {
    await admin
      .from('auth_otps')
      .update({ attempts: (activeRows[0].attempts || 0) + 1 })
      .eq('id', activeRows[0].id)
      .eq('verified', false)
      .then(() => null, () => null);
    return { ok: false, error: 'Incorrect verification code. Please check your email and try again.' };
  }

  const secret =
    process.env.SESSION_SIGNING_SECRET ||
    process.env.QR_SIGNING_SECRET ||
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    'profile-verify';
  const vt = `vt_prof_${crypto.createHmac('sha256', secret).update(`${matched.id}:${Date.now()}`).digest('hex').slice(0, 24)}`;

  const { data: claimed } = await admin
    .from('auth_otps')
    .update({ verified: true, verification_token: vt })
    .eq('id', matched.id)
    .eq('verified', false)
    .select('id')
    .maybeSingle();

  if (!claimed) {
    return { ok: false, error: 'This code was already used. Request a new code.' };
  }

  await admin
    .from('auth_otps')
    .update({ verified: true })
    .eq('identifier', matched.identifier)
    .eq('verified', false)
    .then(() => null, () => null);

  return { ok: true };
}

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id')?.trim();
  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: false, error: 'Server database configuration is missing.' }, { status: 503 });
  }

  const { data, error } = await admin
    .from('providers')
    .select(PROFILE_SELECT_COLS)
    .eq('id', providerId)
    .maybeSingle();

  if (error) {
    console.error('Kitchen profile GET failed:', error.message);
    return NextResponse.json(
      { success: false, error: publicErrorMessage(error, 'Unable to load kitchen settings. Please try again.') },
      { status: 503 }
    );
  }
  if (!data) {
    return NextResponse.json({ success: false, error: 'Kitchen profile not found.' }, { status: 404 });
  }

  return NextResponse.json({ success: true, provider: data }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = String(body.provider_id || '').trim();
  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: false, error: 'Server database configuration is missing.' }, { status: 503 });
  }

  const { data: existing, error: fetchErr } = await admin
    .from('providers')
    .select('id,owner_user_id,display_name,public_phone,public_email,cover_path,logo_path')
    .eq('id', providerId)
    .maybeSingle();

  if (fetchErr || !existing) {
    if (fetchErr) console.error('Kitchen lookup failed:', fetchErr.message);
    return NextResponse.json(
      { success: false, error: 'Unable to load kitchen record. Please try again.' },
      { status: fetchErr ? 503 : 404 }
    );
  }

  const updates: Record<string, any> = { updated_at: new Date().toISOString() };
  if (typeof body.display_name === 'string' && body.display_name.trim()) updates.display_name = body.display_name.trim();
  if (typeof body.description === 'string') updates.description = body.description.trim();
  if (typeof body.address_line1 === 'string') updates.address_line1 = body.address_line1.trim();
  if (typeof body.locality === 'string') updates.locality = body.locality.trim();
  if (typeof body.city === 'string') updates.city = body.city.trim();
  if (typeof body.supports_delivery === 'boolean') updates.supports_delivery = body.supports_delivery;
  if (typeof body.supports_pickup === 'boolean') updates.supports_pickup = body.supports_pickup;
  if (typeof body.allows_takeaway === 'boolean') updates.allows_takeaway = body.allows_takeaway;

  // Handle contact phone / email edits — require email confirmation OTP
  const nextPhoneRaw = typeof body.public_phone === 'string' ? body.public_phone.trim() : undefined;
  const nextEmailRaw = typeof body.public_email === 'string' ? body.public_email.trim().toLowerCase() : undefined;

  const phoneChanged = nextPhoneRaw !== undefined && nextPhoneRaw !== String(existing.public_phone || '').trim();
  const emailChanged = nextEmailRaw !== undefined && nextEmailRaw !== String(existing.public_email || '').trim().toLowerCase();

  if (phoneChanged || emailChanged) {
    if (nextEmailRaw !== undefined && nextEmailRaw.length > 0 && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(nextEmailRaw)) {
      return NextResponse.json({ success: false, error: 'Please enter a valid contact email address.' }, { status: 400 });
    }
    if (nextPhoneRaw !== undefined && nextPhoneRaw.length > 0 && nextPhoneRaw.replace(/\D/g, '').length < 10) {
      return NextResponse.json({ success: false, error: 'Please enter a valid 10-digit phone number.' }, { status: 400 });
    }

    let ownerProfileEmail = '';
    if (existing.owner_user_id) {
      const { data: prof } = await admin
        .from('profiles')
        .select('email')
        .eq('id', existing.owner_user_id)
        .maybeSingle();
      ownerProfileEmail = String(prof?.email || '').trim().toLowerCase();
    }

    const otpCode = String(body.otp_code || body.verification_otp || '').trim();
    const candidateEmails = [
      String(body.verification_email || '').trim().toLowerCase(),
      String(access.email || '').trim().toLowerCase(),
      ownerProfileEmail,
      String(existing.public_email || '').trim().toLowerCase(),
      ...(emailChanged && nextEmailRaw ? [nextEmailRaw] : []),
    ].filter(Boolean);

    if (!otpCode) {
      return NextResponse.json(
        {
          success: false,
          requires_otp: true,
          verification_email: access.email || ownerProfileEmail || existing.public_email || '',
          error: 'Email verification code is required before changing contact details.',
        },
        { status: 400 }
      );
    }

    const otpCheck = await verifyProfileEmailOtp(admin, candidateEmails, otpCode);
    if (!otpCheck.ok) {
      return NextResponse.json({ success: false, requires_otp: true, error: otpCheck.error }, { status: 400 });
    }

    if (phoneChanged) updates.public_phone = nextPhoneRaw || null;
    if (emailChanged) updates.public_email = nextEmailRaw || null;
  }

  // Handle cover image upload
  if (typeof body.cover_image_base64 === 'string' && body.cover_image_base64.trim()) {
    const res = await resolveUploadedMedia(admin, providerId, 'cover', body.cover_image_base64);
    if (!res.ok) return NextResponse.json({ success: false, error: res.error }, { status: 400 });
    updates.cover_path = res.url;
  } else if (typeof body.cover_path === 'string' && body.cover_path.trim()) {
    const trimmed = body.cover_path.trim();
    if (!isAllowedMediaUrl(trimmed)) {
      return NextResponse.json({ success: false, error: 'Invalid cover image URL.' }, { status: 400 });
    }
    updates.cover_path = trimmed;
  }

  // Handle kitchen DP / logo upload
  const rawLogoB64 =
    typeof body.logo_image_base64 === 'string' && body.logo_image_base64.trim()
      ? body.logo_image_base64
      : typeof body.avatar_image_base64 === 'string' && body.avatar_image_base64.trim()
        ? body.avatar_image_base64
        : '';
  if (rawLogoB64) {
    const res = await resolveUploadedMedia(admin, providerId, 'logo', rawLogoB64);
    if (!res.ok) return NextResponse.json({ success: false, error: res.error }, { status: 400 });
    updates.logo_path = res.url;
  } else if (typeof body.logo_path === 'string' && body.logo_path.trim()) {
    const trimmed = body.logo_path.trim();
    if (!isAllowedMediaUrl(trimmed)) {
      return NextResponse.json({ success: false, error: 'Invalid kitchen photo URL.' }, { status: 400 });
    }
    updates.logo_path = trimmed;
  }

  const { data, error } = await admin
    .from('providers')
    .update(updates)
    .eq('id', providerId)
    .select(PROFILE_SELECT_COLS)
    .single();

  if (error) {
    console.error('Kitchen profile update failed:', error.message);
    return NextResponse.json(
      { success: false, error: publicErrorMessage(error, 'Unable to update kitchen profile right now. Please try again.') },
      { status: 503 }
    );
  }

  return NextResponse.json({
    success: true,
    provider: data,
    cover_path: data?.cover_path ?? null,
    logo_path: data?.logo_path ?? null,
  });
}
