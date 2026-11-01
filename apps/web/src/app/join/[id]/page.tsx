'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import {
  ArrowLeft,
  Calendar,
  CheckCircle2,
  Clock,
  MapPin,
  ShieldAlert,
  ShieldCheck,
  Store,
  Wallet,
} from 'lucide-react';

interface Plan {
  id: string;
  name: string;
  description: string;
  plan_type: 'fixed_period' | 'meal_credits' | 'daily';
  duration_days?: number;
  duration_months?: number;
  price_paise: number;
  meal_credits?: number | null;
}

interface ProviderInfo {
  id: string;
  display_name: string;
  public_phone?: string;
  phone?: string;
  address_line1?: string;
  locality?: string;
  city: string;
  state?: string;
  description?: string;
  is_open_today?: boolean;
}

export default function JoinMessPage() {
  const params = useParams();
  const providerId = (params?.id as string) || '';

  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [provider, setProvider] = useState<ProviderInfo | null>(null);
  const [plans, setPlans] = useState<Plan[]>([]);
  const [selectedPlanId, setSelectedPlanId] = useState<string>('');

  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');

  const [error, setError] = useState('');
  const [statusNotice, setStatusNotice] = useState('');

  useEffect(() => {
    if (!providerId) return;

    let cancelled = false;

    async function loadMessDetails() {
      setLoading(true);
      setError('');
      try {
        const [provRes, plansRes] = await Promise.all([
          fetch(`/api/providers`).then((r) => r.json()).catch(() => ({})),
          fetch(`/api/provider/plans?provider_id=${providerId}`).then((r) => r.json()).catch(() => ({})),
        ]);

        if (cancelled) return;

        const matched = provRes?.providers?.find(
          (p: { id: string; slug?: string }) => p.id === providerId || p.slug === providerId
        );

        if (matched) {
          setProvider(matched);
        }

        const planList: Plan[] = plansRes?.plans || [];
        if (planList.length > 0) {
          setPlans(planList);
          setSelectedPlanId(planList[0].id);
        } else {
          setPlans([]);
        }
      } catch {
        if (!cancelled) setError('Unable to load kitchen details. Please retry in a moment.');
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void loadMessDetails();

    return () => {
      cancelled = true;
    };
  }, [providerId]);

  async function handleCheckoutAttempt(e: React.FormEvent) {
    e.preventDefault();
    if (!phone || phone.replace(/\D/g, '').length < 10) {
      setError('Please enter a valid 10-digit mobile number.');
      return;
    }

    setSubmitting(true);
    setError('');
    setStatusNotice('');

    try {
      // Call server subscription creation API to verify configured payment pipeline
      const res = await fetch('/api/subscription/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: provider?.id || providerId,
          plan_id: selectedPlanId,
          customer_phone: phone.trim(),
          customer_name: name.trim(),
          customer_email: email.trim(),
        }),
      });

      const data = await res.json().catch(() => ({}));

      if (!res.ok) {
        // Truthful fail-closed notice
        setStatusNotice(
          data.error ||
            'Online payment gateway is being connected for this kitchen. Entitlements are created only upon verified payment confirmation. No payment has been deducted.'
        );
      } else {
        // If payment gateway returns checkout order
        setStatusNotice('Payment order created. Redirecting to secure gateway…');
      }
    } catch {
      setStatusNotice(
        'Online payment is temporarily unavailable. No meal credits or subscriptions have been deducted.'
      );
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) {
    return (
      <main className="min-h-screen bg-[#fcf8ef] flex items-center justify-center p-4">
        <div className="text-center">
          <div className="h-10 w-10 animate-spin rounded-full border-4 border-amber-600 border-t-transparent mx-auto" />
          <p className="mt-4 text-xs font-bold text-slate-700">Connecting to Kitchen Partner…</p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-[#fcf8ef] px-4 py-8 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-2xl space-y-6">
        <Link
          href={`/provider/${provider?.id || providerId}`}
          className="inline-flex items-center gap-1.5 text-xs font-bold text-amber-800 hover:text-amber-900"
        >
          <ArrowLeft size={14} /> Back to kitchen details
        </Link>

        {/* MESS HEADER */}
        <div className="rounded-3xl border border-amber-950/10 bg-white p-6 shadow-sm sm:p-7">
          <div className="flex items-center gap-3">
            <div className="grid h-12 w-12 place-items-center rounded-2xl bg-amber-50 text-amber-900 font-black text-xl">
              <Store size={24} />
            </div>
            <div>
              <div className="inline-flex items-center gap-1 text-[11px] font-bold uppercase tracking-wider text-emerald-800 bg-emerald-50 px-2.5 py-0.5 rounded-full">
                <ShieldCheck size={13} /> Verified Kitchen Partner
              </div>
              <h1 className="text-2xl font-black text-slate-900 tracking-tight mt-1">
                {provider?.display_name || 'Kitchen Partner'}
              </h1>
            </div>
          </div>

          <div className="mt-4 flex flex-wrap gap-y-2 gap-x-4 text-xs text-slate-600 border-t border-slate-100 pt-3">
            <span className="flex items-center gap-1.5">
              <MapPin size={14} className="text-slate-400 shrink-0" />
              {[provider?.locality, provider?.city, provider?.state].filter(Boolean).join(', ') || 'Campus Location'}
            </span>
            <span className="flex items-center gap-1.5">
              <Clock size={14} className="text-emerald-700 shrink-0" />
              {provider?.is_open_today ? 'Open Today' : 'Daily Meals'}
            </span>
          </div>
        </div>

        {/* PLANS OR EMPTY STATE */}
        {plans.length === 0 ? (
          <div className="rounded-3xl border border-dashed border-slate-300 bg-white p-8 text-center space-y-3">
            <Calendar className="h-10 w-10 text-slate-400 mx-auto" />
            <h2 className="text-base font-bold text-slate-900">No Custom Plans Published</h2>
            <p className="text-xs text-slate-600 max-w-md mx-auto leading-5">
              This kitchen partner has not published any custom meal plans yet. You can visit them in person or browse other verified kitchens nearby.
            </p>
            <div className="pt-2">
              <Link
                href="/explore"
                className="inline-flex min-h-10 items-center justify-center rounded-xl bg-orange-600 px-4 text-xs font-bold text-white hover:bg-orange-700"
              >
                Browse Other Messes
              </Link>
            </div>
          </div>
        ) : (
          <form onSubmit={handleCheckoutAttempt} className="space-y-6">
            {/* STEP 1: SELECT PLAN */}
            <div className="rounded-3xl border border-amber-950/10 bg-white p-6 shadow-sm">
              <div className="flex items-center gap-2">
                <span className="flex h-6 w-6 items-center justify-center rounded-full bg-amber-600 text-white text-xs font-bold">
                  1
                </span>
                <h3 className="text-base font-bold text-slate-900">Select Subscription Plan</h3>
              </div>

              <div className="mt-4 space-y-3">
                {plans.map((plan) => {
                  const isSelected = selectedPlanId === plan.id;
                  return (
                    <label
                      key={plan.id}
                      onClick={() => setSelectedPlanId(plan.id)}
                      className={`block cursor-pointer rounded-2xl border p-4 transition ${
                        isSelected
                          ? 'border-amber-600 bg-amber-50/50 ring-2 ring-amber-600/20'
                          : 'border-slate-200 hover:border-slate-300 bg-white'
                      }`}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="flex items-center gap-3">
                          <input
                            type="radio"
                            name="plan"
                            checked={isSelected}
                            onChange={() => setSelectedPlanId(plan.id)}
                            className="h-4 w-4 accent-amber-600"
                          />
                          <div>
                            <p className="text-sm font-bold text-slate-900">{plan.name}</p>
                            {plan.description && (
                              <p className="mt-1 text-xs text-slate-600">{plan.description}</p>
                            )}
                          </div>
                        </div>
                        <div className="text-right shrink-0">
                          <span className="text-lg font-black text-slate-950">
                            ₹{(plan.price_paise / 100).toLocaleString('en-IN')}
                          </span>
                          <span className="block text-[11px] text-slate-500 font-medium">
                            {plan.plan_type === 'meal_credits'
                              ? `${plan.meal_credits} meals`
                              : plan.duration_months
                              ? `${plan.duration_months} mo`
                              : plan.duration_days
                              ? `${plan.duration_days} days`
                              : 'Plan pass'}
                          </span>
                        </div>
                      </div>
                    </label>
                  );
                })}
              </div>
            </div>

            {/* STEP 2: SUBSCRIBER CONTACT */}
            <div className="rounded-3xl border border-amber-950/10 bg-white p-6 shadow-sm">
              <div className="flex items-center gap-2">
                <span className="flex h-6 w-6 items-center justify-center rounded-full bg-amber-600 text-white text-xs font-bold">
                  2
                </span>
                <h3 className="text-base font-bold text-slate-900">Your Contact Details</h3>
              </div>

              <div className="mt-4 space-y-4 text-xs">
                <div>
                  <label htmlFor="join-name" className="block font-bold text-slate-700">
                    Full Name
                  </label>
                  <input
                    id="join-name"
                    type="text"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="e.g. Rahul Sharma"
                    required
                    className="mt-1.5 w-full rounded-xl border border-slate-300 p-3 text-slate-900 outline-none focus:border-amber-600"
                  />
                </div>

                <div>
                  <label htmlFor="join-phone" className="block font-bold text-slate-700">
                    Mobile Number (10 Digits)
                  </label>
                  <input
                    id="join-phone"
                    type="tel"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="e.g. 9876543210"
                    maxLength={10}
                    required
                    className="mt-1.5 w-full rounded-xl border border-slate-300 p-3 text-slate-900 outline-none focus:border-amber-600 font-mono"
                  />
                </div>

                <div>
                  <label htmlFor="join-email" className="block font-bold text-slate-700">
                    Email Address (Optional)
                  </label>
                  <input
                    id="join-email"
                    type="email"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="e.g. rahul@example.com"
                    className="mt-1.5 w-full rounded-xl border border-slate-300 p-3 text-slate-900 outline-none focus:border-amber-600"
                  />
                </div>
              </div>
            </div>

            {/* STATUS / NOTICE ALERTS */}
            {error && (
              <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-4 text-xs text-red-700">
                {error}
              </div>
            )}

            {statusNotice && (
              <div
                role="status"
                className="rounded-2xl border border-amber-200 bg-amber-50 p-4 text-xs text-amber-950 leading-5"
              >
                <div className="flex items-start gap-2">
                  <ShieldAlert className="h-4 w-4 text-amber-700 shrink-0 mt-0.5" />
                  <p>{statusNotice}</p>
                </div>
              </div>
            )}

            {/* SUBMIT BUTTON */}
            <div className="space-y-3 pt-2">
              <button
                type="submit"
                disabled={submitting}
                className="w-full min-h-12 rounded-2xl bg-orange-600 font-black text-white text-sm shadow-md hover:bg-orange-700 disabled:bg-slate-400 transition flex items-center justify-center gap-2"
              >
                <Wallet size={16} />
                <span>{submitting ? 'Connecting...' : 'Proceed to Plan Checkout'}</span>
              </button>

              <p className="text-center text-[11px] text-slate-500">
                Entitlements are created only upon verified payment confirmation. No payment is taken without verification.
              </p>
            </div>
          </form>
        )}
      </div>
    </main>
  );
}
