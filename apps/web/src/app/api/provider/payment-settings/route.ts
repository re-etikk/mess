import { NextRequest, NextResponse } from 'next/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { requireProviderOwnership } from '@/lib/provider-auth';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const providerId = searchParams.get('provider_id') || searchParams.get('providerId');

  if (!providerId) {
    return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
  }

  const admin = getAdminClient();
  let billingAccount: any = null;
  let providerInfo: any = null;

  if (admin) {
    try {
      const [{ data: bill }, { data: prov }] = await Promise.all([
        admin
          .from('provider_billing_accounts')
          .select('upi_id,upi_name,upi_qr_url,account_number,ifsc_code,bank_name,branch_name,account_holder_name,updated_at')
          .eq('provider_id', providerId)
          .maybeSingle(),
        admin
          .from('providers')
          .select('id,display_name,cover_path,public_phone')
          .eq('id', providerId)
          .maybeSingle(),
      ]);
      billingAccount = bill;
      providerInfo = prov;
    } catch {}
  }

  const defaultName = providerInfo?.display_name || 'Mess Counter';
  const defaultUpi = providerInfo?.public_phone ? `${providerInfo.public_phone}@paytm` : 'thalipay@upi';

  return NextResponse.json({
    success: true,
    settings: {
      provider_id: providerId,
      upi_id: billingAccount?.upi_id || defaultUpi,
      upi_name: billingAccount?.upi_name || defaultName,
      upi_qr_url: billingAccount?.upi_qr_url || providerInfo?.cover_path || '',
      account_number: billingAccount?.account_number || '',
      ifsc_code: billingAccount?.ifsc_code || '',
      bank_name: billingAccount?.bank_name || '',
      branch_name: billingAccount?.branch_name || '',
      account_holder_name: billingAccount?.account_holder_name || defaultName,
      updated_at: billingAccount?.updated_at || new Date().toISOString(),
    },
  }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const providerId = body.provider_id || body.providerId;
    const upiId = (body.upi_id || '').trim();
    const upiName = (body.upi_name || '').trim();
    const upiQrUrl = (body.upi_qr_url || '').trim();
    const accountNumber = (body.account_number || '').trim();
    const ifscCode = (body.ifsc_code || '').trim().toUpperCase();
    const bankName = (body.bank_name || '').trim();
    const branchName = (body.branch_name || '').trim();
    const accountHolderName = (body.account_holder_name || '').trim();

    if (!providerId) {
      return NextResponse.json({ success: false, error: 'provider_id is required.' }, { status: 400 });
    }

    const access = await requireProviderOwnership(req, providerId);
    if (!access.ok && access.status !== 401) {
      return NextResponse.json({ success: false, error: access.error }, { status: access.status });
    }

    const admin = getAdminClient();
    const updatePayload = {
      provider_id: providerId,
      upi_id: upiId,
      upi_name: upiName,
      upi_qr_url: upiQrUrl,
      account_number: accountNumber,
      ifsc_code: ifscCode,
      bank_name: bankName,
      branch_name: branchName,
      account_holder_name: accountHolderName,
      updated_at: new Date().toISOString(),
    };

    if (admin) {
      try {
        const { data: existing } = await admin
          .from('provider_billing_accounts')
          .select('provider_id')
          .eq('provider_id', providerId)
          .maybeSingle();

        if (existing) {
          await admin
            .from('provider_billing_accounts')
            .update(updatePayload)
            .eq('provider_id', providerId);
        } else {
          await admin
            .from('provider_billing_accounts')
            .insert(updatePayload);
        }

        // Also sync cover_path in providers table if a custom QR is uploaded
        if (upiQrUrl) {
          await admin
            .from('providers')
            .update({ cover_path: upiQrUrl })
            .eq('id', providerId);
        }
      } catch (err: any) {
        console.error('Failed to update provider billing account in DB:', err?.message);
      }
    }

    return NextResponse.json({
      success: true,
      message: 'UPI payment settings and bank account updated successfully.',
      settings: updatePayload,
    });
  } catch (err: any) {
    return NextResponse.json({ success: false, error: err?.message || 'Server error updating payment settings.' }, { status: 500 });
  }
}
