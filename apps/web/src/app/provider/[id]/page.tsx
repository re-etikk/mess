import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { MapPin, Store } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';

export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  try {
    const supabase = await createClient();
    const column = /^[0-9a-f-]{36}$/i.test(params.id) ? 'id' : 'slug';
    const { data: provider } = await supabase
      .from('providers')
      .select('display_name,description,locality,city')
      .eq(column, params.id)
      .eq('status', 'active')
      .maybeSingle();

    if (provider) {
      return {
        title: `${provider.display_name} — Mess & Daily Meals`,
        description:
          provider.description ||
          `View daily meals, menu and subscription plans for ${provider.display_name} in ${provider.locality || provider.city || 'your area'} on Thali.`,
        alternates: { canonical: `https://www.thali.store/provider/${params.id}` },
        openGraph: {
          title: `${provider.display_name} | Thali`,
          description: provider.description || `Everyday meals at ${provider.display_name}.`,
          url: `https://www.thali.store/provider/${params.id}`,
        },
      };
    }
  } catch {}

  return {
    title: 'Mess Provider',
    description: 'View meal plans and operating hours on Thali.',
    robots: { index: false, follow: false },
  };
}

export default async function ProviderPage({ params }: { params: { id: string } }) {
  try {
    const supabase = await createClient();
    const column = /^[0-9a-f-]{36}$/i.test(params.id) ? 'id' : 'slug';
    const { data: provider } = await supabase
      .from('providers')
      .select('display_name,description,locality,city,state,pincode,supports_pickup')
      .eq(column, params.id)
      .eq('status', 'active')
      .maybeSingle();
    if (!provider) notFound();

    return (
      <main className="min-h-[70vh] bg-[#f7f6f2] px-4 py-12 sm:px-6 sm:py-16">
        <article className="mx-auto max-w-3xl rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-9">
          <Link href="/explore" className="text-sm font-semibold text-amber-800 underline underline-offset-4">
            Back to approved listings
          </Link>
          <div className="mt-7 grid h-14 w-14 place-items-center rounded-2xl bg-amber-50 text-amber-800">
            <Store size={26} aria-hidden="true" />
          </div>
          <p className="mt-5 text-xs font-bold uppercase tracking-[0.16em] text-emerald-800">Approved Thali provider</p>
          <h1 className="mt-2 text-3xl font-bold tracking-tight text-slate-950">{provider.display_name}</h1>
          {provider.description && (
            <p className="mt-4 whitespace-pre-wrap text-base leading-7 text-slate-600">{provider.description}</p>
          )}
          <p className="mt-6 flex items-start gap-2 text-sm text-slate-700">
            <MapPin size={17} className="mt-0.5 shrink-0" aria-hidden="true" />
            {[provider.locality, provider.city, provider.state, provider.pincode].filter(Boolean).join(', ')}
          </p>
          <p className="mt-6 rounded-xl bg-slate-50 p-4 text-sm leading-6 text-slate-700">
            Meal plans and live availability will be shown when the provider publishes them through the connected
            provider tools.{' '}
            {provider.supports_pickup
              ? 'This provider supports in-person visit/pickup.'
              : 'Contact the provider to confirm availability.'}
          </p>
        </article>
      </main>
    );
  } catch (error) {
    if (error && typeof error === 'object' && 'digest' in error) throw error;
    return (
      <main className="mx-auto max-w-3xl px-4 py-16">
        <h1 className="text-2xl font-bold">Provider details unavailable</h1>
        <p className="mt-3 text-slate-600">
          Connect and verify the Thali backend to load approved provider details. No sample business data is shown.
        </p>
      </main>
    );
  }
}
