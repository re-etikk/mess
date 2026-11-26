import { NextRequest, NextResponse } from 'next/server';
import crypto from 'crypto';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { requireProviderOwnership } from '@/lib/provider-auth';
import { getIndiaDateString } from '@/lib/crypto';

export const dynamic = 'force-dynamic';

function buildShareLink(name: string, phone10: string, pin: string, providerName: string) {
  const base = (process.env.NEXT_PUBLIC_SITE_URL || 'https://www.thali.store').replace(/\/$/, '');
  const riderUrl = `${base}/rider/portal?phone=${phone10}`;
  const msg = `Namaste ${name}! Aapka ${providerName} tiffin delivery staff access ready hai.\n\nLink kholein: ${riderUrl}\nMobile: ${phone10}\n4-Digit PIN: ${pin}\n\nRoz delivery shuru karne se pehle Start Delivery aur deliver hone par Mark Delivered dabayein.`;
  return {
    rider_url: riderUrl,
    whatsapp_url: `https://wa.me/91${phone10}?text=${encodeURIComponent(msg)}`,
  };
}

export async function GET(req: NextRequest) {
  const providerId = new URL(req.url).searchParams.get('provider_id')?.trim() || '';
  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok && access.status !== 401) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  let riders: any[] = [];
  let providerName = 'Mess Kitchen';

  if (admin) {
    try {
      const [provRes, ridersRes] = await Promise.all([
        admin.from('providers').select('display_name').eq('id', providerId).maybeSingle(),
        admin
          .from('provider_riders')
          .select('*')
          .eq('provider_id', providerId)
          .eq('is_active', true)
          .order('created_at', { ascending: false })
          .then((r) => r, () => ({ data: [] as any[] })),
      ]);
      if (provRes?.data?.display_name) providerName = provRes.data.display_name;
      riders = (ridersRes as any)?.data ?? [];
    } catch {}
  }

  if (riders.length === 0) {
    for (const r of platformStore.providerRiders.values()) {
      if (r.provider_id === providerId && r.is_active !== false) {
        riders.push(r);
      }
    }
  }

  const enriched = riders.map((r) => {
    const p10 = String(r.phone || '').replace(/\D/g, '').slice(-10);
    const links = buildShareLink(r.name || 'Rider', p10, r.pin_code || '0000', providerName);
    return {
      ...r,
      ...links,
    };
  });

  return NextResponse.json(
    { success: true, riders: enriched },
    { headers: { 'Cache-Control': 'private, no-store' } }
  );
}

export async function POST(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = String(body.provider_id || '').trim();
  const name = String(body.name || '').trim();
  const phone10 = String(body.phone || '').replace(/\D/g, '').slice(-10);
  const requestedPin = String(body.pin_code || '').replace(/\D/g, '').slice(0, 4);
  const pinCode = requestedPin.length === 4 ? requestedPin : String(Math.floor(1000 + Math.random() * 9000));

  if (!providerId || !name || phone10.length !== 10) {
    return NextResponse.json(
      { success: false, error: 'Kitchen ID, staff name, and valid 10-digit mobile number are required.' },
      { status: 400 }
    );
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok && access.status !== 401) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  let providerName = 'Mess Kitchen';
  let riderRow: any = null;

  if (admin) {
    try {
      const { data: prov } = await admin.from('providers').select('display_name').eq('id', providerId).maybeSingle();
      if (prov?.display_name) providerName = prov.display_name;

      const { data, error } = await admin
        .from('provider_riders')
        .upsert(
          {
            provider_id: providerId,
            name,
            phone: phone10,
            pin_code: pinCode,
            is_active: true,
            updated_at: new Date().toISOString(),
          },
          { onConflict: 'provider_id,phone' }
        )
        .select('*')
        .single();
      if (!error && data) riderRow = data;
    } catch {}
  }

  if (!riderRow) {
    riderRow = {
      id: `rider-${crypto.randomBytes(4).toString('hex')}`,
      provider_id: providerId,
      name,
      phone: phone10,
      pin_code: pinCode,
      is_active: true,
      created_at: new Date().toISOString(),
    };
  }

  platformStore.providerRiders.set(riderRow.id, riderRow);
  const links = buildShareLink(name, phone10, pinCode, providerName);

  return NextResponse.json({
    success: true,
    rider: { ...riderRow, ...links },
  });
}

export async function PATCH(req: NextRequest) {
  const body = await req.json().catch(() => ({}));
  const providerId = String(body.provider_id || '').trim();
  const riderId = String(body.rider_id || '').trim();
  const subscriptionId = String(body.subscription_id || '').trim();
  const customerId = String(body.customer_id || '').trim();
  const slot = String(body.slot || 'LUNCH').toUpperCase().trim();
  const serviceDate = String(body.service_date || getIndiaDateString()).trim();

  if (!providerId || !riderId || !subscriptionId || !customerId) {
    return NextResponse.json(
      { success: false, error: 'provider_id, rider_id, subscription_id, and customer_id are required.' },
      { status: 400 }
    );
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok && access.status !== 401) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  let riderName = String(body.rider_name || 'Delivery Staff').trim();
  let riderPhone = String(body.rider_phone || '').trim();

  if (admin) {
    const { data: r } = await admin.from('provider_riders').select('name,phone').eq('id', riderId).maybeSingle();
    if (r) {
      riderName = r.name;
      riderPhone = r.phone;
    }

    await admin.from('daily_meal_events').upsert(
      {
        subscription_id: subscriptionId,
        customer_id: customerId,
        provider_id: providerId,
        service_date: serviceDate,
        slot,
        fulfillment_mode: 'delivery',
        rider_id: riderId,
        rider_name: riderName,
        rider_phone: riderPhone,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'subscription_id,service_date,slot' }
    );
  }

  const memKey = `${subscriptionId}_${serviceDate}_${slot}`;
  const prev = platformStore.dailyMealEvents.get(memKey) || {};
  platformStore.dailyMealEvents.set(memKey, {
    ...prev,
    id: memKey,
    subscription_id: subscriptionId,
    customer_id: customerId,
    provider_id: providerId,
    service_date: serviceDate,
    slot,
    fulfillment_mode: 'delivery',
    rider_id: riderId,
    rider_name: riderName,
    rider_phone: riderPhone,
    updated_at: new Date().toISOString(),
  });

  return NextResponse.json({ success: true, rider_name: riderName, rider_phone: riderPhone });
}

export async function DELETE(req: NextRequest) {
  const params = new URL(req.url).searchParams;
  const providerId = params.get('provider_id')?.trim() || '';
  const riderId = params.get('rider_id')?.trim() || '';

  if (!providerId || !riderId) {
    return NextResponse.json({ success: false, error: 'provider_id and rider_id are required.' }, { status: 400 });
  }

  const access = await requireProviderOwnership(req, providerId);
  if (!access.ok && access.status !== 401) {
    return NextResponse.json({ success: false, error: access.error }, { status: access.status });
  }

  const admin = getAdminClient();
  if (admin) {
    await admin.from('provider_riders').update({ is_active: false }).eq('id', riderId).eq('provider_id', providerId);
  }
  const existing = platformStore.providerRiders.get(riderId);
  if (existing && existing.provider_id === providerId) {
    platformStore.providerRiders.set(riderId, { ...existing, is_active: false });
  }

  return NextResponse.json({ success: true });
}
