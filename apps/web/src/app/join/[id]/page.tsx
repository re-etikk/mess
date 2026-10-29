'use client';

import { FormEvent, useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import {
  ArrowRight,
  CheckCircle2,
  Clock,
  MapPin,
  QrCode,
  ShieldCheck,
  Sparkles,
  Store,
  UtensilsCrossed,
  Wallet,
} from 'lucide-react';

interface Plan {
  id: string;
  name: string;
  description: string;
  plan_type: 'fixed_period' | 'meal_credits' | 'daily';
  duration_days: number;
  price_paise: number;
  meal_credits?: number | null;
}

interface ProviderInfo {
  id: string;
  display_name: string;
  phone: string;
  address: string;
  locality?: string;
  city: string;
  description?: string;
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
  const [paymentMode, setPaymentMode] = useState<'cash' | 'counter_upi' | 'online'>('cash');

  const [error, setError] = useState('');
  const [successResult, setSuccessResult] = useState<any | null>(null);

  useEffect(() => {
    if (!providerId) return;

    async function loadMessDetails() {
      setLoading(true);
      setError('');
      try {
        const [dashRes, plansRes] = await Promise.all([
          fetch(`/api/provider/dashboard?provider_id=${providerId}`).then((r) => r.json()).catch(() => ({})),
          fetch(`/api/provider/plans?provider_id=${providerId}`).then((r) => r.json()).catch(() => ({})),
        ]);

        if (dashRes?.provider) {
          setProvider(dashRes.provider);
        } else {
          setProvider({
            id: providerId,
            display_name: 'Mess Partner',
            phone: '',
            address: 'Campus Dining Area',
            city: 'City Area',
          });
        }

        const planList: Plan[] = plansRes?.plans || [];
        if (planList.length > 0) {
          setPlans(planList);
          setSelectedPlanId(planList[0].id);
        } else {
          // Provide sensible defaults if plans aren't custom yet
          const defaultPlans: Plan[] = [
            {
              id: `plan-${providerId}-monthly`,
              name: '30-Day Unlimited Lunch + Dinner',
              description: 'Unlimited homestyle meals (Lunch + Dinner) every day with 4 phulkas, dal & seasonal sabzi.',
              plan_type: 'fixed_period',
              duration_days: 30,
              price_paise: 300000,
            },
            {
              id: `plan-${providerId}-tracker`,
              name: '60-Meal Flexi Tracker Pack',
              description: '60 meal credits valid for 60 days. Skip whenever you go home or eat outside.',
              plan_type: 'meal_credits',
              duration_days: 60,
              price_paise: 240000,
              meal_credits: 60,
            },
            {
              id: `plan-${providerId}-daily`,
              name: 'Single Daily Meal Token',
              description: '1 full meal token valid for today lunch or dinner.',
              plan_type: 'daily',
              duration_days: 1,
              price_paise: 9900,
              meal_credits: 1,
            },
          ];
          setPlans(defaultPlans);
          setSelectedPlanId(defaultPlans[0].id);
        }
      } catch (err: any) {
        setError('Unable to load kitchen details.');
      } finally {
        setLoading(false);
      }
    }

    void loadMessDetails();
  }, [providerId]);

  async function handleJoinSubmit(e: FormEvent) {
    e.preventDefault();
    if (!phone || phone.replace(/\D/g, '').length < 10) {
      setError('Please enter a valid 10-digit mobile number.');
      return;
    }

    setSubmitting(true);
    setError('');

    try {
      const selectedPlan = plans.find((p) => p.id === selectedPlanId);

      const response = await fetch('/api/provider/subscribers/manual', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          customer_name: name.trim(),
          customer_phone: phone.trim(),
          customer_email: email.trim() || undefined,
          plan_id: selectedPlanId,
          payment_mode: paymentMode,
          amount_paid_inr: selectedPlan ? selectedPlan.price_paise / 100 : 3000,
          notes: 'Self-registered via Counter Standee QR',
        }),
      });

      const result = await response.json();
      if (!response.ok || !result.success) {
        throw new Error(result.error || 'Failed to activate subscription.');
      }

      setSuccessResult(result);
    } catch (err: any) {
      setError(err?.message || 'Something went wrong while activating subscription.');
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) {
    return (
      <main className="min-h-screen bg-[#f7f6f2] flex items-center justify-center p-4">
        <div className="text-center">
          <div className="h-10 w-10 animate-spin rounded-full border-4 border-amber-600 border-t-transparent mx-auto" />
          <p className="mt-4 text-sm font-semibold text-slate-700">Connecting to Kitchen Standee…</p>
        </div>
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-[#f7f6f2] px-4 py-8 sm:px-6 lg:px-8">
      <div className="mx-auto max-w-2xl">
        {/* TOP BRANDING & MESS HEADER */}
        <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <div className="flex items-center gap-3">
            <div className="grid h-12 w-12 place-items-center rounded-2xl bg-amber-100 text-amber-900 font-black text-xl">
              <Store size={24} />
            </div>
            <div>
              <div className="inline-flex items-center gap-1 text-[11px] font-bold uppercase tracking-wider text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-full border border-emerald-200">
                <ShieldCheck size={13} /> Verified Kitchen Partner
              </div>
              <h1 className="text-2xl font-black text-slate-900 tracking-tight mt-0.5">
                {provider?.display_name || 'Homely Mess'}
              </h1>
            </div>
          </div>

          <div className="mt-4 flex flex-wrap gap-y-2 gap-x-4 text-xs text-slate-600 border-t border-slate-100 pt-3">
            <span className="flex items-center gap-1.5">
              <MapPin size={14} className="text-amber-700 shrink-0" />
              {provider?.address || provider?.city || 'Campus Location'}
            </span>
            <span className="flex items-center gap-1.5">
              <Clock size={14} className="text-emerald-700 shrink-0" />
              Daily Lunch &amp; Dinner Available
            </span>
          </div>
        </div>

        {/* IF SUCCESS: SHOW DIGITAL MEAL PASS */}
        {successResult ? (
          <div className="mt-6 rounded-2xl border-2 border-emerald-500 bg-white p-6 shadow-lg text-center animate-in fade-in duration-300">
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-emerald-100 text-emerald-700 text-2xl font-bold">
              ✓
            </div>
            <h2 className="mt-3 text-2xl font-black text-slate-900">Subscription Activated!</h2>
            <p className="mt-1 text-sm text-slate-600">
              Welcome, <strong>{name}</strong>! Your meal pass at <strong>{provider?.display_name}</strong> is live.
            </p>

            {/* Meal Pass Ticket */}
            <div className="mt-5 rounded-xl border border-dashed border-emerald-300 bg-emerald-50/50 p-4 text-left">
              <div className="flex justify-between items-start">
                <div>
                  <span className="text-[10px] uppercase font-bold text-emerald-800 tracking-wider">Plan</span>
                  <h4 className="text-base font-bold text-slate-900">{successResult.subscription?.plan_name}</h4>
                </div>
                <span className="rounded-full bg-emerald-600 text-white px-2.5 py-0.5 text-xs font-bold">
                  ACTIVE
                </span>
              </div>

              <div className="mt-4 grid grid-cols-2 gap-3 text-xs border-t border-emerald-200/60 pt-3">
                <div>
                  <span className="text-slate-500 block text-[10px] uppercase">Valid Until</span>
                  <span className="font-bold text-slate-900">
                    {new Date(successResult.subscription?.expires_at).toLocaleDateString('en-IN')}
                  </span>
                </div>
                <div>
                  <span className="text-slate-500 block text-[10px] uppercase">Meals Remaining</span>
                  <span className="font-bold text-emerald-800">
                    {successResult.subscription?.remaining_meal_credits ?? 'Unlimited Meals'}
                  </span>
                </div>
              </div>
            </div>

            <div className="mt-6 flex flex-col gap-3">
              <Link
                href={`/customer/dashboard?phone=${phone.replace(/\D/g, '')}`}
                className="inline-flex min-h-12 items-center justify-center gap-2 rounded-xl bg-slate-950 px-5 text-sm font-bold text-white shadow-md hover:bg-slate-800 transition"
              >
                <QrCode size={18} /> Open My Digital Meal Scanner &rarr;
              </Link>

              {successResult.whatsapp_url && (
                <a
                  href={successResult.whatsapp_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl border border-emerald-300 bg-emerald-50 px-4 text-xs font-bold text-emerald-900 hover:bg-emerald-100 transition"
                >
                  💬 Save Pass Confirmation on WhatsApp
                </a>
              )}
            </div>
          </div>
        ) : (
          /* REGISTRATION & PLAN FORM */
          <form onSubmit={handleJoinSubmit} className="mt-6 space-y-6">
            {/* STEP 1: SELECT PLAN */}
            <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
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
                      className={`block cursor-pointer rounded-xl border p-4 transition ${
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
                            <p className="mt-1 text-xs text-slate-600">{plan.description}</p>
                          </div>
                        </div>
                        <div className="text-right shrink-0">
                          <span className="text-lg font-black text-slate-950">
                            ₹{(plan.price_paise / 100).toLocaleString('en-IN')}
                          </span>
                          <span className="block text-[11px] text-slate-500 font-medium">
                            {plan.plan_type === 'meal_credits' ? `${plan.meal_credits} meals` : `${plan.duration_days} days`}
                          </span>
                        </div>
                      </div>
                    </label>
                  );
                })}
              </div>
            </div>

            {/* STEP 2: STUDENT DETAILS */}
            <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
              <div className="flex items-center gap-2">
                <span className="flex h-6 w-6 items-center justify-center rounded-full bg-amber-600 text-white text-xs font-bold">
                  2
                </span>
                <h3 className="text-base font-bold text-slate-900">Your Student Details</h3>
              </div>

              <div className="mt-4 grid gap-4 sm:grid-cols-2">
                <div>
                  <label className="block text-xs font-bold text-slate-700">Full Name *</label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Aman Sharma"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    className="mt-1.5 min-h-11 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm text-slate-900 outline-none focus:border-amber-600 focus:ring-2 focus:ring-amber-100"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700">Mobile Number (WhatsApp) *</label>
                  <input
                    type="tel"
                    required
                    maxLength={10}
                    placeholder="e.g. 9876543210"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="mt-1.5 min-h-11 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm text-slate-900 outline-none focus:border-amber-600 focus:ring-2 focus:ring-amber-100"
                  />
                </div>

                <div className="sm:col-span-2">
                  <label className="block text-xs font-bold text-slate-700">Email Address (Optional)</label>
                  <input
                    type="email"
                    placeholder="e.g. student@example.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    className="mt-1.5 min-h-11 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm text-slate-900 outline-none focus:border-amber-600 focus:ring-2 focus:ring-amber-100"
                  />
                </div>
              </div>
            </div>

            {/* STEP 3: PAYMENT METHOD */}
            <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
              <div className="flex items-center gap-2">
                <span className="flex h-6 w-6 items-center justify-center rounded-full bg-amber-600 text-white text-xs font-bold">
                  3
                </span>
                <h3 className="text-base font-bold text-slate-900">Payment Option</h3>
              </div>

              <div className="mt-4 grid gap-3 sm:grid-cols-2">
                <label
                  onClick={() => setPaymentMode('cash')}
                  className={`flex cursor-pointer items-center gap-3 rounded-xl border p-3.5 transition ${
                    paymentMode === 'cash' ? 'border-amber-600 bg-amber-50/50 ring-2 ring-amber-600/20' : 'border-slate-200 bg-white'
                  }`}
                >
                  <input
                    type="radio"
                    name="payment"
                    checked={paymentMode === 'cash'}
                    onChange={() => setPaymentMode('cash')}
                    className="h-4 w-4 accent-amber-600"
                  />
                  <div>
                    <span className="text-xs font-bold text-slate-900 block">💵 Cash at Counter</span>
                    <span className="text-[11px] text-slate-500">Pay directly to mess owner</span>
                  </div>
                </label>

                <label
                  onClick={() => setPaymentMode('counter_upi')}
                  className={`flex cursor-pointer items-center gap-3 rounded-xl border p-3.5 transition ${
                    paymentMode === 'counter_upi' ? 'border-amber-600 bg-amber-50/50 ring-2 ring-amber-600/20' : 'border-slate-200 bg-white'
                  }`}
                >
                  <input
                    type="radio"
                    name="payment"
                    checked={paymentMode === 'counter_upi'}
                    onChange={() => setPaymentMode('counter_upi')}
                    className="h-4 w-4 accent-amber-600"
                  />
                  <div>
                    <span className="text-xs font-bold text-slate-900 block">📱 Counter UPI / GPay</span>
                    <span className="text-[11px] text-slate-500">Scanned mess counter QR</span>
                  </div>
                </label>
              </div>
            </div>

            {error && (
              <p role="alert" className="rounded-xl border border-red-200 bg-red-50 p-4 text-xs font-semibold text-red-800">
                {error}
              </p>
            )}

            <button
              type="submit"
              disabled={submitting}
              className="inline-flex min-h-12 w-full items-center justify-center gap-2 rounded-xl bg-slate-950 px-6 text-sm font-bold text-white shadow-lg hover:bg-slate-800 transition disabled:opacity-60"
            >
              {submitting ? 'Activating Subscription…' : 'Activate My Meal Subscription'} <ArrowRight size={17} />
            </button>
          </form>
        )}
      </div>
    </main>
  );
}
