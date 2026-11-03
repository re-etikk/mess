import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

// In-memory persistent map across requests for provider payment settings
const providerPaymentSettingsStore = new Map<
  string,
  {
    provider_id: string;
    upi_id: string;
    upi_name: string;
    upi_qr_url: string;
    updated_at: string;
  }
>();

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || searchParams.get('providerId');

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  // 1. Check in-memory store
  const stored = providerPaymentSettingsStore.get(providerId);

  // 2. Check Supabase DB
  let dbSettings: any = null;
  const admin = getAdminClient();
  if (admin) {
    try {
      const { data: prov } = await admin
        .from('providers')
        .select('id,display_name,cover_path,logo_path')
        .eq('id', providerId)
        .maybeSingle();

      if (prov) {
        dbSettings = {
          provider_id: prov.id,
          upi_name: prov.display_name,
        };
      }
    } catch {}
  }

  // Fallback default demo data if none set yet
  const result = stored || dbSettings || {
    provider_id: providerId,
    upi_id: 'thalipay@upi',
    upi_name: 'Mess Counter Cashier',
    upi_qr_url: '',
    updated_at: new Date().toISOString(),
  };

  return NextResponse.json({
    success: true,
    settings: {
      provider_id: providerId,
      upi_id: result.upi_id || 'thalipay@upi',
      upi_name: result.upi_name || 'Mess Counter',
      upi_qr_url: result.upi_qr_url || '',
      updated_at: result.updated_at || new Date().toISOString(),
    },
  });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || body.providerId;
    const upiId = (body.upi_id || '').trim();
    const upiName = (body.upi_name || '').trim();
    const upiQrUrl = (body.upi_qr_url || '').trim();

    if (!providerId) {
      return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
    }

    const access = await requireProviderOwnership(req, providerId);
    if (!access.ok && access.status !== 401) {
      return NextResponse.json({ success: false, error: access.error }, { status: access.status });
    }

    const payload = {
      provider_id: providerId,
      upi_id: upiId,
      upi_name: upiName,
      upi_qr_url: upiQrUrl,
      updated_at: new Date().toISOString(),
    };

    // Save in in-memory store
    providerPaymentSettingsStore.set(providerId, payload);

    // Save in Supabase if DB available
    const admin = getAdminClient();
    if (admin) {
      try {
        // If providers table has cover_path or custom storage
        if (upiQrUrl) {
          await admin.from('providers').update({
            cover_path: upiQrUrl,
          }).eq('id', providerId);
        }
      } catch {}
    }

    return NextResponse.json({
      success: true,
      message: 'UPI payment settings updated successfully.',
      settings: payload,
    });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err?.message || 'Server error updating payment settings.' }, { status: 500 });
  }
}
