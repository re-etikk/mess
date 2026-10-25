import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { requireAdmin } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

const SettingsSchema = z.object({
  free_trial_days: z.number().int().min(0).max(365),
  fee_per_90_successful_redemptions_inr: z.number().int().min(0).max(100000),
  usage_billing_enabled: z.boolean(),
});

const ProviderBillingSchema = z.object({
  provider_id: z.string().uuid(),
  trial_ends_at: z.string().datetime(),
  billing_exempt: z.boolean(),
  exempt_reason: z.string().trim().max(300).nullable(),
  admin_note: z.string().trim().max(500).nullable(),
});

export async function GET() {
  const access = await requireAdmin();
  if (!access.ok) return NextResponse.json({ error: access.error }, { status: access.status });

  const [{ data: settings, error: settingsError }, { data: accounts, error: accountsError }] = await Promise.all([
    access.admin.from('platform_billing_settings').select('free_trial_days,fee_per_90_successful_redemptions_inr,usage_billing_enabled,updated_at').eq('singleton', true).maybeSingle(),
    access.admin.from('provider_billing_accounts').select('provider_id,trial_started_at,trial_ends_at,billing_exempt,exempt_reason,admin_note').order('created_at', { ascending: false }),
  ]);
  if (settingsError || accountsError) {
    return NextResponse.json({ error: 'Billing tables are unavailable. Apply the reviewed Thali billing migration first.' }, { status: 503 });
  }

  const ids = (accounts ?? []).map((account) => account.provider_id);
  const { data: providers, error: providersError } = ids.length
    ? await access.admin.from('providers').select('id,display_name,status').in('id', ids)
    : { data: [], error: null };
  if (providersError) return NextResponse.json({ error: 'Provider records could not be loaded.' }, { status: 503 });

  const providerById = new Map((providers ?? []).map((provider) => [provider.id, provider]));
  const providerAccounts = (accounts ?? []).flatMap((account) => {
    const provider = providerById.get(account.provider_id);
    return provider ? [{ ...account, provider_name: provider.display_name, provider_status: provider.status }] : [];
  });
  return NextResponse.json({ settings, providers: providerAccounts });
}

export async function PATCH(request: NextRequest) {
  const access = await requireAdmin();
  if (!access.ok) return NextResponse.json({ error: access.error }, { status: access.status });

  let payload: unknown;
  try { payload = await request.json(); } catch { return NextResponse.json({ error: 'Invalid JSON body.' }, { status: 400 }); }

  const settings = SettingsSchema.safeParse(payload);
  if (settings.success) {
    const { data, error } = await access.admin
      .from('platform_billing_settings')
      .update({ ...settings.data, updated_by: access.userId })
      .eq('singleton', true)
      .select('free_trial_days,fee_per_90_successful_redemptions_inr,usage_billing_enabled,updated_at')
      .single();
    if (error) return NextResponse.json({ error: 'Unable to save platform billing settings.' }, { status: 503 });
    const { error: auditError } = await access.admin.from('audit_logs').insert({
      actor_user_id: access.userId,
      action: 'platform_billing_settings_updated',
      subject_type: 'platform_billing_settings',
      sanitized_details: settings.data,
    });
    if (auditError) return NextResponse.json({ error: 'Settings were saved, but the audit record failed. Check the audit log before retrying.' }, { status: 500 });
    return NextResponse.json({ settings: data });
  }

  const providerUpdate = ProviderBillingSchema.safeParse(payload);
  if (!providerUpdate.success) return NextResponse.json({ error: 'Invalid billing settings.', details: providerUpdate.error.flatten() }, { status: 400 });
  const values = providerUpdate.data;
  if (values.billing_exempt && (!values.exempt_reason || values.exempt_reason.length < 3)) {
    return NextResponse.json({ error: 'An exemption reason of at least 3 characters is required.' }, { status: 400 });
  }

  const { data: account, error } = await access.admin
    .from('provider_billing_accounts')
    .update({ ...values, updated_by: access.userId })
    .eq('provider_id', values.provider_id)
    .select('provider_id,trial_started_at,trial_ends_at,billing_exempt,exempt_reason,admin_note')
    .maybeSingle();
  if (error) return NextResponse.json({ error: 'Unable to save provider billing settings.' }, { status: 503 });
  if (!account) return NextResponse.json({ error: 'No trial account exists for this provider yet.' }, { status: 404 });

  const { error: auditError } = await access.admin.from('audit_logs').insert({
    actor_user_id: access.userId,
    action: 'provider_billing_account_updated',
    subject_type: 'provider',
    subject_id: values.provider_id,
    reason: values.exempt_reason,
    sanitized_details: { trial_ends_at: values.trial_ends_at, billing_exempt: values.billing_exempt },
  });
  if (auditError) return NextResponse.json({ error: 'Provider settings were saved, but the audit record failed. Check the audit log before retrying.' }, { status: 500 });
  return NextResponse.json({ provider: account });
}
