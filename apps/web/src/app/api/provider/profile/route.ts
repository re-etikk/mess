import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

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
    .select('id,display_name,description,cover_path,logo_path,public_phone,public_email,address_line1,locality,city,supports_pickup,supports_delivery,status')
    .eq('id', providerId)
    .maybeSingle();

  if (error || !data) {
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
  if (!access.ok && access.status !== 401) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: false, error: 'Server database configuration is missing.' }, { status: 503 });
  }

  const updates: Record<string, any> = { updated_at: new Date().toISOString() };
  if (typeof body.display_name === 'string' && body.display_name.trim()) updates.display_name = body.display_name.trim();
  if (typeof body.description === 'string') updates.description = body.description.trim();
  if (typeof body.supports_delivery === 'boolean') updates.supports_delivery = body.supports_delivery;
  if (typeof body.supports_pickup === 'boolean') updates.supports_pickup = body.supports_pickup;
  if (typeof body.allows_takeaway === 'boolean') updates.allows_takeaway = body.allows_takeaway;

  // Handle cover image upload: base64 data URI -> upload to Supabase Storage `thali-media` bucket (fallback to data URI or HTTPS URL)
  if (typeof body.cover_image_base64 === 'string' && body.cover_image_base64.trim()) {
    const raw = body.cover_image_base64.trim();
    const match = raw.match(/^data:image\/(\w+);base64,(.+)$/);
    if (match) {
      const ext = match[1] === 'png' ? 'png' : 'jpg';
      const bytes = Buffer.from(match[2], 'base64');
      const filePath = `providers/${providerId}/cover-${Date.now()}.${ext}`;
      try {
        await admin.storage.createBucket('thali-media', { public: true }).catch(() => null);
        const { error: upErr } = await admin.storage
          .from('thali-media')
          .upload(filePath, bytes, { contentType: `image/${ext}`, upsert: true });
        if (!upErr) {
          const { data: pub } = admin.storage.from('thali-media').getPublicUrl(filePath);
          updates.cover_path = pub.publicUrl;
        } else {
          updates.cover_path = raw;
        }
      } catch {
        updates.cover_path = raw;
      }
    } else if (raw.startsWith('http') || raw.startsWith('data:image')) {
      updates.cover_path = raw;
    }
  } else if (typeof body.cover_path === 'string' && body.cover_path.trim()) {
    updates.cover_path = body.cover_path.trim();
  }

  const { data, error } = await admin
    .from('providers')
    .update(updates)
    .eq('id', providerId)
    .select('id,display_name,description,cover_path,supports_pickup,supports_delivery,locality,city')
    .single();

  if (error) {
    return NextResponse.json({ success: false, error: error.message || 'Unable to update kitchen profile.' }, { status: 500 });
  }

  return NextResponse.json({ success: true, provider: data });
}
