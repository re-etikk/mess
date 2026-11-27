'use client';

import { useState } from 'react';
import Link from 'next/link';
import { ArrowRight, CheckCircle2, Clock3, ShieldAlert, Store, UtensilsCrossed } from 'lucide-react';
import { PartnerSession } from './types';

interface OnboardingProps {
  authenticated: boolean;
  userEmail?: string;
  session: PartnerSession | null;
  onSessionCreated: (nextSession: PartnerSession) => Promise<void> | void;
}

export default function PartnerOnboardingWizard({
  authenticated,
  userEmail,
  session,
  onSessionCreated,
}: OnboardingProps) {
  const [step, setStep] = useState<1 | 2 | 3>(1);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  // Step 1: Account & Kitchen Info
  const [ownerName, setOwnerName] = useState('');
  const [businessName, setBusinessName] = useState('');
  const [email, setEmail] = useState(userEmail || '');
  const [password, setPassword] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [locality, setLocality] = useState('');
  const [city, setCity] = useState('');
  const [stateName, setStateName] = useState('Uttar Pradesh');
  const [pincode, setPincode] = useState('');
  const [description, setDescription] = useState('');
  const [supportsPickup, setSupportsPickup] = useState(true);
  const [supportsDelivery, setSupportsDelivery] = useState(false);
  const [agreedTerms, setAgreedTerms] = useState(true);

  // Step 2: Default Meal Slot Setup (runs after kitchen created)
  const [createdProviderId, setCreatedProviderId] = useState<string>(session?.providerId || '');
  const [createdStatus, setCreatedStatus] = useState<string>(session?.status || '');
  const [slotRates, setSlotRates] = useState<Record<string, { enabled: boolean; start: string; end: string; price: string }>>({
    breakfast: { enabled: true, start: '07:30', end: '10:00', price: '50' },
    lunch: { enabled: true, start: '12:00', end: '15:30', price: '80' },
    snacks: { enabled: false, start: '16:30', end: '18:30', price: '40' },
    dinner: { enabled: true, start: '19:30', end: '22:30', price: '80' },
  });

  // Step 3: Starter Dish & Plan
  const [starterDish, setStarterDish] = useState('Home-Style Thali (Dal, Sabzi, 4 Roti, Rice)');
  const [starterPlanName, setStarterPlanName] = useState('Monthly 2-Meal Mess Pass');
  const [starterPlanPrice, setStarterPlanPrice] = useState('3200');
  const [starterPlanDays, setStarterPlanDays] = useState('30');

  if (session?.providerId && step === 1) {
    const isPending = session.status === 'pending_review';
    const isSuspended = session.status === 'suspended';
    return (
      <div className="mx-auto max-w-2xl rounded-2xl border border-slate-200 bg-white p-8 shadow-sm">
        <div className="flex items-start gap-4">
          <div
            className={`grid h-12 w-12 shrink-0 place-items-center rounded-xl ${
              isSuspended ? 'bg-red-50 text-red-700' : 'bg-amber-50 text-amber-800'
            }`}
          >
            {isSuspended ? <ShieldAlert size={24} /> : <Clock3 size={24} />}
          </div>
          <div>
            <h1 className="text-xl font-black text-slate-950">
              {isSuspended ? 'Kitchen Partner Access Suspended' : 'Kitchen Application Under Admin Review'}
            </h1>
            <p className="mt-2 text-sm text-slate-600 leading-6">
              {isSuspended
                ? 'Your kitchen listing is currently paused by Thali Operations. Open a support ticket from your Partner Login or contact partner support to resolve compliance requirements.'
                : `${session.businessName} has been submitted and is queued for Thali verification. As soon as an admin approves your kitchen, full Partner Portal controls will unlock automatically.`}
            </p>
            <div className="mt-5 flex flex-wrap gap-3">
              <button
                type="button"
                onClick={() => window.location.reload()}
                className="rounded-xl bg-slate-900 px-4 py-2.5 text-xs font-bold text-white hover:bg-slate-800"
              >
                Check Approval Status
              </button>
              <Link
                href="/contact"
                className="rounded-xl border border-slate-300 bg-white px-4 py-2.5 text-xs font-bold text-slate-700 hover:bg-slate-50"
              >
                Contact Support Team
              </Link>
            </div>
            {isPending && (
              <p className="mt-4 text-xs text-slate-500">
                Reference Kitchen ID: <span className="font-mono font-semibold">{session.providerId}</span>
              </p>
            )}
          </div>
        </div>
      </div>
    );
  }

  async function handleStep1Submit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    if (!agreedTerms) {
      setError('Please accept the Partner Terms to continue.');
      return;
    }
    const cleanPhone = phone.replace(/\D/g, '');
    if (cleanPhone.length < 10) {
      setError('Enter a valid 10-digit kitchen contact mobile number.');
      return;
    }
    if (!businessName.trim() || !address.trim() || !city.trim()) {
      setError('Kitchen name, street address, and city are required.');
      return;
    }

    setSubmitting(true);
    try {
      let provId = '';
      let provStatus = 'pending_review';
      let provEmail = email.trim();

      if (authenticated) {
        const res = await fetch('/api/providers/applications', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            display_name: businessName.trim(),
            phone: cleanPhone.slice(-10),
            description: description.trim(),
            address_line1: address.trim(),
            locality: locality.trim() || city.trim(),
            city: city.trim(),
            state: stateName.trim() || 'India',
            pincode: pincode.trim() || '110001',
          }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) throw new Error(data.error || 'Could not submit partner application.');
        provId = data.application?.provider_id || data.application?.id || '';
        provStatus = data.status || 'pending_review';
        provEmail = data.user?.email || email.trim();
      } else {
        if (!email.trim().includes('@') || password.trim().length < 8) {
          throw new Error('Enter a valid email and a password with at least 8 characters.');
        }
        const res = await fetch('/api/provider/register', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email: email.trim(),
            password,
            name: ownerName.trim() || businessName.trim(),
            business_name: businessName.trim(),
            phone: cleanPhone.slice(-10),
            address: address.trim(),
            locality: locality.trim() || city.trim(),
            city: city.trim(),
            state: stateName.trim() || 'India',
            pincode: pincode.trim() || undefined,
            description: description.trim(),
            supports_delivery: supportsDelivery,
            supports_pickup: supportsPickup,
          }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok || !data.success) throw new Error(data.error || 'Partner registration failed.');
        provId = data.user?.provider_id || data.provider?.id || '';
        provStatus = data.provider?.status || 'pending_review';
      }

      if (!provId) {
        throw new Error('Kitchen was saved without a provider reference ID. Please sign in again.');
      }

      setCreatedProviderId(provId);
      setCreatedStatus(provStatus);
      setNotice('Kitchen registered! Now set your serving slots and single-meal rates.');
      setStep(2);
    } catch (err: any) {
      setError(err?.message || 'Unable to register kitchen right now.');
    } finally {
      setSubmitting(false);
    }
  }

  async function handleStep2SaveTimings(e: React.FormEvent) {
    e.preventDefault();
    if (!createdProviderId) {
      setStep(3);
      return;
    }
    setSubmitting(true);
    setError('');
    try {
      const slotsPayload = Object.entries(slotRates).map(([name, cfg]) => ({
        name,
        starts_at_local: `${cfg.start}:00`,
        ends_at_local: `${cfg.end}:00`,
        active: cfg.enabled,
        single_meal_price_inr: cfg.enabled && Number(cfg.price) > 0 ? Number(cfg.price) : null,
      }));
      const res = await fetch('/api/provider/timings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: createdProviderId,
          supports_delivery: supportsDelivery,
          supports_pickup: supportsPickup,
          slots: slotsPayload,
          replace_slots: false,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) throw new Error(data.error || 'Could not save meal slots.');
      setNotice('Serving slots saved. Add your signature dish and first meal pass.');
      setStep(3);
    } catch (err: any) {
      setError(err?.message || 'Failed to save serving times.');
    } finally {
      setSubmitting(false);
    }
  }

  async function handleStep3Finish(e: React.FormEvent) {
    e.preventDefault();
    setSubmitting(true);
    setError('');
    try {
      if (createdProviderId && starterDish.trim()) {
        await fetch('/api/provider/menu', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            provider_id: createdProviderId,
            action: 'add_item',
            slot: 'LUNCH',
            name: starterDish.trim(),
            is_extra: false,
            day_of_week: 'Daily',
            dietary_type: 'vegetarian',
          }),
        }).catch(() => null);
      }

      if (createdProviderId && starterPlanName.trim() && Number(starterPlanPrice) > 0) {
        await fetch('/api/provider/plans', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            provider_id: createdProviderId,
            name: starterPlanName.trim(),
            plan_type: 'fixed_period',
            duration_days: Math.max(1, Number(starterPlanDays) || 30),
            price_inr: Number(starterPlanPrice),
            published: true,
          }),
        }).catch(() => null);
      }

      await onSessionCreated({
        providerId: createdProviderId,
        businessName: businessName.trim() || 'Mess Partner',
        email: email.trim(),
        phone: phone.trim(),
        status: createdStatus || 'pending_review',
      });
    } catch (err: any) {
      setError(err?.message || 'Could not finalize setup.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="mx-auto max-w-3xl">
      <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
        <div className="flex flex-wrap items-center justify-between gap-4 border-b border-slate-100 pb-5">
          <div className="flex items-center gap-3">
            <div className="grid h-11 w-11 place-items-center rounded-xl bg-amber-50 text-amber-800">
              <Store size={22} />
            </div>
            <div>
              <h1 className="text-xl font-black tracking-tight text-slate-950">Partner Onboarding</h1>
              <p className="text-xs text-slate-500">
                Set up your Thali Kitchen, meal slots, walk-in rates &amp; first subscription pass.
              </p>
            </div>
          </div>
          {!authenticated && (
            <Link
              href="/partner/login"
              className="rounded-xl border border-slate-300 px-3.5 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50"
            >
              Existing Partner Login
            </Link>
          )}
        </div>

        <ol className="mt-5 grid grid-cols-3 gap-2 text-xs">
          {[
            { num: 1, label: 'Kitchen Profile' },
            { num: 2, label: 'Slots & Meal Rates' },
            { num: 3, label: 'Starter Menu & Plan' },
          ].map((s) => (
            <li
              key={s.num}
              className={`flex items-center gap-2 rounded-xl border px-3 py-2 font-bold ${
                step === s.num
                  ? 'border-amber-600 bg-amber-50 text-amber-900'
                  : step > s.num
                  ? 'border-emerald-200 bg-emerald-50 text-emerald-800'
                  : 'border-slate-200 text-slate-400'
              }`}
            >
              <span className="inline-flex h-5 w-5 items-center justify-center rounded-full bg-white text-[11px] font-black shadow-sm">
                {step > s.num ? <CheckCircle2 size={14} /> : s.num}
              </span>
              <span className="truncate">{s.label}</span>
            </li>
          ))}
        </ol>

        {notice && (
          <div className="mt-4 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-2.5 text-xs font-semibold text-emerald-900">
            {notice}
          </div>
        )}
        {error && (
          <div role="alert" className="mt-4 rounded-xl border border-red-200 bg-red-50 px-4 py-2.5 text-xs font-semibold text-red-700">
            {error}
          </div>
        )}

        {step === 1 && (
          <form onSubmit={handleStep1Submit} className="mt-6 space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              {!authenticated && (
                <>
                  <div>
                    <label className="block text-xs font-bold text-slate-700">Owner / Manager Name</label>
                    <input
                      type="text"
                      required
                      value={ownerName}
                      onChange={(e) => setOwnerName(e.target.value)}
                      placeholder="e.g. Rajesh Verma"
                      className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-amber-600"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-700">Kitchen Business Name</label>
                    <input
                      type="text"
                      required
                      value={businessName}
                      onChange={(e) => setBusinessName(e.target.value)}
                      placeholder="e.g. Annapurna Home Kitchen"
                      className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-amber-600"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-700">Partner Login Email</label>
                    <input
                      type="email"
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="partner@kitchen.in"
                      className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-amber-600"
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-bold text-slate-700">Password (min 8 chars)</label>
                    <input
                      type="password"
                      required
                      minLength={8}
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      placeholder="Minimum 8 characters"
                      className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-amber-600"
                    />
                  </div>
                </>
              )}

              {authenticated && (
                <div className="sm:col-span-2">
                  <label className="block text-xs font-bold text-slate-700">Kitchen / Mess Name</label>
                  <input
                    type="text"
                    required
                    value={businessName}
                    onChange={(e) => setBusinessName(e.target.value)}
                    placeholder="e.g. Annapurna Home Kitchen"
                    className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-amber-600"
                  />
                </div>
              )}

              <div>
                <label className="block text-xs font-bold text-slate-700">10-Digit Contact Mobile</label>
                <input
                  type="tel"
                  required
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="9876543210"
                  className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 font-mono text-sm outline-none focus:border-amber-600"
                />
              </div>
              <div>
                <label className="block text-xs font-bold text-slate-700">Locality / Area</label>
                <input
                  type="text"
                  required
                  value={locality}
                  onChange={(e) => setLocality(e.target.value)}
                  placeholder="e.g. Sector 62, Campus Road"
                  className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-amber-600"
                />
              </div>
              <div className="sm:col-span-2">
                <label className="block text-xs font-bold text-slate-700">Full Kitchen Address</label>
                <input
                  type="text"
                  required
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                  placeholder="Shop / Floor, Landmark, Street"
                  className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-amber-600"
                />
              </div>
              <div>
                <label className="block text-xs font-bold text-slate-700">City</label>
                <input
                  type="text"
                  required
                  value={city}
                  onChange={(e) => setCity(e.target.value)}
                  placeholder="e.g. Noida"
                  className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-amber-600"
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700">State</label>
                  <input
                    type="text"
                    required
                    value={stateName}
                    onChange={(e) => setStateName(e.target.value)}
                    className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-amber-600"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700">Pincode</label>
                  <input
                    type="text"
                    required
                    maxLength={6}
                    value={pincode}
                    onChange={(e) => setPincode(e.target.value)}
                    placeholder="201301"
                    className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2.5 font-mono text-sm outline-none focus:border-amber-600"
                  />
                </div>
              </div>
              <div className="sm:col-span-2">
                <label className="block text-xs font-bold text-slate-700">About Kitchen (Optional)</label>
                <textarea
                  rows={2}
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                  placeholder="Pure veg home-style meals, RO water, Sunday special..."
                  className="mt-1 w-full rounded-xl border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                />
              </div>
            </div>

            <div className="flex flex-wrap gap-4 rounded-xl border border-slate-200 bg-slate-50 px-4 py-3 text-xs font-semibold text-slate-700">
              <label className="inline-flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={supportsPickup}
                  onChange={(e) => setSupportsPickup(e.target.checked)}
                  className="h-4 w-4 accent-amber-600"
                />
                Dine-in &amp; Counter Pickup
              </label>
              <label className="inline-flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={supportsDelivery}
                  onChange={(e) => setSupportsDelivery(e.target.checked)}
                  className="h-4 w-4 accent-amber-600"
                />
                Tiffin Home Delivery
              </label>
            </div>

            <label className="flex items-start gap-2.5 text-xs text-slate-600 cursor-pointer">
              <input
                type="checkbox"
                checked={agreedTerms}
                onChange={(e) => setAgreedTerms(e.target.checked)}
                className="mt-0.5 h-4 w-4 accent-amber-600"
              />
              <span>
                I confirm my kitchen meets local hygiene &amp; FSSAI norms and agree to Thali Partner Terms.
              </span>
            </label>

            <button
              type="submit"
              disabled={submitting}
              className="inline-flex w-full min-h-11 items-center justify-center gap-2 rounded-xl bg-orange-600 px-5 text-sm font-bold text-white hover:bg-orange-700 disabled:bg-slate-400"
            >
              <span>{submitting ? 'Creating Kitchen Profile...' : 'Save Kitchen & Configure Meal Slots'}</span>
              <ArrowRight size={16} />
            </button>
          </form>
        )}

        {step === 2 && (
          <form onSubmit={handleStep2SaveTimings} className="mt-6 space-y-4">
            <p className="text-xs text-slate-600">
              Enable the meal windows you serve and set each slot&apos;s walk-in Single Meal Rate (optional).
            </p>
            <div className="space-y-3">
              {Object.entries(slotRates).map(([slotKey, cfg]) => (
                <div key={slotKey} className="grid items-center gap-3 rounded-xl border border-slate-200 p-3.5 sm:grid-cols-12">
                  <label className="flex items-center gap-2 font-bold capitalize text-sm text-slate-900 sm:col-span-3 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={cfg.enabled}
                      onChange={(e) =>
                        setSlotRates((prev) => ({
                          ...prev,
                          [slotKey]: { ...prev[slotKey], enabled: e.target.checked },
                        }))
                      }
                      className="h-4 w-4 accent-amber-600"
                    />
                    {slotKey}
                  </label>
                  <div className="flex items-center gap-2 sm:col-span-5">
                    <input
                      type="time"
                      disabled={!cfg.enabled}
                      value={cfg.start}
                      onChange={(e) =>
                        setSlotRates((prev) => ({
                          ...prev,
                          [slotKey]: { ...prev[slotKey], start: e.target.value },
                        }))
                      }
                      className="w-full rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs disabled:bg-slate-100"
                    />
                    <span className="text-xs text-slate-400">to</span>
                    <input
                      type="time"
                      disabled={!cfg.enabled}
                      value={cfg.end}
                      onChange={(e) =>
                        setSlotRates((prev) => ({
                          ...prev,
                          [slotKey]: { ...prev[slotKey], end: e.target.value },
                        }))
                      }
                      className="w-full rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs disabled:bg-slate-100"
                    />
                  </div>
                  <div className="sm:col-span-4">
                    <div className="flex items-center rounded-lg border border-slate-300 px-2.5 py-1.5 text-xs">
                      <span className="text-slate-500 mr-1">₹</span>
                      <input
                        type="number"
                        min={0}
                        disabled={!cfg.enabled}
                        value={cfg.price}
                        onChange={(e) =>
                          setSlotRates((prev) => ({
                            ...prev,
                            [slotKey]: { ...prev[slotKey], price: e.target.value },
                          }))
                        }
                        placeholder="Single rate"
                        className="w-full outline-none bg-transparent disabled:text-slate-400"
                      />
                      <span className="text-[11px] text-slate-400">/meal</span>
                    </div>
                  </div>
                </div>
              ))}
            </div>
            <div className="flex justify-between gap-3 pt-2">
              <button
                type="button"
                onClick={() => setStep(3)}
                className="rounded-xl border border-slate-300 px-4 py-2.5 text-xs font-bold text-slate-700 hover:bg-slate-50"
              >
                Skip for Now
              </button>
              <button
                type="submit"
                disabled={submitting}
                className="inline-flex items-center gap-2 rounded-xl bg-orange-600 px-5 py-2.5 text-xs font-bold text-white hover:bg-orange-700 disabled:bg-slate-400"
              >
                {submitting ? 'Saving Slots...' : 'Save Slots & Next'}
                <ArrowRight size={15} />
              </button>
            </div>
          </form>
        )}

        {step === 3 && (
          <form onSubmit={handleStep3Finish} className="mt-6 space-y-4">
            <div className="rounded-xl border border-slate-200 p-4 space-y-3">
              <div className="flex items-center gap-2 text-sm font-bold text-slate-900">
                <UtensilsCrossed size={16} className="text-amber-700" /> Starter Daily Menu Item (Lunch)
              </div>
              <input
                type="text"
                value={starterDish}
                onChange={(e) => setStarterDish(e.target.value)}
                placeholder="e.g. Dal Fry, Jeera Rice, Seasonal Sabzi, 4 Roti"
                className="w-full rounded-xl border border-slate-300 px-3 py-2.5 text-sm outline-none focus:border-amber-600"
              />
            </div>

            <div className="rounded-xl border border-slate-200 p-4 space-y-3">
              <p className="text-sm font-bold text-slate-900">First Subscription Plan</p>
              <div className="grid gap-3 sm:grid-cols-3">
                <input
                  type="text"
                  value={starterPlanName}
                  onChange={(e) => setStarterPlanName(e.target.value)}
                  placeholder="Plan Name"
                  className="rounded-xl border border-slate-300 px-3 py-2 text-xs outline-none focus:border-amber-600"
                />
                <input
                  type="number"
                  min={1}
                  value={starterPlanDays}
                  onChange={(e) => setStarterPlanDays(e.target.value)}
                  placeholder="Days (e.g. 30)"
                  className="rounded-xl border border-slate-300 px-3 py-2 text-xs outline-none focus:border-amber-600"
                />
                <input
                  type="number"
                  min={1}
                  value={starterPlanPrice}
                  onChange={(e) => setStarterPlanPrice(e.target.value)}
                  placeholder="Price ₹"
                  className="rounded-xl border border-slate-300 px-3 py-2 text-xs outline-none focus:border-amber-600"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="inline-flex w-full min-h-11 items-center justify-center gap-2 rounded-xl bg-slate-900 px-5 text-sm font-bold text-white hover:bg-slate-800 disabled:bg-slate-400"
            >
              {submitting ? 'Finalizing Partner Setup...' : 'Finish & Open Partner Dashboard'}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}
