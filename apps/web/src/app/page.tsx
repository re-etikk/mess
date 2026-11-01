import type { Metadata } from 'next';
import Link from 'next/link';
import {
  ArrowRight,
  BarChart3,
  CalendarClock,
  Check,
  CircleHelp,
  ClipboardList,
  QrCode,
  ShieldCheck,
  Store,
  Utensils,
  WalletCards,
} from 'lucide-react';
import { APP_CONFIG } from '@/lib/config';

export const metadata: Metadata = {
  title: 'Tools for Mess Owners',
  description: 'Manage your mess profile, menu, meal plans, subscribers and daily operations with Thali Partner.',
  alternates: { canonical: 'https://www.thali.store' },
  openGraph: {
    title: 'Thali Partner — tools for mess owners',
    description: 'One workspace for your mess profile, menu, meal plans and daily operations.',
    url: 'https://www.thali.store',
  },
};

const tools = [
  { icon: Store, title: 'Your business profile', detail: 'Submit your mess details and track the review status.' },
  { icon: Utensils, title: 'Menu and meal plans', detail: 'Manage the dishes, meal slots and plans your business actually offers.' },
  { icon: QrCode, title: 'Daily counter QR', detail: 'Display a short-lived code for on-premise meal check-ins.' },
  { icon: ClipboardList, title: 'Subscribers and activity', detail: 'Review persisted subscriber and redemption records when available.' },
  { icon: BarChart3, title: 'Reports and operations', detail: 'See business activity from connected records, with clear empty states.' },
  { icon: WalletCards, title: 'Trial and billing', detail: 'Platform trial and billing settings are managed by the Thali admin.' },
];

const steps = [
  'Create or sign in to your Thali account.',
  'Submit your mess details for review.',
  'After approval, configure your real menu and plans.',
  'Use the partner portal to manage day-to-day operations.',
];

export default function HomePage() {
  return (
    <main className="overflow-hidden bg-[#fbfaf7] text-slate-950">
      <section className="relative isolate border-b border-orange-100 bg-white">
        <div aria-hidden="true" className="absolute inset-0 -z-10 bg-[radial-gradient(ellipse_at_80%_15%,rgba(251,146,60,0.13),transparent_38%),radial-gradient(ellipse_at_10%_90%,rgba(22,101,52,0.08),transparent_36%)]" />
        <div className="mx-auto grid max-w-7xl items-center gap-12 px-5 py-16 sm:px-8 sm:py-24 lg:grid-cols-[1.1fr_0.9fr] lg:px-10 lg:py-28">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full border border-orange-200 bg-orange-50 px-3.5 py-1.5 text-xs font-bold text-orange-900">
              <Store size={14} /> THALI PARTNER WORKSPACE
            </div>
            <h1 className="mt-6 max-w-3xl text-4xl font-black leading-[1.08] tracking-tight sm:text-6xl">
              Run your mess.<br />Keep the day in order.
            </h1>
            <p className="mt-6 max-w-xl text-base leading-7 text-slate-600 sm:text-lg sm:leading-8">
              Set up your business profile, keep your menu and plans current, and manage daily partner operations from one workspace.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Link href="/provider/portal" className="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-orange-700 px-5 text-sm font-bold text-white shadow-lg shadow-orange-900/10 transition hover:bg-orange-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-orange-700">
                Open partner workspace <ArrowRight size={17} />
              </Link>
              <Link href="/partner/login" className="inline-flex min-h-12 items-center justify-center rounded-xl border border-slate-300 bg-white px-5 text-sm font-bold text-slate-800 transition hover:border-slate-400 hover:bg-slate-50">
                Partner sign in
              </Link>
            </div>
            <p className="mt-4 flex items-start gap-2 text-xs leading-5 text-slate-500">
              <ShieldCheck size={15} className="mt-0.5 shrink-0 text-emerald-700" />
              Access to partner tools depends on your signed-in account and business approval.
            </p>
          </div>

          <div className="relative mx-auto w-full max-w-lg">
            <div className="absolute -inset-4 rounded-[2rem] bg-gradient-to-br from-orange-200/70 via-amber-100/40 to-emerald-100/60 blur-2xl" />
            <div className="relative rounded-[1.65rem] border border-slate-200 bg-white p-5 shadow-2xl shadow-slate-900/10 sm:p-7">
              <div className="flex items-center justify-between border-b border-slate-100 pb-5">
                <div className="flex items-center gap-3">
                  <div className="flex h-11 w-11 items-center justify-center rounded-2xl bg-orange-100 text-orange-800"><Store size={21} /></div>
                  <div><p className="text-sm font-extrabold">Partner workspace</p><p className="mt-0.5 text-xs text-slate-500">Tools for your daily operations</p></div>
                </div>
                <span className="rounded-full border border-slate-200 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wide text-slate-500">Partner tools</span>
              </div>
              <div className="mt-5 grid grid-cols-2 gap-3">
                {[
                  { icon: Utensils, label: 'Menu', hint: 'Your dishes and slots', color: 'bg-amber-50 text-amber-800' },
                  { icon: CalendarClock, label: 'Plans', hint: 'Your published offers', color: 'bg-emerald-50 text-emerald-800' },
                  { icon: QrCode, label: 'Counter QR', hint: 'Available when redemption is enabled', color: 'bg-sky-50 text-sky-800' },
                  { icon: BarChart3, label: 'Activity', hint: 'From saved records', color: 'bg-violet-50 text-violet-800' },
                ].map(({ icon: Icon, label, hint, color }) => (
                  <div key={label} className="rounded-2xl border border-slate-100 bg-slate-50/70 p-4">
                    <div className={`mb-5 flex h-9 w-9 items-center justify-center rounded-xl ${color}`}><Icon size={18} /></div>
                    <p className="text-sm font-extrabold">{label}</p><p className="mt-1 text-[11px] leading-4 text-slate-500">{hint}</p>
                  </div>
                ))}
              </div>
              <div className="mt-4 flex items-center gap-3 rounded-2xl border border-emerald-100 bg-emerald-50/70 p-4">
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-white text-emerald-700"><Check size={18} /></div>
                <div><p className="text-xs font-bold text-emerald-950">Your records stay yours</p><p className="mt-1 text-[11px] leading-4 text-emerald-900/70">No sample business or subscriber data is shown as live activity.</p></div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="tools" className="mx-auto max-w-7xl scroll-mt-24 px-5 py-16 sm:px-8 sm:py-20 lg:px-10">
        <div className="max-w-2xl">
          <p className="text-xs font-extrabold uppercase tracking-[0.18em] text-orange-800">Built around your work</p>
          <h2 className="mt-3 text-3xl font-black tracking-tight sm:text-4xl">The tools a mess owner needs to get started.</h2>
          <p className="mt-4 text-sm leading-6 text-slate-600 sm:text-base">Start with your own business information. Protected partner and admin actions require verified access.</p>
        </div>
        <div className="mt-9 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {tools.map(({ icon: Icon, title, detail }) => (
            <article key={title} className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-orange-50 text-orange-800"><Icon size={19} /></div>
              <h3 className="mt-4 text-base font-extrabold">{title}</h3>
              <p className="mt-2 text-sm leading-6 text-slate-600">{detail}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="border-y border-slate-200 bg-white">
        <div className="mx-auto grid max-w-7xl gap-10 px-5 py-16 sm:px-8 md:grid-cols-[0.8fr_1.2fr] md:py-20 lg:px-10">
          <div>
            <p className="text-xs font-extrabold uppercase tracking-[0.18em] text-emerald-800">Getting started</p>
            <h2 className="mt-3 text-3xl font-black tracking-tight">From application to operations.</h2>
            <p className="mt-4 text-sm leading-6 text-slate-600">Use real business details. Thali reviews new partner applications before operational tools are unlocked.</p>
          </div>
          <ol className="grid gap-3 sm:grid-cols-2">
            {steps.map((step, index) => (
              <li key={step} className="flex gap-4 rounded-2xl border border-slate-200 bg-[#fbfaf7] p-4">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-slate-950 text-xs font-black text-white">0{index + 1}</span>
                <span className="pt-1 text-sm font-semibold leading-6 text-slate-700">{step}</span>
              </li>
            ))}
          </ol>
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-5 py-14 sm:px-8 lg:px-10">
        <div className="flex flex-col gap-5 rounded-3xl bg-slate-950 px-6 py-8 text-white sm:flex-row sm:items-center sm:justify-between sm:px-9 sm:py-10">
          <div><p className="flex items-center gap-2 text-xs font-bold uppercase tracking-widest text-orange-300"><CircleHelp size={14} /> Need help?</p><h2 className="mt-2 text-2xl font-black">We’ll help you get your mess set up.</h2><p className="mt-2 text-sm text-slate-300">Contact the Thali team for partner onboarding or account support.</p></div>
          <div className="flex flex-col gap-2 sm:items-end"><Link href="/contact" className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-white px-4 text-sm font-bold text-slate-950 transition hover:bg-orange-50">Contact support <ArrowRight size={16} /></Link></div>
        </div>
        <p className="mt-5 text-center text-xs text-slate-500">Customer ordering and meal passes continue through the Thali mobile app for now. {APP_CONFIG.brandName} web is currently focused on mess partners and administrators.</p>
      </section>
    </main>
  );
}
