import Link from 'next/link';
import { redirect } from 'next/navigation';
import { CalendarDays, Clock, History, MapPin, ScanLine, Store } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';
import { platformStore } from '@/lib/platform-service';
import CustomerPlanUpgradeModal from '@/components/customer/plan-upgrade-modal';

export const dynamic = 'force-dynamic';

export default async function CustomerDashboardPage() {
  let user: any = null;
  try {
    const session = await createClient();
    const res = await session.auth.getUser();
    user = res.data?.user;
  } catch {}

  if (!user) {
    redirect('/auth/login?next=/customer/dashboard');
  }

  const db = getAdminClient();
  let subscriptions: any[] = [];
  let redemptions: any[] = [];
  let displayName = user.user_metadata?.full_name || user.email?.split('@')[0] || 'there';

  if (db) {
    try {
      const [profileResult, subscriptionResult, redemptionResult] = await Promise.all([
        db.from('profiles').select('display_name').eq('id', user.id).maybeSingle(),
        db.from('subscriptions')
          .select('id,status,plan_id,plan_type_snapshot,plan_name_snapshot,initial_meal_credits,remaining_meal_credits,starts_at,expires_at,created_at,provider_id,providers(id,display_name,slug,locality,city)')
          .eq('customer_id', user.id).order('created_at', { ascending: false }).limit(20),
        db.from('meal_redemptions')
          .select('id,redeemed_at,provider_id,providers(display_name),meal_bookings(service_date,meal_slots(name))')
          .eq('customer_id', user.id).order('redeemed_at', { ascending: false }).limit(15),
      ]);

      if (profileResult.data?.display_name) {
        displayName = profileResult.data.display_name;
      }
      if (subscriptionResult.data && subscriptionResult.data.length > 0) {
        subscriptions = subscriptionResult.data;
      }
      if (redemptionResult.data) {
        redemptions = redemptionResult.data;
      }
    } catch (e) {
      console.error('Error loading Supabase customer dashboard:', e);
    }
  }

  // Fallback to platformStore if DB returned empty or wasn't configured
  if (subscriptions.length === 0) {
    subscriptions = Array.from(platformStore.subscriptions.values())
      .filter((s) => s.customer_id === user.id || (user.phone && s.customer_phone === user.phone))
      .map((s) => {
        const prov = platformStore.providers.get(s.provider_id);
        const plan = platformStore.plans.get(s.plan_id);
        return {
          id: s.id,
          status: s.status,
          plan_id: s.plan_id,
          provider_id: s.provider_id,
          plan_name_snapshot: plan?.name || s.plan_name || 'Meal Plan',
          plan_type_snapshot: plan?.plan_type || s.plan_type || 'fixed_period',
          initial_meal_credits: plan?.meal_credits ?? 30,
          remaining_meal_credits: s.remaining_meal_credits ?? plan?.meal_credits ?? 30,
          starts_at: s.created_at,
          expires_at: s.expires_at,
          created_at: s.created_at,
          providers: {
            id: prov?.id,
            display_name: prov?.display_name || 'Kitchen Partner',
            locality: prov?.locality || 'Campus Area',
            city: prov?.city || 'City',
          },
        };
      });
  }

  const today = Date.now();
  const active = subscriptions.find(
    (item: any) =>
      item.status === 'active' &&
      (!item.starts_at || new Date(item.starts_at).getTime() <= today) &&
      (!item.expires_at || new Date(item.expires_at).getTime() > today)
  );

  const pendingList = subscriptions.filter((item: any) => item.status === 'pending_payment');
  const activeProvider = Array.isArray(active?.providers) ? active.providers[0] : active?.providers;

  return (
    <main className="min-h-screen bg-[#fcf8ef] px-4 py-9 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-6xl">
        <header className="flex flex-col gap-4 border-b border-amber-950/10 pb-6 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.18em] text-amber-800">Your Thali account</p>
            <h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950">Welcome, {displayName}</h1>
            <p className="mt-2 text-sm text-slate-600">Your active meal passes, pending approvals, and verified visits.</p>
          </div>
          <Link
            href="/explore"
            className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-orange-600 px-5 text-sm font-bold text-white hover:bg-orange-700"
          >
            <Store size={17} aria-hidden="true" />
            Explore messes
          </Link>
        </header>

        {/* PENDING APPROVALS NOTICE */}
        {pendingList.length > 0 && (
          <section aria-labelledby="pending-heading" className="mt-7">
            <h2 id="pending-heading" className="text-lg font-extrabold text-amber-950 flex items-center gap-2">
              <Clock size={19} className="text-amber-600" />
              Pending Mess Approvals ({pendingList.length})
            </h2>
            <div className="mt-3 space-y-3">
              {pendingList.map((p) => {
                const prov = Array.isArray(p.providers) ? p.providers[0] : p.providers;
                return (
                  <div
                    key={p.id}
                    className="rounded-2xl border border-amber-200 bg-amber-50/70 p-5 shadow-sm flex flex-wrap items-center justify-between gap-4"
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="rounded-full bg-amber-200 px-2.5 py-0.5 text-xs font-bold text-amber-900 uppercase">
                          Awaiting Partner Confirmation
                        </span>
                        <h3 className="font-extrabold text-slate-900">{p.plan_name_snapshot}</h3>
                      </div>
                      <p className="mt-1 text-xs text-slate-600">
                        {prov?.display_name || 'Mess Partner'} · Submitted {new Date(p.created_at).toLocaleDateString('en-IN')}
                      </p>
                      <p className="mt-1 text-xs text-amber-900">
                        Payment proof submitted. As soon as the mess owner clicks confirm in their hub, your pass unlocks for daily meal redemption.
                      </p>
                    </div>
                  </div>
                );
              })}
            </div>
          </section>
        )}

        {/* CURRENT ACTIVE PASS */}
        <section aria-labelledby="subscription-heading" className="mt-7">
          <h2 id="subscription-heading" className="text-lg font-extrabold text-slate-950">Current meal pass</h2>
          {active ? (
            <article className="mt-3 rounded-2xl border border-amber-200 bg-white p-5 shadow-sm sm:p-7">
              <div className="flex flex-wrap items-start justify-between gap-4">
                <div>
                  <p className="text-xs font-bold uppercase tracking-wide text-emerald-800">Active subscription</p>
                  <h3 className="mt-2 text-2xl font-black text-slate-950">{active.plan_name_snapshot}</h3>
                  <p className="mt-1 flex items-center gap-1.5 text-sm text-slate-600">
                    <MapPin size={15} aria-hidden="true" />
                    {activeProvider?.display_name || 'Mess partner'}
                    {activeProvider?.locality ? ` · ${activeProvider.locality}` : ''}
                    {activeProvider?.city ? `, ${activeProvider.city}` : ''}
                  </p>
                </div>
                <div className="flex items-center gap-3">
                  <span className="rounded-full bg-emerald-50 px-3 py-1 text-xs font-bold text-emerald-800">
                    ACTIVE
                  </span>
                  <CustomerPlanUpgradeModal
                    subscription={active}
                    providerId={active.provider_id || activeProvider?.id}
                  />
                </div>
              </div>
              <div className="mt-5 flex flex-wrap gap-x-8 gap-y-3 text-sm text-slate-700">
                {active.plan_type_snapshot === 'meal_credits' && (
                  <p>
                    <strong>{active.remaining_meal_credits ?? 0}</strong> of {active.initial_meal_credits ?? 0} meals remaining
                  </p>
                )}
                {active.expires_at && (
                  <p className="flex items-center gap-1.5">
                    <CalendarDays size={15} aria-hidden="true" />
                    Valid until {new Date(active.expires_at).toLocaleDateString('en-IN')}
                  </p>
                )}
              </div>
            </article>
          ) : (
            <div className="mt-3 rounded-2xl border border-dashed border-slate-300 bg-white p-7">
              <h3 className="font-bold text-slate-900">No active subscription</h3>
              <p className="mt-1 text-sm text-slate-600">
                Once you purchase a plan and its payment is verified, it will appear here.
              </p>
              <Link
                href="/explore"
                className="mt-4 inline-flex min-h-11 items-center rounded-lg border border-slate-300 px-4 text-sm font-bold text-slate-800 hover:bg-slate-50"
              >
                Browse approved messes
              </Link>
            </div>
          )}
        </section>

        {/* VERIFIED MEAL HISTORY */}
        <section aria-labelledby="history-heading" className="mt-8">
          <h2 id="history-heading" className="flex items-center gap-2 text-lg font-extrabold text-slate-950">
            <History size={19} aria-hidden="true" />
            Verified meal history
          </h2>
          {redemptions.length === 0 ? (
            <div className="mt-3 rounded-2xl border border-slate-200 bg-white p-6 text-sm text-slate-600">
              No verified meal redemptions yet.
            </div>
          ) : (
            <ul className="mt-3 divide-y divide-slate-100 rounded-2xl border border-slate-200 bg-white">
              {redemptions.map((row: any) => (
                <li key={row.id} className="flex flex-wrap items-center justify-between gap-2 p-4">
                  <div>
                    <p className="font-semibold text-slate-900">
                      {row.providers?.display_name || 'Mess partner'} · {row.meal_bookings?.meal_slots?.name || 'Meal'}
                    </p>
                    <p className="mt-1 text-xs text-slate-500">
                      {row.meal_bookings?.service_date || new Date(row.redeemed_at).toLocaleDateString('en-IN')}
                    </p>
                  </div>
                  <time className="text-xs text-slate-500" dateTime={row.redeemed_at}>
                    {new Date(row.redeemed_at).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}
                  </time>
                </li>
              ))}
            </ul>
          )}
        </section>

        <div className="mt-8 grid gap-3 sm:grid-cols-2">
          <Link
            href="/explore"
            className="flex min-h-14 items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 font-semibold text-slate-800 hover:border-amber-300"
          >
            <Store size={18} aria-hidden="true" />
            Find a meal nearby
          </Link>
          <div
            className="flex min-h-14 items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 text-sm text-slate-500"
            aria-disabled="true"
          >
            <ScanLine size={18} aria-hidden="true" />
            Use mobile app for daily counter QR meal scan & attendance
          </div>
        </div>
      </div>
    </main>
  );
}
