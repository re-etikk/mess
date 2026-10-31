import type { Metadata } from 'next';
import Link from 'next/link';
import { APP_CONFIG } from '@/lib/config';

export const metadata: Metadata = {
  title: 'Find Your Everyday Thali',
  description: 'Thali is building a local meal marketplace for students and professionals. Find verified mess and tiffin providers near you for breakfast, lunch and dinner.',
  alternates: { canonical: 'https://www.thali.store' },
  openGraph: {
    title: 'Thali — Find Your Everyday Thali',
    description: 'Discover local mess and tiffin providers for affordable daily meals.',
    url: 'https://www.thali.store',
  },
};

export default function HomePage() {
  return <main className="mx-auto max-w-5xl px-6 py-20">
    <p className="text-sm font-semibold uppercase tracking-widest text-amber-700">Local food, made simpler</p>
    <h1 className="mt-4 max-w-3xl text-5xl font-bold tracking-tight text-slate-900">Find your everyday thali.</h1>
    <p className="mt-6 max-w-2xl text-lg leading-8 text-slate-600">{APP_CONFIG.brandName} is preparing its local meal marketplace. Provider listings will appear here after verified businesses are onboarded.</p>
    <div className="mt-8 flex gap-3"><Link className="rounded-md bg-slate-900 px-5 py-3 text-white" href="/auth/register">Create account</Link><Link className="rounded-md border border-slate-300 px-5 py-3 text-slate-800" href="/provider/portal">Provider onboarding</Link></div>
    <p className="mt-10 text-sm text-slate-500">Dine-in and visit-provider meals only. No delivery service is currently offered.</p>
  </main>;
}
