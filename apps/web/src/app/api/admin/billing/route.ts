import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

const SettingsSchema = z.object({
  free_trial_days: z.number().int().min(0).max(365),
  fee_per_90_successful_redemptions_inr: z.number().int().min(0).max(100000),
  usage_billing_enabled: z.boolean(),
});
const ProviderSettingsSchema = z.object({
  provider_id: z.string().uuid(),
  trial_ends_at: z.string().datetime({ offset: true }).nullable(),
  billing_exempt: z.boolean(),
  exempt_reason: z.string().trim().max(500).nullable(),
  admin_note: z.string().trim().max(1000).nullable(),
}).refine((value) => !value.billing_exempt || Boolean(value.exempt_reason && value.exempt_reason.length >= 3), {
  message: 'An exemption reason of at least 3 characters is required.', path: ['exempt_reason'],
});

export async function GET(req: NextRequest) {
  const access = await requireAdmin(req);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  const [{ data: settings, error: settingsError }, { data: accounts, error: accountsError }] = await Promise.all([
    access.admin.from('platform_billing_settings')
      .select('free_trial_days,fee_per_90_successful_redemptions_inr,usage_billing_enabled,updated_at')
      .eq('singleton', true).maybeSingle(),
    access.admin.from('provider_billing_accounts')
      .select('provider_id,trial_started_at,trial_ends_at,billing_exempt,exempt_reason,admin_note,providers!inner(display_name,status)')
      .order('created_at', { ascending: false }),
  ]);
  if (settingsError || accountsError) {
    console.error('Billing settings query failed:', settingsError?.message || accountsError?.message);
    return NextResponse.json({ success: false, error: 'Billing data could not be loaded.' }, { status: 503 });
  }
  if (!settings) return NextResponse.json({ success: false, error: 'Platform billing settings are not initialized. Apply the billing migration first.' }, { status: 503 });

  return NextResponse.json({
    settings,
    providers: (accounts ?? []).map((account: any) => ({
      provider_id: account.provider_id,
      provider_name: account.providers.display_name,
      provider_status: account.providers.status,
      trial_started_at: account.trial_started_at,
      trial_ends_at: account.trial_ends_at,
      billing_exempt: account.billing_exempt,
      exempt_reason: account.exempt_reason,
      admin_note: account.admin_note,
    })),
  }, { headers: { 'Cache-Control': 'private, no-store' } });
}

export async function PATCH(req: NextRequest) {
  const access = await requireAdmin(req);
  if (!access.ok) return NextResponse.json({ success: false, error: access.error }, { status: access.status });

  let payload: unknown;
  try { payload = await req.json(); } catch {
    return NextResponse.json({ success: false, error: 'Invalid JSON body.' }, { status: 400 });
  }
  const settings = SettingsSchema.safeParse(payload);
  if (settings.success) {
    if (settings.data.usage_billing_enabled && (!process.env.RAZORPAY_KEY_ID || !process.env.RAZORPAY_KEY_SECRET || !process.env.RAZORPAY_WEBHOOK_SECRET)) {
      return NextResponse.json({ success: false, error: 'Usage billing cannot be enabled until Razorpay credentials and webhook verification are configured.' }, { status: 409 });
    }
    const { data, error } = await access.admin.from('platform_billing_settings')
      .update({ ...settings.data, updated_by: access.userId })
      .eq('singleton', true)
      .select('free_trial_days,fee_per_90_successful_redemptions_inr,usage_billing_enabled,updated_at')
      .maybeSingle();
    if (error || !data) {
      console.error('Billing settings update failed:', error?.message || 'singleton missing');
      return NextResponse.json({ success: false, error: 'Billing settings could not be saved.' }, { status: 503 });
    }
    return NextResponse.json({ success: true, settings: data });
  }

  const providerSettings = ProviderSettingsSchema.safeParse(payload);
  if (!providerSettings.success) return NextResponse.json({ success: false, error: 'Invalid billing settings.', details: providerSettings.error.flatten() }, { status: 400 });
  const { provider_id, ...updates } = providerSettings.data;
  const { data, error } = await access.admin.from('provider_billing_accounts')
    .update({ ...updates, updated_by: access.userId })
    .eq('provider_id', provider_id)
    .select('provider_id,trial_started_at,trial_ends_at,billing_exempt,exempt_reason,admin_note')
    .maybeSingle();
  if (error || !data) {
    console.error('Provider billing update failed:', error?.message || 'provider billing account missing');
    return NextResponse.json({ success: false, error: 'Provider billing settings could not be saved. Confirm the provider has an activated trial account.' }, { status: 503 });
  }
  return NextResponse.json({ success: true, provider: data });
}
