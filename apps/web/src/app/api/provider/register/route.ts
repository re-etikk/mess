import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { getClientIp, signSessionToken } from '@/lib/auth-session';
import { checkRateLimit } from '@/lib/rate-limiter';
import { sendProviderApprovalNotice } from '@/lib/notifications';
import { platformStore } from '@/lib/platform-service';
import { getPlatformAppConfig } from '@/lib/app-config';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  const rl = checkRateLimit(`provider-register:${getClientIp(req)}`, 6, 15 * 60 * 1000);
  if (!rl.isAllowed) {
    return NextResponse.json({ success: false, error: 'Too many registration requests. Please wait before retrying.' }, { status: 429 });
  }

  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid request format.' }, { status: 400 });
  }

  const businessName = String(body.business_name || body.display_name || '').trim();
  const ownerName = String(body.name || body.owner_name || '').trim();
  const email = String(body.email || '').trim().toLowerCase();
  const password = String(body.password || '');
  const phone = String(body.phone || '').trim();
  const addressLine1 = String(body.address || body.address_line1 || '').trim();
  const city = String(body.city || '').trim();
  const locality = String(body.locality || addressLine1 || '').trim();
  const state = String(body.state || '').trim() || 'India';
  const pincode = String(body.pincode || '').replace(/\D/g, '').slice(0, 6) || '000000';
  const supportsDelivery = body.supports_delivery === true;
  const supportsPickup = body.supports_pickup !== false;

  const phoneDigits = phone.replace(/\D/g, '');
  const normalizedPhoneDigits =
    phoneDigits.length === 11 && phoneDigits.startsWith('0') ? phoneDigits.slice(1) : phoneDigits;

  if (!businessName || !ownerName || !email.includes('@') || password.length < 8) {
    return NextResponse.json(
      { success: false, error: 'Kitchen name, owner name, valid email, and password (min 8 chars) are required.' },
      { status: 400 }
    );
  }
  if (normalizedPhoneDigits.length < 10 || normalizedPhoneDigits.length > 15) {
    return NextResponse.json(
      { success: false, error: 'Enter a valid 10-digit mobile number.' },
      { status: 400 }
    );
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json(
      { success: false, error: 'Server registration requires Supabase service credentials to be configured.' },
      { status: 503 }
    );
  }

  try {
    const cleanDigits = phone.replace(/\D/g, '').slice(-10);
    const phoneE164 = cleanDigits.length === 10 ? `+91${cleanDigits}` : phone || null;

    const { data: createdAuth, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      phone: phoneE164 || undefined,
      user_metadata: { display_name: ownerName, role: 'provider', business_name: businessName },
    });

    if (createErr || !createdAuth?.user) {
      return NextResponse.json(
        { success: false, error: createErr?.message || 'An account with this email may already exist. Try signing in.' },
        { status: 400 }
      );
    }

    const userId = createdAuth.user.id;
    await admin.from('profiles').upsert({
      id: userId,
      display_name: ownerName,
      email,
      phone_e164: phoneE164,
      locale: 'en-IN',
      timezone: 'Asia/Kolkata',
    });

    await admin
      .from('user_roles')
      .upsert({ user_id: userId, role: 'provider' }, { onConflict: 'user_id,role' });

    const slugBase = businessName
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');
    const slug = `${slugBase || 'kitchen'}-${Date.now().toString(36).slice(-4)}`;

    const appCfg = await getPlatformAppConfig(admin);
    const requiresApproval = appCfg.require_provider_approval !== false;
    const initialStatus: 'pending_review' | 'active' = requiresApproval ? 'pending_review' : 'active';

    const { data: prov, error: provErr } = await admin
      .from('providers')
      .insert({
        owner_user_id: userId,
        display_name: businessName,
        slug,
        public_phone: phoneE164,
        public_email: email,
        address_line1: addressLine1 || city,
        locality,
        city: city || locality,
        state,
        pincode,
        supports_pickup: supportsPickup,
        supports_delivery: supportsDelivery,
        status: initialStatus,
        approved_at: initialStatus === 'active' ? new Date().toISOString() : null,
      })
      .select('*')
      .single();

    if (provErr || !prov) {
      return NextResponse.json(
        { success: false, error: provErr?.message || 'Could not create kitchen profile.' },
        { status: 500 }
      );
    }

    await admin.from('provider_memberships').upsert(
      { provider_id: prov.id, user_id: userId, role: 'owner', active: true },
      { onConflict: 'provider_id,user_id' }
    );

    await admin.from('meal_slots').insert([
      { provider_id: prov.id, name: 'breakfast', starts_at_local: '07:30:00', ends_at_local: '10:00:00', active: true },
      { provider_id: prov.id, name: 'lunch', starts_at_local: '12:00:00', ends_at_local: '15:00:00', active: true },
      { provider_id: prov.id, name: 'dinner', starts_at_local: '19:30:00', ends_at_local: '22:30:00', active: true },
    ]);

    platformStore.providers.set(prov.id, {
      id: prov.id,
      owner_user_id: userId,
      display_name: prov.display_name,
      slug: prov.slug || slug,
      description: 'Home-style daily tiffin & mess meals.',
      email,
      phone: phoneE164 || '',
      address: [addressLine1, locality, city].filter(Boolean).join(', '),
      locality,
      city: prov.city || '',
      rating: 4.5,
      total_reviews: 0,
      cuisines: ['Home-style Indian'],
      dietary_types: ['veg'],
      status: initialStatus,
      created_at: new Date().toISOString(),
    });

    await sendProviderApprovalNotice({
      provider_name: businessName,
      phone: phoneE164 || '',
      email,
      user_id: userId,
    }).catch(() => null);

    const token = signSessionToken({
      userId,
      email,
      role: 'provider',
      providerId: prov.id,
      name: ownerName,
    });

    const regRes = NextResponse.json(
      {
        success: true,
        requires_approval: requiresApproval,
        token,
        user: { id: userId, email, name: ownerName, role: 'provider', provider_id: prov.id, provider_name: businessName, provider_status: initialStatus },
        provider: prov,
        message: requiresApproval
          ? 'Kitchen application submitted for admin verification.'
          : 'Kitchen registered and ready.',
      },
      { status: 201 }
    );
    regRes.cookies.set('thali_session_token', token, {
      httpOnly: true,
      sameSite: 'lax',
      path: '/',
      maxAge: 30 * 86400,
      secure: process.env.NODE_ENV === 'production',
    });
    return regRes;
  } catch (e: any) {
    return NextResponse.json(
      { success: false, error: e?.message || 'Kitchen registration failed. Please try again.' },
      { status: 500 }
    );
  }
}
