import { NextResponse } from 'next/server';
import { platformStore } from '@/lib/platform-service';

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

  return NextResponse.json({
    success: true,
    platform: 'Thali (MESS)',
    backend_status: {
      backend_enabled: process.env.NEXT_PUBLIC_BACKEND_ENABLED || 'not_set',
      has_supabase_url: !!process.env.NEXT_PUBLIC_SUPABASE_URL,
      has_service_key: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
    },
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
