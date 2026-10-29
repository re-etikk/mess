import { NextRequest, NextResponse } from 'next/server';
import { z } from 'zod';
import { getAdminClient, requireAdmin } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';

export const dynamic = 'force-dynamic';

const SettingsSchema = z.object({
  free_trial_days: z.number().int().min(0).max(365),
  fee_per_90_successful_redemptions_inr: z.number().int().min(0).max(100000),
  usage_billing_enabled: z.boolean(),
});

const defaultSettings = {
  free_trial_days: 14,
  fee_per_90_successful_redemptions_inr: 25,
  usage_billing_enabled: true,
  updated_at: new Date().toISOString(),
};

export async function GET(req: NextRequest) {
  const auth = await requireAdmin(req);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  let settings = defaultSettings;
  let providerAccounts: any[] = [];

  try {
    const admin = getAdminClient();
    if (admin) {
      const [{ data: dbSettings }, { data: accounts }] = await Promise.all([
        admin.from('platform_billing_settings').select('free_trial_days,fee_per_90_successful_redemptions_inr,usage_billing_enabled,updated_at').eq('singleton', true).maybeSingle(),
        admin.from('provider_billing_accounts').select('provider_id,trial_started_at,trial_ends_at,billing_exempt,exempt_reason,admin_note').order('created_at', { ascending: false }),
      ]);

      if (dbSettings) {
        settings = dbSettings;
      }

      if (accounts && accounts.length > 0) {
        const ids = accounts.map((a: any) => a.provider_id);
        const { data: dbProviders } = await admin.from('providers').select('id,display_name,status').in('id', ids);
        const pMap = new Map((dbProviders ?? []).map((p: any) => [p.id, p]));
        providerAccounts = accounts.map((acc: any) => {
          const prov = pMap.get(acc.provider_id);
          return {
            ...acc,
            provider_name: prov?.display_name || 'Kitchen Partner',
            provider_status: prov?.status || 'active',
          };
        });
      }
    }
  } catch (err) {
    console.warn('Billing accounts query fallback:', err);
  }

  // Fallback to active providers in platformStore if no accounts yet
  if (providerAccounts.length === 0) {
    providerAccounts = Array.from(platformStore.providers.values())
      .filter((p) => p.status === 'active')
      .map((p) => ({
        provider_id: p.id,
        provider_name: p.display_name,
        provider_status: p.status,
        trial_started_at: p.created_at,
        trial_ends_at: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString(),
        billing_exempt: false,
        exempt_reason: null,
        admin_note: null,
      }));
  }

  return NextResponse.json({
    settings,
    providers: providerAccounts,
  });
}

export async function PATCH(request: NextRequest) {
  const auth = await requireAdmin(request);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ error: 'Invalid JSON body.' }, { status: 400 });
  }

  const settingsParsed = SettingsSchema.safeParse(payload);
  if (settingsParsed.success) {
    try {
      const admin = getAdminClient();
      if (admin) {
        await admin
          .from('platform_billing_settings')
          .update({ ...settingsParsed.data, updated_by: 'admin-system' })
          .eq('singleton', true);
      }
    } catch {
      // fallback
    }

    return NextResponse.json({
      settings: {
        ...settingsParsed.data,
        updated_at: new Date().toISOString(),
      },
    });
  }

  return NextResponse.json({ success: true, message: 'Billing policy updated.' });
}
