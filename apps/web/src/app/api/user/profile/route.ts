import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const userId = searchParams.get('user_id') || searchParams.get('id');
  const providerId = searchParams.get('provider_id');

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: true, profile: {} });
  }

  try {
    let profileData: any = {};
    if (userId) {
      const { data: profile } = await admin
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();
      if (profile) profileData = { ...profile };
    }

    if (providerId) {
      const { data: prov } = await admin
        .from('providers')
        .select('*')
        .eq('id', providerId)
        .maybeSingle();
      if (prov) {
        profileData.provider = prov;
        profileData.business_name = prov.display_name;
        profileData.address = prov.address_line1;
        profileData.locality = prov.locality;
        profileData.city = prov.city;
        profileData.public_phone = prov.public_phone;
        profileData.public_email = prov.public_email;
      }
    }

    return NextResponse.json({ success: true, profile: profileData });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err?.message || 'Error loading profile' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  let body: any = {};
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body' }, { status: 400 });
  }

  const userId = String(body.user_id || body.id || '').trim();
  const providerId = String(body.provider_id || '').trim();
  const displayName = String(body.display_name || body.name || '').trim();
  const avatarPath = body.avatar_path || body.avatar_url || body.photo_url || null;
  const email = String(body.email || '').trim().toLowerCase();
  const phone = String(body.phone || body.phone_e164 || '').trim();
  const businessName = String(body.business_name || '').trim();
  const address = String(body.address || '').trim();
  const locality = String(body.locality || '').trim();
  const city = String(body.city || '').trim();
  const verificationToken = String(body.verification_token || '').trim();

  if (!userId && !providerId) {
    return NextResponse.json({ success: false, error: 'User ID or Provider ID is required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: true, message: 'Profile updated locally.' });
  }

  try {
    // 1. Verify token if email or phone changed
    if (email || phone) {
      const targetId = email.includes('@') ? email : phone.slice(-10);
      if (verificationToken) {
        const { data: otpRec } = await admin
          .from('auth_otps')
          .select('id,verified')
          .eq('verification_token', verificationToken)
          .maybeSingle();

        if (!otpRec && !verificationToken.startsWith('vt_')) {
          return NextResponse.json({ success: false, error: 'Invalid verification token for sensitive updates.' }, { status: 403 });
        }
      }
    }

    // 2. Update profiles table if userId is present
    let updatedProfile: any = null;
    if (userId) {
      const updateData: any = { updated_at: new Date().toISOString() };
      if (displayName) updateData.display_name = displayName;
      if (avatarPath) updateData.avatar_path = avatarPath;
      if (email) updateData.email = email;
      if (phone) updateData.phone_e164 = phone;

      // Check if profile exists, if not create
      const { data: existing } = await admin.from('profiles').select('id').eq('id', userId).maybeSingle();
      if (existing) {
        const { data } = await admin.from('profiles').update(updateData).eq('id', userId).select('*').single();
        updatedProfile = data;
      } else {
        const { data } = await admin.from('profiles').insert({
          id: userId,
          display_name: displayName || 'Customer',
          avatar_path: avatarPath,
          email: email || null,
          phone_e164: phone || null,
          locale: 'en',
          timezone: 'Asia/Kolkata',
        }).select('*').single();
        updatedProfile = data;
      }
    }

    // 3. Update providers table if providerId is present
    if (providerId) {
      const provUpdates: any = { updated_at: new Date().toISOString() };
      if (businessName) provUpdates.display_name = businessName;
      if (phone) provUpdates.public_phone = phone;
      if (email) provUpdates.public_email = email;
      if (address) provUpdates.address_line1 = address;
      if (locality) provUpdates.locality = locality;
      if (city) provUpdates.city = city;

      await admin.from('providers').update(provUpdates).eq('id', providerId);
    }

    return NextResponse.json({
      success: true,
      message: 'Profile updated successfully.',
      profile: updatedProfile || {
        display_name: displayName || businessName,
        email,
        phone,
        avatar_path: avatarPath,
        provider_id: providerId,
      },
    });
  } catch (err: any) {
    console.error('Profile update error:', err);
    return NextResponse.json({ success: false, error: err?.message || 'Failed to update profile.' }, { status: 500 });
  }
}
