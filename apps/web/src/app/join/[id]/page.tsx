'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useParams } from 'next/navigation';
import {
  ArrowLeft,
  Calendar,
  CheckCircle2,
  Clock,
  Coins,
  CreditCard,
  MapPin,
  QrCode,
  ShieldCheck,
  Store,
  Tag,
  Truck,
} from 'lucide-react';
import { launchCashfreeWebCheckout } from '@/lib/cashfree-client';

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
  supports_delivery?: boolean;
  supports_pickup?: boolean;
}

interface PromoSuggestion {
  code: string;
  title?: string;
  discount_percent?: number;
  flat_discount_paise?: number;
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
  const [paymentMode, setPaymentMode] = useState<'cashfree' | 'counter_cash'>('cashfree');
  const [fulfillmentMode, setFulfillmentMode] = useState<'pickup' | 'delivery'>('pickup');

  const [platformFeePaise, setPlatformFeePaise] = useState(0);
  const [availablePromos, setAvailablePromos] = useState<PromoSuggestion[]>([]);
  const [promoCode, setPromoCode] = useState('');
  const [promoApplying, setPromoApplying] = useState(false);
  const [appliedPromo, setAppliedPromo] = useState<{ code: string; discount_paise: number; message: string } | null>(null);
  const [promoError, setPromoError] = useState('');

  const [error, setError] = useState('');
  const [successData, setSuccessData] = useState<any>(null);

  useEffect(() => {
    if (!providerId) return;

    let cancelled = false;

    async function loadMessDetails() {
      setLoading(true);
      setError('');
      try {
        const [provRes, plansRes, promoRes, cfgRes] = await Promise.all([
          fetch(`/api/providers`).then((r) => r.json()).catch(() => ({})),
          fetch(`/api/provider/plans?provider_id=${providerId}`).then((r) => r.json()).catch(() => ({})),
          fetch(`/api/promos/validate?provider_id=${providerId}&order_context=plan`).then((r) => r.json()).catch(() => ({})),
          fetch(`/api/app-config`).then((r) => r.json()).catch(() => ({})),
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
        setAvailablePromos(promoRes?.promos || []);
        setPlatformFeePaise(Number(cfgRes?.config?.platform_fee_paise || 0));
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

  const selectedPlan = plans.find((p) => p.id === selectedPlanId);
  const basePlanPaise = selectedPlan?.price_paise || 0;
  const discountPaise = Math.min(basePlanPaise, appliedPromo?.discount_paise || 0);
  const finalPayablePaise = Math.max(0, basePlanPaise - discountPaise) + platformFeePaise;

  async function applyPromo(codeOverride?: string) {
    const clean = (codeOverride ?? promoCode).trim().toUpperCase();
    if (!clean || !selectedPlan) return;
    setPromoApplying(true);
    setPromoError('');
    try {
      const res = await fetch('/api/promos/validate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          code: clean,
          provider_id: provider?.id || providerId,
          order_context: 'plan',
          order_amount_paise: selectedPlan.price_paise,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.isValid) {
        setAppliedPromo(null);
        setPromoError(data.message || data.error || 'Promo code is not valid for this plan.');
      } else {
        setPromoCode(data.code || clean);
        setAppliedPromo({
          code: data.code || clean,
          discount_paise: Number(data.discount_paise || 0),
          message: data.message || 'Promo applied.',
        });
      }
    } catch {
      setPromoError('Could not validate promo code.');
    } finally {
      setPromoApplying(false);
    }
  }

  async function handleCheckoutAttempt(e: React.FormEvent) {
    e.preventDefault();
    if (!phone || phone.replace(/\D/g, '').length < 10) {
      setError('Please enter a valid 10-digit mobile number.');
      return;
    }

    setSubmitting(true);
    setError('');

    try {
      if (paymentMode === 'cashfree') {
        const orderRes = await fetch('/api/payments/cashfree/create-order', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            purpose: 'subscription_purchase',
            provider_id: provider?.id || providerId,
            plan_id: selectedPlanId,
            customer_phone: phone.trim(),
            customer_name: name.trim(),
            customer_email: email.trim(),
            promo_code: appliedPromo?.code || undefined,
            fulfillment_mode: fulfillmentMode,
            plan_type: selectedPlan?.plan_type,
            plan_name: selectedPlan?.name,
            duration_days: selectedPlan?.duration_days || (selectedPlan?.duration_months ? selectedPlan.duration_months * 30 : 30),
            meal_credits: selectedPlan?.meal_credits,
            price_paise: selectedPlan?.price_paise,
          }),
        });
        const orderData = await orderRes.json().catch(() => ({}));
        if (!orderRes.ok || !orderData.success || !orderData.payment_session_id) {
          setError(orderData.error || 'Unable to start Cashfree online checkout. You can choose Pay on Counter instead.');
          return;
        }
        await launchCashfreeWebCheckout({
          paymentSessionId: orderData.payment_session_id,
          environment: orderData.environment === 'production' ? 'production' : 'sandbox',
        });
        return;
      }

      const res = await fetch('/api/subscription/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: provider?.id || providerId,
          plan_id: selectedPlanId,
          customer_phone: phone.trim(),
          customer_name: name.trim(),
          customer_email: email.trim(),
          promo_code: appliedPromo?.code || undefined,
          fulfillment_mode: fulfillmentMode,
          payment_mode: paymentMode,
        }),
      });

      const data = await res.json().catch(() => ({}));

      if (!res.ok || !data.success) {
        setError(data.error || 'Unable to register subscription. Please retry.');
      } else {
        setSuccessData(data);
      }
    } catch (err: any) {
      setError(err?.message || 'Network error registering subscription. Please check your connection.');
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

  // SUCCESS CONFIRMATION VIEW
  if (successData) {
    return (
      <main className="min-h-screen bg-[#fcf8ef] px-4 py-12 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-lg rounded-3xl border border-amber-950/10 bg-white p-7 text-center shadow-lg space-y-6">
          <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-emerald-50 text-emerald-600">
            <CheckCircle2 size={36} />
          </div>

          <div>
            <span className="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-3 py-1 text-xs font-bold text-emerald-800">
              Pass Registered Successfully
            </span>
            <h1 className="mt-3 text-2xl font-black text-slate-900">
              Welcome to {provider?.display_name || 'Kitchen Partner'}!
            </h1>
            <p className="mt-2 text-xs text-slate-600">
              Your meal pass has been registered. Complete the payment at the mess counter to redeem meals seamlessly.
            </p>
          </div>

          <div className="rounded-2xl border border-amber-200 bg-amber-50/70 p-5 text-left text-xs space-y-2.5">
            <div className="flex justify-between items-center text-slate-700">
              <span className="font-semibold">Selected Plan:</span>
              <span className="font-bold text-slate-900">{selectedPlan?.name || 'Meal Plan'}</span>
            </div>
            <div className="flex justify-between items-center text-slate-700">
              <span className="font-semibold">Total to Pay at Counter:</span>
              <span className="text-base font-black text-amber-900">
                ₹{((successData?.subscription?.price_paid_paise ?? finalPayablePaise) / 100).toLocaleString('en-IN')}
              </span>
            </div>
            <div className="flex justify-between items-center text-slate-700">
              <span className="font-semibold">Payment Mode:</span>
              <span className="font-bold text-slate-900 uppercase">
                Cash at Counter
              </span>
            </div>
            <div className="flex justify-between items-center text-slate-700">
              <span className="font-semibold">Customer:</span>
              <span className="font-bold text-slate-900">{name || phone}</span>
            </div>
          </div>

          <div className="rounded-2xl bg-slate-900 p-4 text-white text-xs text-left space-y-2">
            <p className="font-bold flex items-center gap-1.5 text-amber-400">
              <QrCode size={16} /> How to Redeem Meals:
            </p>
            <ol className="list-decimal list-inside space-y-1 text-slate-300 text-[11px] leading-5">
              <li>Visit the mess counter at meal timing (Lunch / Dinner).</li>
              <li>Pay ₹{selectedPlan ? (selectedPlan.price_paise / 100) : 0} in Cash at the counter.</li>
              <li>Scan the daily Mess QR on your mobile app or tell your registered number.</li>
            </ol>
          </div>

          <div className="pt-2 flex flex-col gap-3">
            <Link
              href={`/provider/${provider?.id || providerId}`}
              className="inline-flex min-h-12 items-center justify-center rounded-2xl bg-orange-600 font-bold text-white text-sm shadow hover:bg-orange-700 transition"
            >
              Back to Mess Profile
            </Link>
            <Link
              href="/explore"
              className="text-xs font-bold text-slate-500 hover:text-slate-800 transition"
            >
              Browse Other Messes
            </Link>
          </div>
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
                      onClick={() => {
                        if (selectedPlanId !== plan.id) setAppliedPromo(null);
                        setSelectedPlanId(plan.id);
                      }}
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
                            onChange={() => {
                              if (selectedPlanId !== plan.id) setAppliedPromo(null);
                              setSelectedPlanId(plan.id);
                            }}
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

            {/* STEP 3: OFFERS, FULFILLMENT & PAYMENT METHOD */}
            <div className="rounded-3xl border border-amber-950/10 bg-white p-6 shadow-sm space-y-5">
              <div className="flex items-center gap-2">
                <span className="flex h-6 w-6 items-center justify-center rounded-full bg-amber-600 text-white text-xs font-bold">
                  3
                </span>
                <h3 className="text-base font-bold text-slate-900">Offers &amp; Payment</h3>
              </div>

              {provider?.supports_delivery && (
                <div className="rounded-2xl border border-slate-200 bg-slate-50/70 p-3.5">
                  <p className="text-xs font-bold text-slate-800 flex items-center gap-1.5">
                    <Truck size={14} className="text-amber-700" /> Fulfillment Preference
                  </p>
                  <div className="mt-2 grid grid-cols-2 gap-2">
                    <button
                      type="button"
                      onClick={() => setFulfillmentMode('pickup')}
                      className={`rounded-xl px-3 py-2 text-xs font-bold border transition ${
                        fulfillmentMode === 'pickup'
                          ? 'border-amber-600 bg-white text-amber-900'
                          : 'border-slate-200 bg-transparent text-slate-600'
                      }`}
                    >
                      Dine-in / Counter Pickup
                    </button>
                    <button
                      type="button"
                      onClick={() => setFulfillmentMode('delivery')}
                      className={`rounded-xl px-3 py-2 text-xs font-bold border transition ${
                        fulfillmentMode === 'delivery'
                          ? 'border-amber-600 bg-white text-amber-900'
                          : 'border-slate-200 bg-transparent text-slate-600'
                      }`}
                    >
                      Tiffin Delivery
                    </button>
                  </div>
                </div>
              )}

              <div className="rounded-2xl border border-slate-200 p-4 space-y-2.5">
                <label htmlFor="join-promo" className="flex items-center gap-1.5 text-xs font-bold text-slate-800">
                  <Tag size={14} className="text-orange-600" /> Apply Promo Code
                </label>
                <div className="flex gap-2">
                  <input
                    id="join-promo"
                    type="text"
                    value={promoCode}
                    onChange={(e) => setPromoCode(e.target.value.toUpperCase())}
                    placeholder="Enter coupon code"
                    className="flex-1 rounded-xl border border-slate-300 px-3 py-2 text-xs font-mono uppercase text-slate-900 outline-none focus:border-amber-600"
                  />
                  {appliedPromo ? (
                    <button
                      type="button"
                      onClick={() => {
                        setAppliedPromo(null);
                        setPromoCode('');
                        setPromoError('');
                      }}
                      className="rounded-xl border border-slate-300 px-3.5 text-xs font-bold text-slate-700 hover:bg-slate-50"
                    >
                      Remove
                    </button>
                  ) : (
                    <button
                      type="button"
                      disabled={promoApplying || !promoCode.trim()}
                      onClick={() => applyPromo()}
                      className="rounded-xl bg-slate-900 px-4 text-xs font-bold text-white hover:bg-slate-800 disabled:bg-slate-300"
                    >
                      {promoApplying ? 'Checking...' : 'Apply'}
                    </button>
                  )}
                </div>

                {availablePromos.length > 0 && !appliedPromo && (
                  <div className="flex flex-wrap gap-1.5 pt-1">
                    {availablePromos.slice(0, 4).map((p) => (
                      <button
                        key={p.code}
                        type="button"
                        onClick={() => applyPromo(p.code)}
                        className="rounded-lg border border-amber-300 bg-amber-50 px-2.5 py-1 text-[11px] font-bold text-amber-900 hover:bg-amber-100"
                      >
                        {p.code}
                        {p.flat_discount_paise
                          ? ` · Save ₹${Math.round(p.flat_discount_paise / 100)}`
                          : p.discount_percent
                          ? ` · ${p.discount_percent}% OFF`
                          : ''}
                      </button>
                    ))}
                  </div>
                )}
                {appliedPromo && (
                  <p className="text-[11px] font-semibold text-emerald-700">{appliedPromo.message}</p>
                )}
                {promoError && <p className="text-[11px] font-semibold text-red-600">{promoError}</p>}
              </div>

              <div className="space-y-3">
                <label
                  onClick={() => setPaymentMode('cashfree')}
                  className={`flex items-center gap-3 p-3.5 rounded-2xl border cursor-pointer transition ${
                    paymentMode === 'cashfree'
                      ? 'border-orange-600 bg-orange-50/60 ring-2 ring-orange-600/20'
                      : 'border-slate-200 bg-white'
                  }`}
                >
                  <input
                    type="radio"
                    name="paymentMode"
                    checked={paymentMode === 'cashfree'}
                    onChange={() => setPaymentMode('cashfree')}
                    className="h-4 w-4 accent-orange-600"
                  />
                  <CreditCard className="h-5 w-5 text-orange-600 shrink-0" />
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <p className="text-xs font-bold text-slate-900">Pay Online via Cashfree</p>
                      <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-extrabold text-emerald-800">INSTANT</span>
                    </div>
                    <p className="text-[11px] text-slate-500">UPI, Cards, Netbanking &amp; Wallets · Instant pass activation.</p>
                  </div>
                </label>

                <label
                  onClick={() => setPaymentMode('counter_cash')}
                  className={`flex items-center gap-3 p-3.5 rounded-2xl border cursor-pointer transition ${
                    paymentMode === 'counter_cash'
                      ? 'border-amber-600 bg-amber-50/50 ring-2 ring-amber-600/20'
                      : 'border-slate-200 bg-white'
                  }`}
                >
                  <input
                    type="radio"
                    name="paymentMode"
                    checked={paymentMode === 'counter_cash'}
                    onChange={() => setPaymentMode('counter_cash')}
                    className="h-4 w-4 accent-amber-600"
                  />
                  <Coins className="h-5 w-5 text-amber-700 shrink-0" />
                  <div>
                    <p className="text-xs font-bold text-slate-900">Pay Cash at Mess Counter</p>
                    <p className="text-[11px] text-slate-500">Pay physical cash directly at the mess counter for staff approval.</p>
                  </div>
                </label>
              </div>
            </div>

            {/* STATUS / NOTICE ALERTS */}
            {error && (
              <div role="alert" className="rounded-2xl border border-red-200 bg-red-50 p-4 text-xs text-red-700">
                {error}
              </div>
            )}

            {/* SUMMARY & SUBMIT BUTTON */}
            <div className="space-y-3 pt-2">
              {selectedPlan && (
                <div className="rounded-2xl border border-slate-200 bg-white px-4 py-3 text-xs space-y-1">
                  <div className="flex justify-between text-slate-600">
                    <span>Plan Subtotal</span>
                    <span>₹{(basePlanPaise / 100).toLocaleString('en-IN')}</span>
                  </div>
                  {discountPaise > 0 && (
                    <div className="flex justify-between font-semibold text-emerald-700">
                      <span>Promo Discount ({appliedPromo?.code})</span>
                      <span>-₹{(discountPaise / 100).toLocaleString('en-IN')}</span>
                    </div>
                  )}
                  {platformFeePaise > 0 && (
                    <div className="flex justify-between text-slate-600">
                      <span>Platform Fee</span>
                      <span>₹{(platformFeePaise / 100).toLocaleString('en-IN')}</span>
                    </div>
                  )}
                  <div className="flex justify-between border-t border-slate-100 pt-1.5 text-sm font-black text-slate-950">
                    <span>Total Payable</span>
                    <span>₹{(finalPayablePaise / 100).toLocaleString('en-IN')}</span>
                  </div>
                </div>
              )}

              <button
                type="submit"
                disabled={submitting}
                className="w-full min-h-12 rounded-2xl bg-orange-600 font-black text-white text-sm shadow-md hover:bg-orange-700 disabled:bg-slate-400 transition flex items-center justify-center gap-2"
              >
                <CheckCircle2 size={18} />
                <span>
                  {submitting
                    ? (paymentMode === 'cashfree' ? 'Opening Cashfree Checkout...' : 'Registering Pass...')
                    : paymentMode === 'cashfree'
                    ? `Pay ₹${(finalPayablePaise / 100).toLocaleString('en-IN')} Online (Cashfree)`
                    : `Confirm Pass · Pay ₹${(finalPayablePaise / 100).toLocaleString('en-IN')} on Counter`}
                </span>
              </button>

              <p className="text-center text-[11px] text-slate-500">
                {paymentMode === 'cashfree'
                  ? `Secured by Cashfree Payments. Instant pass activation for ${provider?.display_name || 'the mess'}.`
                  : `Instant registration. You will pay directly to ${provider?.display_name || 'the mess'} at the counter.`}
              </p>
            </div>
          </form>
        )}
      </div>
    </main>
  );
}
