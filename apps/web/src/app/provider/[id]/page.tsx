import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { ArrowLeft, Calendar, CheckCircle2, Clock, MapPin, Store, Utensils, UtensilsCrossed } from 'lucide-react';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

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
      .select('id,display_name,description,locality,city,state,pincode,supports_pickup,public_phone,is_open_today')
      .eq(column, params.id)
      .eq('status', 'active')
      .maybeSingle();

    if (!provider) notFound();

    // Fetch meal slots, menu items, and subscription plans in parallel
    const [slotsResult, menuResult, plansResult] = await Promise.all([
      supabase
        .from('meal_slots')
        .select('id,name,start_time,end_time')
        .eq('provider_id', provider.id)
        .eq('active', true)
        .order('start_time'),
      supabase
        .from('menu_items')
        .select('id,name,description,category,dietary_type,price_paise')
        .eq('provider_id', provider.id)
        .eq('active', true),
      supabase
        .from('subscription_plans')
        .select('id,name,description,plan_type,duration_months,meal_credits,price_paise')
        .eq('provider_id', provider.id)
        .eq('active', true)
        .order('price_paise'),
    ]);

    const slots = slotsResult.data ?? [];
    const menuItems = menuResult.data ?? [];
    const plans = plansResult.data ?? [];

    return (
      <main className="min-h-screen bg-[#fcf8ef] px-4 py-8 sm:px-6 sm:py-12 lg:px-8">
        <div className="mx-auto max-w-4xl space-y-6">
          {/* TOP BREADCRUMB */}
          <Link
            href="/explore"
            className="inline-flex items-center gap-1.5 text-xs font-bold text-amber-800 hover:text-amber-900"
          >
            <ArrowLeft size={14} /> Back to verified kitchens
          </Link>

          {/* KITCHEN PROFILE CARD */}
          <article className="rounded-3xl border border-amber-950/10 bg-white p-6 shadow-sm sm:p-8">
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="flex items-start gap-4">
                <div className="grid h-16 w-16 place-items-center rounded-2xl bg-amber-50 text-amber-800">
                  <Store size={32} aria-hidden="true" />
                </div>
                <div>
                  <div className="inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-3 py-0.5 text-[11px] font-bold text-emerald-800">
                    <CheckCircle2 size={13} /> Verified Kitchen Partner
                  </div>
                  <h1 className="mt-2 text-2xl font-black text-slate-950 sm:text-3xl">
                    {provider.display_name}
                  </h1>
                  <p className="mt-1 flex items-center gap-1.5 text-xs text-slate-600">
                    <MapPin size={14} className="text-slate-400 shrink-0" />
                    {[provider.locality, provider.city, provider.state, provider.pincode].filter(Boolean).join(', ')}
                  </p>
                </div>
              </div>

              {typeof provider.is_open_today === 'boolean' && (
                <span
                  className={`rounded-full px-3 py-1 text-xs font-extrabold ${
                    provider.is_open_today
                      ? 'bg-emerald-100 text-emerald-800'
                      : 'bg-slate-100 text-slate-600'
                  }`}
                >
                  {provider.is_open_today ? '🟢 Open Today' : '🔴 Closed Today'}
                </span>
              )}
            </div>

            {provider.description && (
              <p className="mt-5 whitespace-pre-wrap text-sm leading-6 text-slate-700 border-t border-slate-100 pt-4">
                {provider.description}
              </p>
            )}

            {/* OPERATING MEAL SLOTS */}
            {slots.length > 0 && (
              <div className="mt-6 border-t border-slate-100 pt-5">
                <h2 className="text-xs font-bold uppercase tracking-wider text-slate-500 flex items-center gap-1.5">
                  <Clock size={14} /> Service Timings &amp; Slots
                </h2>
                <div className="mt-3 flex flex-wrap gap-2.5">
                  {slots.map((s) => (
                    <div
                      key={s.id}
                      className="rounded-xl border border-slate-200 bg-slate-50 px-3.5 py-2 text-xs font-semibold text-slate-800"
                    >
                      <span className="capitalize font-bold text-slate-950">{s.name}</span>
                      {s.start_time && s.end_time && (
                        <span className="ml-2 text-slate-500 font-normal">
                          {s.start_time.slice(0, 5)} – {s.end_time.slice(0, 5)}
                        </span>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}
          </article>

          {/* MENU SECTION */}
          <section className="rounded-3xl border border-amber-950/10 bg-white p-6 shadow-sm sm:p-8">
            <h2 className="text-lg font-black text-slate-950 flex items-center gap-2">
              <UtensilsCrossed size={18} className="text-orange-600" />
              Kitchen Menu
            </h2>

            {menuItems.length === 0 ? (
              <div className="mt-4 rounded-2xl border border-dashed border-slate-200 bg-slate-50 p-6 text-center text-xs text-slate-600">
                This partner has not published a digital menu yet. Homestyle dishes are served fresh daily on-site.
              </div>
            ) : (
              <div className="mt-4 grid gap-3 sm:grid-cols-2">
                {menuItems.map((item) => (
                  <div
                    key={item.id}
                    className="flex items-start justify-between gap-3 rounded-2xl border border-slate-200 p-4"
                  >
                    <div>
                      <div className="flex items-center gap-1.5">
                        <span
                          className={`h-2 w-2 rounded-full ${
                            item.dietary_type === 'non_vegetarian' ? 'bg-red-600' : 'bg-emerald-600'
                          }`}
                        />
                        <h3 className="text-sm font-bold text-slate-900">{item.name}</h3>
                      </div>
                      {item.description && (
                        <p className="mt-1 text-xs text-slate-500 line-clamp-2">{item.description}</p>
                      )}
                    </div>
                    {item.price_paise > 0 && (
                      <span className="text-xs font-bold text-slate-900 shrink-0">
                        ₹{(item.price_paise / 100).toLocaleString('en-IN')}
                      </span>
                    )}
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* SUBSCRIPTION PLANS SECTION */}
          <section className="rounded-3xl border border-amber-950/10 bg-white p-6 shadow-sm sm:p-8">
            <h2 className="text-lg font-black text-slate-950 flex items-center gap-2">
              <Calendar size={18} className="text-amber-700" />
              Meal Subscription Plans
            </h2>

            {plans.length === 0 ? (
              <div className="mt-4 rounded-2xl border border-dashed border-slate-200 bg-slate-50 p-6 text-center text-xs text-slate-600">
                No subscription plans are currently active for this kitchen. Please check back later or visit the kitchen directly.
              </div>
            ) : (
              <div className="mt-4 grid gap-4 sm:grid-cols-2">
                {plans.map((p) => (
                  <div
                    key={p.id}
                    className="rounded-2xl border border-amber-200/80 bg-gradient-to-b from-amber-50/30 to-white p-5 flex flex-col justify-between"
                  >
                    <div>
                      <span className="text-[10px] font-extrabold uppercase tracking-wider text-amber-900">
                        {p.plan_type === 'meal_credits' ? 'Meal Credit Pack' : 'Fixed Period Plan'}
                      </span>
                      <h3 className="mt-1 text-base font-black text-slate-950">{p.name}</h3>
                      {p.description && (
                        <p className="mt-1 text-xs text-slate-600 line-clamp-2">{p.description}</p>
                      )}
                    </div>

                    <div className="mt-4 border-t border-amber-100 pt-3 flex items-baseline justify-between">
                      <div>
                        <span className="text-xl font-black text-slate-950">
                          ₹{(p.price_paise / 100).toLocaleString('en-IN')}
                        </span>
                        <span className="ml-1 text-[11px] text-slate-500 font-medium">
                          {p.plan_type === 'meal_credits'
                            ? ` · ${p.meal_credits} meals`
                            : p.duration_months
                            ? ` · ${p.duration_months} mo`
                            : ''}
                        </span>
                      </div>

                      <Link
                        href={`/join/${provider.id}`}
                        className="rounded-xl bg-orange-600 px-3.5 py-1.5 text-xs font-bold text-white hover:bg-orange-700 transition"
                      >
                        Select Plan
                      </Link>
                    </div>
                  </div>
                ))}
              </div>
            )}

            <div className="mt-6 rounded-2xl bg-amber-50/80 border border-amber-200 p-4 text-xs text-amber-950 leading-5">
              <strong>Notice:</strong> Online checkout and payment gateway reconciliation are being connected. Entitlements are created only upon verified payment confirmation. No payment is deducted without verification.
            </div>
          </section>
        </div>
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
