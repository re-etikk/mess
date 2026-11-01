import Link from 'next/link';
import { redirect } from 'next/navigation';
import { CalendarDays, History, MapPin, ScanLine, Store } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';
import { getAdminClient } from '@/lib/supabase/admin';

export const dynamic = 'force-dynamic';

export default async function CustomerDashboardPage() {
  let session;
  try { session = await createClient(); } catch {
    return <Unavailable message="Customer accounts are unavailable until Supabase is configured." />;
  }
  const { data: { user } } = await session.auth.getUser();
  if (!user) redirect('/auth/login?next=/customer/dashboard');

  const db = getAdminClient();
  if (!db) return <Unavailable message="Customer records are temporarily unavailable. Please try again later." />;

  const [profileResult, subscriptionResult, redemptionResult] = await Promise.all([
    db.from('profiles').select('display_name').eq('id', user.id).maybeSingle(),
    db.from('subscriptions')
      .select('id,status,plan_type_snapshot,plan_name_snapshot,initial_meal_credits,remaining_meal_credits,starts_at,expires_at,created_at,providers(display_name,slug,locality,city)')
      .eq('customer_id', user.id).order('created_at', { ascending: false }).limit(20),
    db.from('meal_redemptions')
      .select('id,redeemed_at,providers(display_name),meal_bookings(service_date,meal_slots(name))')
      .eq('customer_id', user.id).order('redeemed_at', { ascending: false }).limit(15),
  ]);
  const failed = [profileResult, subscriptionResult, redemptionResult].find((result) => result.error);
  if (failed?.error) {
    console.error('Customer dashboard query failed:', failed.error.message);
    return <Unavailable message="Your account data could not be loaded. Please retry in a moment." />;
  }

  const today = Date.now();
  const subscriptions = subscriptionResult.data ?? [];
  const active = subscriptions.find((item: any) => item.status === 'active'
    && (!item.starts_at || new Date(item.starts_at).getTime() <= today)
    && (!item.expires_at || new Date(item.expires_at).getTime() > today));
  const activeProvider = Array.isArray(active?.providers) ? active.providers[0] : active?.providers;
  const name = profileResult.data?.display_name || user.email?.split('@')[0] || 'there';

  return <main className="min-h-screen bg-[#fcf8ef] px-4 py-9 sm:px-6 lg:px-8">
    <div className="mx-auto max-w-6xl">
      <header className="flex flex-col gap-4 border-b border-amber-950/10 pb-6 sm:flex-row sm:items-end sm:justify-between">
        <div><p className="text-xs font-bold uppercase tracking-[0.18em] text-amber-800">Your Thali account</p><h1 className="mt-2 text-3xl font-black tracking-tight text-slate-950">Welcome, {name}</h1><p className="mt-2 text-sm text-slate-600">Your subscriptions and verified meal visits.</p></div>
        <Link href="/explore" className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-orange-600 px-5 text-sm font-bold text-white hover:bg-orange-700"><Store size={17} aria-hidden="true"/>Explore messes</Link>
      </header>

      <section aria-labelledby="subscription-heading" className="mt-7">
        <h2 id="subscription-heading" className="text-lg font-extrabold text-slate-950">Current meal pass</h2>
        {active ? <article className="mt-3 rounded-2xl border border-amber-200 bg-white p-5 shadow-sm sm:p-7">
          <div className="flex flex-wrap items-start justify-between gap-4"><div><p className="text-xs font-bold uppercase tracking-wide text-emerald-800">Active subscription</p><h3 className="mt-2 text-2xl font-black text-slate-950">{active.plan_name_snapshot}</h3><p className="mt-1 flex items-center gap-1.5 text-sm text-slate-600"><MapPin size={15} aria-hidden="true"/>{activeProvider?.display_name || 'Mess partner'}{activeProvider?.locality ? ` · ${activeProvider.locality}` : ''}{activeProvider?.city ? `, ${activeProvider.city}` : ''}</p></div><span className="rounded-full bg-emerald-50 px-3 py-1 text-xs font-bold text-emerald-800">ACTIVE</span></div>
          <div className="mt-5 flex flex-wrap gap-x-8 gap-y-3 text-sm text-slate-700">{active.plan_type_snapshot === 'meal_credits' && <p><strong>{active.remaining_meal_credits ?? 0}</strong> of {active.initial_meal_credits ?? 0} meals remaining</p>}{active.expires_at && <p className="flex items-center gap-1.5"><CalendarDays size={15} aria-hidden="true"/>Valid until {new Date(active.expires_at).toLocaleDateString('en-IN')}</p>}</div>
          <p className="mt-5 rounded-xl bg-amber-50 p-3 text-sm text-amber-950">Meal redemption is temporarily unavailable while secure QR validation is connected to the production database. No meal credits can be deducted from this page.</p>
        </article> : <div className="mt-3 rounded-2xl border border-dashed border-slate-300 bg-white p-7"><h3 className="font-bold text-slate-900">No active subscription</h3><p className="mt-1 text-sm text-slate-600">Once you purchase a plan and its payment is verified, it will appear here.</p><Link href="/explore" className="mt-4 inline-flex min-h-11 items-center rounded-lg border border-slate-300 px-4 text-sm font-bold text-slate-800 hover:bg-slate-50">Browse approved messes</Link></div>}
      </section>

      <section aria-labelledby="history-heading" className="mt-8">
        <h2 id="history-heading" className="flex items-center gap-2 text-lg font-extrabold text-slate-950"><History size={19} aria-hidden="true"/>Verified meal history</h2>
        {(redemptionResult.data ?? []).length === 0 ? <div className="mt-3 rounded-2xl border border-slate-200 bg-white p-6 text-sm text-slate-600">No verified meal redemptions yet.</div> : <ul className="mt-3 divide-y divide-slate-100 rounded-2xl border border-slate-200 bg-white">{(redemptionResult.data ?? []).map((row: any) => <li key={row.id} className="flex flex-wrap items-center justify-between gap-2 p-4"><div><p className="font-semibold text-slate-900">{row.providers?.display_name || 'Mess partner'} · {row.meal_bookings?.meal_slots?.name || 'Meal'}</p><p className="mt-1 text-xs text-slate-500">{row.meal_bookings?.service_date || new Date(row.redeemed_at).toLocaleDateString('en-IN')}</p></div><time className="text-xs text-slate-500" dateTime={row.redeemed_at}>{new Date(row.redeemed_at).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}</time></li>)}</ul>}
      </section>

      <div className="mt-8 grid gap-3 sm:grid-cols-2"><Link href="/explore" className="flex min-h-14 items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 font-semibold text-slate-800 hover:border-amber-300"><Store size={18} aria-hidden="true"/>Find a meal nearby</Link><div className="flex min-h-14 items-center gap-3 rounded-xl border border-slate-200 bg-white px-4 text-sm text-slate-500" aria-disabled="true"><ScanLine size={18} aria-hidden="true"/>QR scanning will be enabled after redemption APIs are verified</div></div>
    </div>
  </main>;
}

function Unavailable({ message }: { message: string }) {
  return <main className="mx-auto max-w-3xl px-4 py-16"><h1 className="text-2xl font-black text-slate-950">Dashboard unavailable</h1><p role="alert" className="mt-3 text-slate-600">{message}</p><Link href="/auth/login" className="mt-5 inline-flex min-h-11 items-center rounded-lg bg-slate-950 px-4 font-semibold text-white">Sign in again</Link></main>;
}
