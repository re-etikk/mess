import { NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export async function GET() {
  const providers = Array.from(platformStore.providers.values());
  const subscriptions = Array.from(platformStore.subscriptions.values());
  const redemptions = Array.from(platformStore.redemptions.values());
  const invoices = Array.from(platformStore.invoices.values());

  let totalScanCount = 0;
  let unbilledScanCount = 0;
  for (const scan of platformStore.providerScanCounts.values()) {
    totalScanCount += scan.total;
    unbilledScanCount += scan.unbilled;
  }

  let totalRevenuePaise = 0;
  for (const sub of subscriptions) {
    totalRevenuePaise += sub.price_paid_paise;
  }

  let totalBilledUsagePaise = 0;
  for (const inv of invoices) {
    if (inv.status === 'paid') {
      totalBilledUsagePaise += inv.total_due_paise;
    }
  }

  let supabaseCheck: Record<string, any> = { attempted: false };
  try {
    const admin = getAdminClient();
    if (admin) {
      supabaseCheck.attempted = true;
      const { data: provs, error: provErr } = await admin.from('providers').select('id,display_name,status').limit(10);
      supabaseCheck.providers_error = provErr ? provErr.message : null;
      supabaseCheck.providers_count = provs ? provs.length : 0;
      supabaseCheck.providers_sample = provs;

      const { data: profs, error: profErr } = await admin.from('profiles').select('id,display_name').limit(5);
      supabaseCheck.profiles_error = profErr ? profErr.message : null;
      supabaseCheck.profiles_count = profs ? profs.length : 0;
    }
  } catch (err: any) {
    supabaseCheck.exception = err?.message || String(err);
  }

  return NextResponse.json({
    success: true,
    platform: 'Thali (MESS)',
    backend_status: {
      backend_enabled: process.env.NEXT_PUBLIC_BACKEND_ENABLED || 'not_set',
      has_supabase_url: !!process.env.NEXT_PUBLIC_SUPABASE_URL,
      has_service_key: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
    },
    supabase_check: supabaseCheck,
    providers: {
      total: providers.length,
      active: providers.filter((p) => p.status === 'active').length,
      pending: providers.filter((p) => p.status === 'pending_review').length,
    },
    subscriptions: {
      total: subscriptions.length,
      active: subscriptions.filter((s) => s.status === 'active').length,
      fixed_period: subscriptions.filter((s) => s.plan_type === 'fixed_period' && s.status === 'active').length,
      meal_credits: subscriptions.filter((s) => s.plan_type === 'meal_credits' && s.status === 'active').length,
    },
    redemptions: {
      total: redemptions.length,
      today: redemptions.filter((r) => r.date === new Date().toISOString().split('T')[0]).length,
    },
    usage_billing: {
      total_scans_recorded: totalScanCount,
      unbilled_scans_pending: unbilledScanCount,
      fee_rate: '₹25 per 90 scans',
      total_invoices_paid_inr: totalBilledUsagePaise / 100,
    },
    financials: {
      total_gmv_inr: totalRevenuePaise / 100,
      currency: 'INR',
    },
  });
}
