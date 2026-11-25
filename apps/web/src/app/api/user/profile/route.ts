import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const userId = searchParams.get('user_id') || searchParams.get('id');
  const providerId = searchParams.get('provider_id');

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: false, error: 'Database client is not configured.' }, { status: 503 });
  }

  try {
    let profileData: any = {};
    let addresses: any[] = [];

    if (userId) {
      const [{ data: profile }, { data: addrRows }] = await Promise.all([
        admin.from('profiles').select('*').eq('id', userId).maybeSingle(),
        admin.from('customer_addresses').select('*').eq('customer_id', userId).order('is_default', { ascending: false }).limit(20),
      ]);
      if (profile) profileData = { ...profile };
      addresses = addrRows ?? [];
    }

    if (providerId) {
      const { data: prov } = await admin.from('providers').select('*').eq('id', providerId).maybeSingle();
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

    return NextResponse.json({ success: true, profile: profileData, addresses }, { headers: { 'Cache-Control': 'private, no-store' } });
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
  const displayName = body.display_name !== undefined ? String(body.display_name || '').trim() : body.name !== undefined ? String(body.name || '').trim() : undefined;
  const avatarPath = body.avatar_path || body.avatar_url || body.photo_url || undefined;
  const email = body.email !== undefined ? String(body.email || '').trim().toLowerCase() : undefined;
  const phone = body.phone !== undefined ? String(body.phone || '').trim() : body.phone_e164 !== undefined ? String(body.phone_e164 || '').trim() : undefined;
  const foodPreference = body.food_preference ? String(body.food_preference).trim().toLowerCase() : undefined;
  const onboardingCompleted = typeof body.onboarding_completed === 'boolean' ? body.onboarding_completed : undefined;

  const businessName = body.business_name !== undefined ? String(body.business_name).trim() : undefined;
  const address = body.address !== undefined ? String(body.address).trim() : body.address_line1 !== undefined ? String(body.address_line1).trim() : undefined;
  const locality = body.locality !== undefined ? String(body.locality).trim() : undefined;
  const city = body.city !== undefined ? String(body.city).trim() : undefined;
  const latitude = body.latitude != null ? Number(body.latitude) : undefined;
  const longitude = body.longitude != null ? Number(body.longitude) : undefined;

  if (!userId && !providerId) {
    return NextResponse.json({ success: false, error: 'User ID or Provider ID is required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: false, error: 'Database client is not configured.' }, { status: 503 });
  }

  try {
    let updatedProfile: any = null;
    if (userId) {
      const coreUpdate: any = { updated_at: new Date().toISOString() };
      if (displayName !== undefined) coreUpdate.display_name = displayName;
      if (avatarPath !== undefined) coreUpdate.avatar_path = avatarPath;
      if (phone !== undefined && phone.length >= 7) coreUpdate.phone_e164 = phone;

      const extendedUpdate: any = { ...coreUpdate };
      if (email) extendedUpdate.email = email;
      if (foodPreference) extendedUpdate.food_preference = foodPreference;
      if (onboardingCompleted !== undefined) extendedUpdate.onboarding_completed = onboardingCompleted;
      if (address !== undefined) extendedUpdate.default_address = address;
      if (locality !== undefined) extendedUpdate.default_locality = locality;
      if (city !== undefined) extendedUpdate.default_city = city;
      if (latitude !== undefined && !isNaN(latitude)) extendedUpdate.latitude = latitude;
      if (longitude !== undefined && !isNaN(longitude)) extendedUpdate.longitude = longitude;

      const { data: existing } = await admin.from('profiles').select('id').eq('id', userId).maybeSingle();
      if (existing) {
        const res = await admin.from('profiles').update(extendedUpdate).eq('id', userId).select('*').single();
        if (!res.error) {
          updatedProfile = res.data;
        } else {
          const resCore = await admin.from('profiles').update(coreUpdate).eq('id', userId).select('*').single();
          updatedProfile = resCore.data;
        }
      } else {
        const res = await admin
          .from('profiles')
          .insert({
            id: userId,
            display_name: displayName || '',
            avatar_path: avatarPath || null,
            phone_e164: phone && phone.length >= 7 ? phone : null,
            locale: 'en-IN',
            timezone: 'Asia/Kolkata',
            ...(foodPreference ? { food_preference: foodPreference } : {}),
            ...(onboardingCompleted !== undefined ? { onboarding_completed: onboardingCompleted } : {}),
          })
          .select('*')
          .single();
        updatedProfile = res.data;
      }

      // If locality / address updated during setup, upsert default address cleanly
      if (locality || address) {
        const addrLine = address || locality || '';
        const { data: existingAddr } = await admin
          .from('customer_addresses')
          .select('id')
          .eq('customer_id', userId)
          .eq('is_default', true)
          .maybeSingle();

        const addrPayload: any = {
          customer_id: userId,
          label: String(body.address_label || 'Home'),
          recipient_name: displayName || updatedProfile?.display_name || 'Customer',
          recipient_phone_e164: phone || updatedProfile?.phone_e164 || '+919999999999',
          address_line1: addrLine || locality || 'Default Address',
          locality: locality || addrLine || 'Local Area',
          city: city || 'City',
          state: String(body.state || 'Maharashtra'),
          pincode: String(body.pincode || '425001'),
          latitude: latitude !== undefined && !isNaN(latitude) ? latitude : null,
          longitude: longitude !== undefined && !isNaN(longitude) ? longitude : null,
          is_default: true,
        };
        if (existingAddr) {
          await admin.from('customer_addresses').update(addrPayload).eq('id', existingAddr.id);
        } else {
          await admin.from('customer_addresses').insert(addrPayload);
        }
      }
    }

    if (providerId) {
      const provUpdate: any = { updated_at: new Date().toISOString() };
      if (businessName) provUpdate.display_name = businessName;
      if (address) provUpdate.address_line1 = address;
      if (locality) provUpdate.locality = locality;
      if (city) provUpdate.city = city;
      if (phone) provUpdate.public_phone = phone;
      if (email) provUpdate.public_email = email;
      if (latitude !== undefined && !isNaN(latitude)) provUpdate.latitude = latitude;
      if (longitude !== undefined && !isNaN(longitude)) provUpdate.longitude = longitude;
      if (typeof body.supports_pickup === 'boolean') provUpdate.supports_pickup = body.supports_pickup;
      if (typeof body.supports_delivery === 'boolean') provUpdate.supports_delivery = body.supports_delivery;
      if (typeof body.description === 'string') provUpdate.description = body.description;
      await admin.from('providers').update(provUpdate).eq('id', providerId);
    }

    return NextResponse.json({ success: true, profile: updatedProfile, message: 'Profile saved successfully.' });
  } catch (err: any) {
    console.error('Profile POST error:', err?.message);
    return NextResponse.json({ success: false, error: err?.message || 'Error updating profile' }, { status: 500 });
  }
}
