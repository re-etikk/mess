'use client';

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { ArrowRight, MapPin, Search, Store, Lock } from 'lucide-react';

type Provider = {
  id: string;
  display_name: string;
  slug: string;
  description: string | null;
  locality: string | null;
  city: string;
  state: string;
  supports_pickup: boolean;
  is_open_today?: boolean;
};

export default function ExploreClient() {
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
        if (!cancelled) setProviders(result.providers || []);
      })
      .catch((reason: unknown) => {
        if (!cancelled) setError(reason instanceof Error ? reason.message : 'Failed to load providers.');
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, []);

  const filtered = providers.filter((provider) =>
    `${provider.display_name} ${provider.locality || ''} ${provider.city} ${provider.state}`
      .toLowerCase()
      .includes(query.trim().toLowerCase())
  );

  return (
    <main className="min-h-screen bg-amber-50/40 px-4 py-12 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-5xl">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight text-slate-950 sm:text-4xl">Explore Kitchen Partners</h1>
            <p className="mt-2 text-sm text-slate-600">Discover authentic tiffins, hostels, and student mess networks.</p>
          </div>
          <Link
            href="/provider/portal"
            className="inline-flex min-h-11 items-center justify-center rounded-xl bg-amber-600 px-4 text-sm font-semibold text-white shadow-sm transition hover:bg-amber-700"
          >
            Register your mess
            <ArrowRight size={16} className="ml-2" aria-hidden="true" />
          </Link>
        </div>

        <div className="relative mt-8">
          <label htmlFor="search" className="sr-only">
            Search approved kitchens
          </label>
          <Search className="pointer-events-none absolute left-4 top-3.5 text-slate-400" size={18} aria-hidden="true" />
          <input
            id="search"
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Search by kitchen name, locality or city…"
            className="w-full rounded-2xl border border-slate-200 bg-white py-3.5 pl-11 pr-4 text-sm text-slate-900 shadow-sm placeholder:text-slate-400 focus:border-amber-500 focus:outline-none focus:ring-2 focus:ring-amber-500/20"
          />
        </div>

        {loading && <p role="status" className="mt-8 text-sm text-slate-600">Loading approved listings…</p>}
        {error && (
          <div role="alert" className="mt-8 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-950">
            {error}
            <p className="mt-2 text-xs">Listings will appear after backend setup and admin approval. No sample listings are displayed.</p>
          </div>
        )}
        {!loading && !error && filtered.length === 0 && (
          <div className="mt-8 rounded-2xl border border-dashed border-slate-300 bg-white px-6 py-12 text-center">
            <div className="mx-auto grid h-12 w-12 place-items-center rounded-full bg-amber-50 text-amber-800">
              <Store size={22} aria-hidden="true" />
            </div>
            <h2 className="mt-4 font-semibold text-slate-900">{query ? 'No matching kitchens' : 'No approved kitchens yet'}</h2>
            <p className="mx-auto mt-2 max-w-md text-sm leading-6 text-slate-600">
              {query ? 'Try a different mess name or location.' : 'When mess owners submit real details and an admin approves them, listings will show here.'}
            </p>
          </div>
        )}
        {!loading && !error && filtered.length > 0 && (
          <div className="mt-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {filtered.map((provider) => {
              const isClosed = provider.is_open_today === false;
              return (
                <Link
                  key={provider.id}
                  href={`/provider/${provider.slug}`}
                  className={`group relative overflow-hidden rounded-2xl p-5 shadow-sm transition hover:-translate-y-0.5 focus-visible:outline focus-visible:outline-2 ${
                    isClosed
                      ? 'border border-slate-800 bg-slate-950 text-white shadow-xl hover:border-slate-700'
                      : 'border border-slate-200 bg-white hover:border-amber-300 hover:shadow-md focus-visible:outline-amber-600'
                  }`}
                >
                  {isClosed && (
                    <div className="absolute top-3 right-3 flex items-center gap-1 rounded-full bg-red-600/90 px-2.5 py-0.5 text-[10px] font-black uppercase tracking-wider text-white backdrop-blur-sm">
                      <Lock size={10} />
                      CLOSED TODAY
                    </div>
                  )}
                  <div
                    className={`grid h-11 w-11 place-items-center rounded-xl ${
                      isClosed ? 'bg-slate-800 text-slate-300' : 'bg-amber-50 text-amber-800'
                    }`}
                  >
                    <Store size={20} aria-hidden="true" />
                  </div>
                  <h2 className={`mt-4 text-lg font-bold ${isClosed ? 'text-white' : 'text-slate-950 group-hover:text-amber-800'}`}>
                    {provider.display_name}
                  </h2>
                  <p className={`mt-2 line-clamp-3 min-h-[3rem] text-sm leading-6 ${isClosed ? 'text-slate-400' : 'text-slate-600'}`}>
                    {provider.description || 'Approved Thali provider.'}
                  </p>
                  <p className={`mt-4 flex items-center gap-2 text-xs font-medium ${isClosed ? 'text-slate-400' : 'text-slate-500'}`}>
                    <MapPin size={14} aria-hidden="true" />
                    {[provider.locality, provider.city, provider.state].filter(Boolean).join(', ')}
                  </p>
                  <p className={`mt-4 text-xs font-semibold ${isClosed ? 'text-red-400 font-bold' : 'text-emerald-800'}`}>
                    {isClosed ? '🔒 Kitchen closed today' : provider.supports_pickup ? 'Visit provider' : 'Contact for availability'}
                  </p>
                </Link>
              );
            })}
          </div>
        )}
      </div>
    </main>
  );
}
