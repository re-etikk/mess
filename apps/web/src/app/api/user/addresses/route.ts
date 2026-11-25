import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const customerId = new URL(req.url).searchParams.get('customer_id')?.trim();
  if (!customerId) {
    return NextResponse.json({ success: false, error: 'customer_id is required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: true, addresses: [] });
  }

  const { data, error } = await admin
    .from('customer_addresses')
    .select('*')
    .eq('customer_id', customerId)
    .order('is_default', { ascending: false })
    .order('created_at', { ascending: false });

  if (error) {
    return NextResponse.json({ success: false, error: 'Unable to fetch saved addresses.' }, { status: 500 });
  }

  return NextResponse.json({ success: true, addresses: data ?? [] }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const customerId = String(body.customer_id || '').trim();
  const addressLine1 = String(body.address_line1 || body.address || '').trim();
  const locality = String(body.locality || '').trim();
  const city = String(body.city || '').trim();

  if (!customerId || (!addressLine1 && !locality)) {
    return NextResponse.json({ success: false, error: 'customer_id and locality/address are required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json({ success: false, error: 'Database unavailable.' }, { status: 503 });
  }

  const setDefault = body.is_default === true;
  if (setDefault) {
    await admin.from('customer_addresses').update({ is_default: false }).eq('customer_id', customerId);
  }

  const payload: any = {
    customer_id: customerId,
    label: String(body.label || 'Home'),
    recipient_name: String(body.recipient_name || 'Customer'),
    recipient_phone_e164: String(body.recipient_phone_e164 || '+919999999999'),
    address_line1: addressLine1 || locality,
    address_line2: body.address_line2 ? String(body.address_line2) : null,
    locality: locality || addressLine1,
    city: city || 'City',
    state: String(body.state || 'Maharashtra'),
    pincode: String(body.pincode || '425001'),
    latitude: body.latitude != null ? Number(body.latitude) : null,
    longitude: body.longitude != null ? Number(body.longitude) : null,
    delivery_instructions: body.delivery_instructions ? String(body.delivery_instructions) : null,
    is_default: setDefault,
  };

  if (body.id) {
    const { data, error } = await admin.from('customer_addresses').update(payload).eq('id', body.id).eq('customer_id', customerId).select('*').single();
    if (error) return NextResponse.json({ success: false, error: error.message }, { status: 400 });
    return NextResponse.json({ success: true, address: data });
  }

  const { data, error } = await admin.from('customer_addresses').insert(payload).select('*').single();
  if (error) return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  return NextResponse.json({ success: true, address: data }, { status: 201 });
}

export async function DELETE(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const id = searchParams.get('id')?.trim();
  const customerId = searchParams.get('customer_id')?.trim();
  if (!id || !customerId) {
    return NextResponse.json({ success: false, error: 'id and customer_id are required.' }, { status: 400 });
  }
  const admin = getAdminClient();
  if (!admin) return NextResponse.json({ success: false, error: 'Database unavailable.' }, { status: 503 });
  await admin.from('customer_addresses').delete().eq('id', id).eq('customer_id', customerId);
  return NextResponse.json({ success: true });
}
