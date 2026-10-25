'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { ArrowRight, MapPin, Search, Store } from 'lucide-react';

type Provider = {
  id: string;
  display_name: string;
  slug: string;
  description: string | null;
  locality: string | null;
  city: string;
  state: string;
  supports_pickup: boolean;
};

export default function ExplorePage() {
  const [providers, setProviders] = useState<Provider[]>([]);
  const [query, setQuery] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    let cancelled = false;
    fetch('/api/providers', { cache: 'no-store' })
      .then(async (response) => {
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Provider listings are unavailable.');
        if (!cancelled) setProviders(result.providers);
      })
      .catch((reason: unknown) => { if (!cancelled) setError(reason instanceof Error ? reason.message : 'Provider listings are unavailable.'); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, []);

  const filtered = providers.filter((provider) => `${provider.display_name} ${provider.locality ?? ''} ${provider.city} ${provider.state}`.toLowerCase().includes(query.trim().toLowerCase()));

  return (
    <main className="min-h-[75vh] bg-[#f7f6f2] px-4 py-12 sm:px-6 sm:py-16">
      <div className="mx-auto max-w-6xl">
        <p className="text-xs font-bold uppercase tracking-[0.18em] text-amber-700">Real kitchens · verified listings</p>
        <div className="mt-3 flex flex-col justify-between gap-5 sm:flex-row sm:items-end">
          <div><h1 className="text-3xl font-bold tracking-tight text-slate-950 sm:text-4xl">Explore local meals</h1><p className="mt-3 max-w-xl text-sm leading-6 text-slate-600">Only approved mess and food-provider records from Thali’s connected database appear here.</p></div>
          <Link href="/provider/portal" className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl bg-slate-950 px-4 text-sm font-semibold text-white hover:bg-slate-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-amber-600">List your mess <ArrowRight size={16} aria-hidden="true" /></Link>
        </div>

        <label className="mt-7 flex min-h-12 max-w-lg items-center gap-3 rounded-xl border border-slate-300 bg-white px-4 shadow-sm focus-within:border-amber-600 focus-within:ring-2 focus-within:ring-amber-100"><Search size={17} className="text-slate-500" aria-hidden="true" /><span className="sr-only">Search by mess or location</span><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search mess or city" className="w-full bg-transparent text-sm outline-none placeholder:text-slate-400" /></label>

        {loading && <p role="status" className="mt-8 text-sm text-slate-600">Loading approved listings…</p>}
        {error && <div role="alert" className="mt-8 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-950">{error}<p className="mt-2 text-xs">Listings will appear after backend setup and admin approval. No sample listings are displayed.</p></div>}
        {!loading && !error && filtered.length === 0 && <div className="mt-8 rounded-2xl border border-dashed border-slate-300 bg-white px-6 py-12 text-center"><div className="mx-auto grid h-12 w-12 place-items-center rounded-full bg-amber-50 text-amber-800"><Store size={22} aria-hidden="true" /></div><h2 className="mt-4 font-semibold text-slate-900">{query ? 'No matching kitchens' : 'No approved kitchens yet'}</h2><p className="mx-auto mt-2 max-w-md text-sm leading-6 text-slate-600">{query ? 'Try a different mess name or location.' : 'When mess owners submit real details and an admin approves them, listings will show here.'}</p></div>}
        {!loading && !error && filtered.length > 0 && <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">{filtered.map((provider) => <Link key={provider.id} href={`/provider/${provider.slug}`} className="group rounded-2xl border border-slate-200 bg-white p-5 shadow-sm transition hover:-translate-y-0.5 hover:border-amber-300 hover:shadow-md focus-visible:outline focus-visible:outline-2 focus-visible:outline-amber-600"><div className="grid h-11 w-11 place-items-center rounded-xl bg-amber-50 text-amber-800"><Store size={20} aria-hidden="true" /></div><h2 className="mt-4 text-lg font-bold text-slate-950 group-hover:text-amber-800">{provider.display_name}</h2><p className="mt-2 line-clamp-3 min-h-[3rem] text-sm leading-6 text-slate-600">{provider.description || 'Approved Thali provider.'}</p><p className="mt-4 flex items-center gap-2 text-xs font-medium text-slate-500"><MapPin size={14} aria-hidden="true" />{[provider.locality, provider.city, provider.state].filter(Boolean).join(', ')}</p><p className="mt-4 text-xs font-semibold text-emerald-800">{provider.supports_pickup ? 'Visit provider' : 'Contact for availability'}</p></Link>)}</div>}
      </div>
    </main>
  );
}
