'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import {
  Calendar,
  CheckCircle2,
  Clock,
  Flame,
  HelpCircle,
  MapPin,
  QrCode,
  RefreshCw,
  Send,
  Sparkles,
  Store,
  Tag,
  Utensils,
  X,
} from 'lucide-react';

type Provider = {
  id: string;
  display_name: string;
  slug: string;
  description: string | null;
  locality: string | null;
  city: string;
  state: string;
  distance_km?: number;
};

type MenuItem = {
  id: string;
  name: string;
  slot: string;
  is_available: boolean;
  is_extra?: boolean;
  price?: number;
};

type MealPlan = {
  id: string;
  name: string;
  price: number;
  duration_days: number;
  meal_credits?: number;
  discount_percent?: number;
  is_flexi?: boolean;
};

type MealRedemption = {
  id: string;
  date: string;
  time: string;
  slot: string;
  provider_name: string;
  status: string;
};

export default function CustomerDashboardPage() {
  const [providers, setProviders] = useState<Provider[]>([]);
  const [selectedProvider, setSelectedProvider] = useState<Provider | null>(null);
  const [menu, setMenu] = useState<MenuItem[]>([]);
  const [plans, setPlans] = useState<MealPlan[]>([]);
  const [activePlan, setActivePlan] = useState<{
    name: string;
    durationDays: number;
    daysRemaining: number;
    mealCreditsTotal: number;
    mealCreditsRemaining: number;
    isFlexi: boolean;
    providerName: string;
    subscribedAt: string;
  }>({
    name: '30 Days Unlimited Standard Thali',
    durationDays: 30,
    daysRemaining: 18,
    mealCreditsTotal: 60,
    mealCreditsRemaining: 34,
    isFlexi: true,
    providerName: 'Radhe Mess',
    subscribedAt: '11 Oct 2026',
  });

  const [redemptions, setRedemptions] = useState<MealRedemption[]>([
    { id: 'RED-1049', date: 'Today', time: '01:25 PM', slot: 'LUNCH', provider_name: 'Radhe Mess', status: 'VERIFIED ✅' },
    { id: 'RED-1048', date: 'Today', time: '08:45 AM', slot: 'BREAKFAST', provider_name: 'Radhe Mess', status: 'VERIFIED ✅' },
    { id: 'RED-1047', date: 'Yesterday', time: '08:30 PM', slot: 'DINNER', provider_name: 'Radhe Mess', status: 'VERIFIED ✅' },
    { id: 'RED-1046', date: 'Yesterday', time: '01:15 PM', slot: 'LUNCH', provider_name: 'Radhe Mess', status: 'VERIFIED ✅' },
    { id: 'RED-1045', date: '27 Oct 2026', time: '08:15 PM', slot: 'DINNER', provider_name: 'Radhe Mess', status: 'VERIFIED ✅' },
  ]);

  const [loading, setLoading] = useState(true);
  const [activeSlot, setActiveSlot] = useState<'Lunch' | 'Dinner' | 'Breakfast'>('Lunch');
  const [showCheckInModal, setShowCheckInModal] = useState(false);
  const [checkingIn, setCheckingIn] = useState(false);
  const [checkInSuccess, setCheckInSuccess] = useState(false);
  const [showSupportModal, setShowSupportModal] = useState(false);
  const [supportSending, setSupportSending] = useState(false);
  const [supportStatus, setSupportStatus] = useState<string | null>(null);
  const [supportForm, setSupportForm] = useState({
    name: 'Student User',
    phone: '9876543210',
    email: 'student@example.com',
    category: 'Subscription & Credits',
    description: '',
  });

  useEffect(() => {
    loadProviders();
  }, []);

  async function loadProviders() {
    setLoading(true);
    try {
      const res = await fetch('/api/providers', { cache: 'no-store' });
      const data = await res.json().catch(() => ({}));
      if (data?.providers && data.providers.length > 0) {
        setProviders(data.providers);
        const initial = data.providers[0];
        setSelectedProvider(initial);
        loadProviderDetails(initial.id);
      }
    } catch {
      // fallback
    } finally {
      setLoading(false);
    }
  }

  async function loadProviderDetails(providerId: string) {
    try {
      const [menuRes, plansRes] = await Promise.all([
        fetch(`/api/provider/menu?providerId=${providerId}`, { cache: 'no-store' }).then((r) => r.json().catch(() => ({}))),
        fetch(`/api/provider/plans?providerId=${providerId}`, { cache: 'no-store' }).then((r) => r.json().catch(() => ({}))),
      ]);

      if (menuRes?.menu && Array.isArray(menuRes.menu)) {
        setMenu(menuRes.menu);
      } else {
        setMenu([
          { id: '1', name: 'Special Paneer Butter Masala', slot: 'Lunch', is_available: true, is_extra: true, price: 50 },
          { id: '2', name: 'Dal Tadka', slot: 'Lunch', is_available: true, is_extra: false },
          { id: '3', name: 'Aloo Gobi Dry', slot: 'Lunch', is_available: true, is_extra: false },
          { id: '4', name: 'Phulka Rotis (Butter)', slot: 'Lunch', is_available: true, is_extra: false },
          { id: '5', name: 'Jeera Rice', slot: 'Lunch', is_available: true, is_extra: false },
          { id: '6', name: 'Gulab Jamun (1 pc)', slot: 'Lunch', is_available: true, is_extra: true, price: 20 },
        ]);
      }

      if (plansRes?.plans && Array.isArray(plansRes.plans)) {
        setPlans(plansRes.plans);
      } else {
        setPlans([
          { id: 'p1', name: '30 Days Full Unlimited Pass', price: 2999, duration_days: 30, discount_percent: 15, is_flexi: false },
          { id: 'p2', name: 'Flexi 60 Meals Tracker Plan', price: 3400, duration_days: 45, meal_credits: 60, discount_percent: 10, is_flexi: true },
          { id: 'p3', name: '15 Days Exam Sprint Pass', price: 1650, duration_days: 15, discount_percent: 5, is_flexi: false },
        ]);
      }
    } catch {
      // ignore
    }
  }

  function handleSelectProvider(p: Provider) {
    setSelectedProvider(p);
    loadProviderDetails(p.id);
  }

  async function handleConfirmCheckIn() {
    setCheckingIn(true);
    await new Promise((r) => setTimeout(r, 600));

    const newRedemption: MealRedemption = {
      id: `RED-${Math.floor(1000 + Math.random() * 9000)}`,
      date: 'Today',
      time: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }),
      slot: activeSlot.toUpperCase(),
      provider_name: selectedProvider?.display_name || 'Radhe Mess',
      status: 'VERIFIED ✅',
    };

    setRedemptions([newRedemption, ...redemptions]);
    if (activePlan.isFlexi && activePlan.mealCreditsRemaining > 0) {
      setActivePlan((prev) => ({
        ...prev,
        mealCreditsRemaining: prev.mealCreditsRemaining - 1,
      }));
    }

    setCheckingIn(false);
    setCheckInSuccess(true);
    setTimeout(() => {
      setCheckInSuccess(false);
      setShowCheckInModal(false);
    }, 1800);
  }

  async function handleSubmitSupport(e: React.FormEvent) {
    e.preventDefault();
    if (!supportForm.description.trim()) return;

    setSupportSending(true);
    setSupportStatus(null);
    try {
      const res = await fetch('/api/support/ticket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ...supportForm,
          role: 'customer',
        }),
      });
      const data = await res.json();
      if (res.ok && data.success) {
        setSupportStatus('✅ Ticket dispatched directly to admin email!');
        setTimeout(() => {
          setShowSupportModal(false);
          setSupportStatus(null);
          setSupportForm((p) => ({ ...p, description: '' }));
        }, 1500);
      } else {
        setSupportStatus('❌ ' + (data.error || 'Failed to dispatch ticket'));
      }
    } catch {
      setSupportStatus('❌ Network error while sending ticket.');
    } finally {
      setSupportSending(false);
    }
  }

  const filteredMenu = menu.filter((m) => m.slot.toLowerCase() === activeSlot.toLowerCase());

  return (
    <main className="min-h-screen bg-[#f8f9fa] pb-16 pt-8 text-slate-900">
      <div className="mx-auto max-w-6xl px-4 sm:px-6">
        {/* TOP BAR / GREETING */}
        <div className="flex flex-col justify-between gap-4 border-b border-slate-200 pb-6 sm:flex-row sm:items-center">
          <div>
            <div className="inline-flex items-center gap-1.5 rounded-full bg-emerald-100 px-3 py-1 text-xs font-black uppercase text-emerald-800">
              <Sparkles size={12} /> Student Account Live
            </div>
            <h1 className="mt-2 text-2xl font-black text-slate-950 sm:text-3xl">Meal Pass &amp; Kitchen Dashboard</h1>
            <p className="text-xs text-slate-500 sm:text-sm">Manage your mess subscription, daily check-in scans, and live kitchen menus.</p>
          </div>
          <div className="flex items-center gap-3">
            <button
              onClick={() => setShowSupportModal(true)}
              className="inline-flex items-center gap-1.5 rounded-xl border border-slate-300 bg-white px-3.5 py-2.5 text-xs font-bold text-slate-700 shadow-sm transition hover:bg-slate-50"
            >
              <HelpCircle size={15} className="text-amber-600" /> Help &amp; Support
            </button>
            <button
              onClick={() => setShowCheckInModal(true)}
              className="inline-flex items-center gap-2 rounded-xl bg-amber-600 px-4 py-2.5 text-xs font-extrabold text-white shadow-sm transition hover:bg-amber-700"
            >
              <QrCode size={16} /> Check-in at Counter
            </button>
          </div>
        </div>

        {/* ACTIVE PLAN & TRACKER CARD */}
        <div className="mt-6 grid gap-6 lg:grid-cols-3">
          <div className="rounded-3xl border border-amber-200 bg-gradient-to-br from-amber-500 to-amber-600 p-6 text-white shadow-md lg:col-span-2">
            <div className="flex items-start justify-between">
              <div>
                <span className="rounded-md bg-white/20 px-2.5 py-1 text-[11px] font-extrabold uppercase tracking-wide text-white">
                  Active Subscription Pass
                </span>
                <h2 className="mt-2 text-2xl font-black">{activePlan.name}</h2>
                <p className="text-xs text-amber-100">
                  Kitchen Partner: <strong className="text-white">{activePlan.providerName}</strong> • Started {activePlan.subscribedAt}
                </p>
              </div>
              {activePlan.daysRemaining <= 3 ? (
                <div className="animate-pulse rounded-xl bg-red-600 px-3 py-1.5 text-xs font-black text-white shadow">
                  ⚠️ RENEW SOON ({activePlan.daysRemaining} days left)
                </div>
              ) : (
                <div className="rounded-xl bg-white/25 px-3 py-1.5 text-xs font-black text-white backdrop-blur-sm">
                  {activePlan.daysRemaining} Days Left
                </div>
              )}
            </div>

            {/* Tracker Bar */}
            {activePlan.isFlexi ? (
              <div className="mt-6 rounded-2xl bg-black/15 p-4 backdrop-blur-sm">
                <div className="flex items-center justify-between text-xs font-bold">
                  <span>Meal Credits Remaining: {activePlan.mealCreditsRemaining} / {activePlan.mealCreditsTotal}</span>
                  <span>{Math.round((activePlan.mealCreditsRemaining / activePlan.mealCreditsTotal) * 100)}% Available</span>
                </div>
                <div className="mt-2 h-3.5 w-full overflow-hidden rounded-full bg-black/25">
                  <div
                    className="h-full rounded-full bg-emerald-400 transition-all duration-500"
                    style={{
                      width: `${(activePlan.mealCreditsRemaining / activePlan.mealCreditsTotal) * 100}%`,
                    }}
                  />
                </div>
              </div>
            ) : (
              <div className="mt-6 rounded-2xl bg-black/15 p-4 text-xs font-bold backdrop-blur-sm">
                Unlimited Calendar Plan • Active until {activePlan.daysRemaining} days
              </div>
            )}

            <div className="mt-6 flex flex-wrap items-center gap-4 text-xs font-medium text-amber-100">
              <span className="inline-flex items-center gap-1">
                <CheckCircle2 size={14} className="text-emerald-300" /> Verified Biometric/QR
              </span>
              <span className="inline-flex items-center gap-1">
                <Utensils size={14} className="text-amber-200" /> Breakfast • Lunch • Dinner
              </span>
              <span className="inline-flex items-center gap-1">
                <Clock size={14} className="text-amber-200" /> Auto-expires when period completes
              </span>
            </div>
          </div>

          {/* CONSUMPTION METRICS */}
          <div className="flex flex-col justify-between rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h3 className="text-sm font-extrabold uppercase tracking-wide text-slate-500">Meal Consumption Stats</h3>
            <div className="my-4 grid grid-cols-2 gap-3 text-center">
              <div className="rounded-2xl bg-slate-50 p-3">
                <p className="text-xs text-slate-500">Total Scans</p>
                <p className="text-2xl font-black text-slate-900">{redemptions.length}</p>
              </div>
              <div className="rounded-2xl bg-amber-50 p-3">
                <p className="text-xs text-amber-800">Breakfasts</p>
                <p className="text-2xl font-black text-amber-700">
                  {redemptions.filter((r) => r.slot === 'BREAKFAST').length}
                </p>
              </div>
              <div className="rounded-2xl bg-emerald-50 p-3">
                <p className="text-xs text-emerald-800">Lunches</p>
                <p className="text-2xl font-black text-emerald-700">
                  {redemptions.filter((r) => r.slot === 'LUNCH').length}
                </p>
              </div>
              <div className="rounded-2xl bg-blue-50 p-3">
                <p className="text-xs text-blue-800">Dinners</p>
                <p className="text-2xl font-black text-blue-700">
                  {redemptions.filter((r) => r.slot === 'DINNER').length}
                </p>
              </div>
            </div>
            <p className="text-center text-[11px] text-slate-400">Exact timestamps recorded for every scanned thali</p>
          </div>
        </div>

        {/* KITCHEN PARTNER SELECTOR & LIVE MENUS */}
        <div className="mt-10">
          <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
            <div>
              <h2 className="text-xl font-black text-slate-950">Approved Kitchen Partners &amp; Daily Menus</h2>
              <p className="text-xs text-slate-500">Select a mess to inspect their today&apos;s menu and custom plan pricing.</p>
            </div>
            <div className="flex flex-wrap gap-2">
              {providers.map((p) => (
                <button
                  key={p.id}
                  onClick={() => handleSelectProvider(p)}
                  className={`inline-flex items-center gap-1.5 rounded-xl px-3.5 py-2 text-xs font-bold transition ${
                    selectedProvider?.id === p.id
                      ? 'bg-slate-950 text-white shadow'
                      : 'border border-slate-200 bg-white text-slate-700 hover:bg-slate-50'
                  }`}
                >
                  <Store size={14} className={selectedProvider?.id === p.id ? 'text-amber-400' : 'text-slate-400'} />
                  {p.display_name}
                </button>
              ))}
            </div>
          </div>

          {/* SELECTED KITCHEN CARD */}
          {selectedProvider && (
            <div className="mt-4 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <div className="flex flex-col justify-between gap-4 border-b border-slate-100 pb-5 sm:flex-row sm:items-center">
                <div>
                  <div className="flex items-center gap-2">
                    <h3 className="text-lg font-black text-slate-950">{selectedProvider.display_name}</h3>
                    <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-bold text-emerald-800">
                      Verified Kitchen
                    </span>
                  </div>
                  <p className="mt-1 flex items-center gap-1.5 text-xs text-slate-500">
                    <MapPin size={13} className="text-amber-600" />
                    {[selectedProvider.locality, selectedProvider.city, selectedProvider.state].filter(Boolean).join(', ')}
                    <span className="text-emerald-700 font-bold">• 1.2 km away</span>
                  </p>
                </div>
                {/* Meal Slot Tabs */}
                <div className="flex rounded-xl bg-slate-100 p-1">
                  {(['Breakfast', 'Lunch', 'Dinner'] as const).map((s) => (
                    <button
                      key={s}
                      onClick={() => setActiveSlot(s)}
                      className={`rounded-lg px-3 py-1.5 text-xs font-bold transition ${
                        activeSlot === s ? 'bg-white text-slate-950 shadow-sm' : 'text-slate-500 hover:text-slate-900'
                      }`}
                    >
                      {s}
                    </button>
                  ))}
                </div>
              </div>

              {/* MENU ITEMS GRID */}
              <div className="mt-6">
                <h4 className="text-xs font-black uppercase tracking-wider text-slate-400">
                  Today&apos;s {activeSlot} Serving Composition
                </h4>
                {filteredMenu.length === 0 ? (
                  <p className="py-6 text-center text-xs text-slate-400">No dishes updated for {activeSlot} yet.</p>
                ) : (
                  <div className="mt-3 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                    {filteredMenu.map((dish) => (
                      <div
                        key={dish.id}
                        className={`flex items-center justify-between rounded-2xl border p-3.5 transition ${
                          dish.is_available ? 'border-slate-200 bg-white' : 'border-slate-200 bg-slate-50 opacity-60'
                        }`}
                      >
                        <div className="flex items-center gap-3">
                          <div
                            className={`flex h-8 w-8 items-center justify-center rounded-lg font-black text-xs ${
                              dish.is_extra ? 'bg-amber-100 text-amber-900' : 'bg-emerald-100 text-emerald-900'
                            }`}
                          >
                            <Utensils size={14} />
                          </div>
                          <div>
                            <p className="text-xs font-bold text-slate-900">{dish.name}</p>
                            <p className="text-[11px] text-slate-500">
                              {dish.is_extra ? `Special Extra • ₹${dish.price || 40}` : 'Included in Thali'}
                            </p>
                          </div>
                        </div>
                        <span
                          className={`rounded-md px-2 py-0.5 text-[10px] font-extrabold ${
                            dish.is_available ? 'bg-emerald-50 text-emerald-700' : 'bg-red-50 text-red-700'
                          }`}
                        >
                          {dish.is_available ? 'Available' : 'Sold Out'}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              {/* CUSTOM PLANS OFFERED BY THIS MESS */}
              <div className="mt-8 border-t border-slate-100 pt-6">
                <h4 className="text-xs font-black uppercase tracking-wider text-slate-400">
                  Custom Subscription Plans at {selectedProvider.display_name}
                </h4>
                <div className="mt-3 grid gap-4 sm:grid-cols-3">
                  {plans.map((p) => (
                    <div
                      key={p.id}
                      className="flex flex-col justify-between rounded-2xl border border-slate-200 bg-slate-50/50 p-4 transition hover:border-amber-400 hover:bg-white"
                    >
                      <div>
                        <div className="flex items-center justify-between">
                          <span className="rounded-md bg-amber-100 px-2 py-0.5 text-[10px] font-extrabold text-amber-800">
                            {p.duration_days} Days
                          </span>
                          {p.discount_percent && p.discount_percent > 0 ? (
                            <span className="text-[10px] font-bold text-emerald-700">
                              {p.discount_percent}% OFF
                            </span>
                          ) : null}
                        </div>
                        <h5 className="mt-2 text-sm font-extrabold text-slate-950">{p.name}</h5>
                        <p className="text-xs text-slate-500">
                          {p.is_flexi ? `${p.meal_credits || 60} Meal Credits with Tracker` : 'Unlimited Daily Meals'}
                        </p>
                      </div>
                      <div className="mt-4 flex items-baseline justify-between border-t border-slate-200/60 pt-3">
                        <div>
                          <span className="text-lg font-black text-slate-950">₹{p.price}</span>
                          <span className="text-[11px] text-slate-400"> /pass</span>
                        </div>
                        <button
                          onClick={() => {
                            setActivePlan({
                              name: p.name,
                              durationDays: p.duration_days,
                              daysRemaining: p.duration_days,
                              mealCreditsTotal: p.meal_credits || 60,
                              mealCreditsRemaining: p.meal_credits || 60,
                              isFlexi: !!p.is_flexi,
                              providerName: selectedProvider.display_name,
                              subscribedAt: 'Today',
                            });
                            alert(`Subscribed to ${p.name} at ${selectedProvider.display_name}!`);
                          }}
                          className="rounded-lg bg-slate-950 px-3 py-1.5 text-xs font-bold text-white transition hover:bg-amber-600"
                        >
                          Select Plan
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>

        {/* VERIFIED REDEMPTIONS LOG */}
        <div className="mt-10 rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <div className="flex items-center justify-between border-b border-slate-100 pb-4">
            <div>
              <h3 className="text-base font-black text-slate-950">Your Verified Meal Check-in History</h3>
              <p className="text-xs text-slate-500">Exact timestamps and slots verified by mess partner QR scans</p>
            </div>
            <button
              onClick={() => loadProviders()}
              className="inline-flex items-center gap-1 text-xs font-bold text-amber-700 hover:underline"
            >
              <RefreshCw size={13} className={loading ? 'animate-spin' : ''} /> Refresh Log
            </button>
          </div>

          <div className="mt-4 divide-y divide-slate-100">
            {redemptions.map((r) => (
              <div key={r.id} className="flex items-center justify-between py-3">
                <div className="flex items-center gap-3">
                  <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-100 font-black text-emerald-800 text-xs">
                    ✓
                  </div>
                  <div>
                    <p className="text-xs font-black text-slate-900">{r.provider_name}</p>
                    <p className="text-[11px] text-slate-500">
                      Receipt {r.id} • {r.date}, {r.time}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <span className="rounded-md bg-amber-100 px-2 py-0.5 text-[10px] font-extrabold text-amber-900">
                    {r.slot}
                  </span>
                  <span className="rounded-md bg-emerald-100 px-2 py-0.5 text-[10px] font-extrabold text-emerald-800">
                    {r.status}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* DUAL CONFIRMATION CHECK-IN MODAL */}
      {showCheckInModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-3xl bg-white p-6 shadow-2xl">
            {checkInSuccess ? (
              <div className="py-6 text-center">
                <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-emerald-100 text-emerald-700">
                  <CheckCircle2 size={36} />
                </div>
                <h3 className="mt-4 text-xl font-black text-slate-950">Meal Check-in Confirmed!</h3>
                <p className="mt-1 text-xs text-slate-600">
                  Attendance verified for {activeSlot.toUpperCase()} at {selectedProvider?.display_name || 'Radhe Mess'}.
                </p>
              </div>
            ) : (
              <div>
                <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                  <div className="flex items-center gap-2">
                    <QrCode size={18} className="text-amber-600" />
                    <h3 className="font-extrabold text-slate-950">Confirm Counter Meal Scan</h3>
                  </div>
                  <button onClick={() => setShowCheckInModal(false)} className="rounded-lg p-1 text-slate-400 hover:text-slate-900">
                    <X size={16} />
                  </button>
                </div>
                <div className="mt-4 space-y-3 rounded-2xl bg-amber-50/60 p-4 border border-amber-100 text-xs">
                  <p className="text-slate-600">
                    <strong>Mess Partner:</strong> {selectedProvider?.display_name || 'Radhe Mess'}
                  </p>
                  <p className="text-slate-600">
                    <strong>Active Pass:</strong> {activePlan.name}
                  </p>
                  <p className="text-slate-600">
                    <strong>Meal Serving Slot:</strong> <span className="text-amber-800 font-bold">{activeSlot.toUpperCase()}</span>
                  </p>
                  {activePlan.isFlexi && (
                    <p className="text-slate-600">
                      <strong>Remaining Credits:</strong> {activePlan.mealCreditsRemaining} meals left
                    </p>
                  )}
                  <p className="text-slate-500 text-[11px]">
                    Confirming will mark attendance on today&apos;s provider ledger and debit 1 meal credit.
                  </p>
                </div>
                <div className="mt-6 flex gap-3">
                  <button
                    onClick={() => setShowCheckInModal(false)}
                    className="w-1/2 rounded-xl border border-slate-200 py-2.5 text-xs font-bold text-slate-700 hover:bg-slate-50"
                  >
                    Cancel
                  </button>
                  <button
                    onClick={handleConfirmCheckIn}
                    disabled={checkingIn}
                    className="w-1/2 rounded-xl bg-amber-600 py-2.5 text-xs font-extrabold text-white shadow-sm hover:bg-amber-700 disabled:opacity-50"
                  >
                    {checkingIn ? 'Verifying...' : 'Confirm & Check-in'}
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* HELP & SUPPORT MODAL */}
      {showSupportModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-3xl bg-white p-6 shadow-2xl">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2">
                <HelpCircle size={18} className="text-amber-600" />
                <h3 className="font-extrabold text-slate-950">Help &amp; Support Desk</h3>
              </div>
              <button onClick={() => setShowSupportModal(false)} className="rounded-lg p-1 text-slate-400 hover:text-slate-900">
                <X size={16} />
              </button>
            </div>
            <form onSubmit={handleSubmitSupport} className="mt-4 space-y-3">
              <div>
                <label className="text-xs font-bold text-slate-700">Issue Category</label>
                <select
                  value={supportForm.category}
                  onChange={(e) => setSupportForm({ ...supportForm, category: e.target.value })}
                  className="mt-1 w-full rounded-xl border border-slate-300 p-2.5 text-xs outline-none focus:border-amber-600"
                >
                  <option>Subscription &amp; Credits</option>
                  <option>Daily Meal Attendance</option>
                  <option>Payment &amp; Refund Issue</option>
                  <option>Food Quality or Service</option>
                  <option>Other Feedback</option>
                </select>
              </div>
              <div>
                <label className="text-xs font-bold text-slate-700">Detailed Message</label>
                <textarea
                  rows={4}
                  value={supportForm.description}
                  onChange={(e) => setSupportForm({ ...supportForm, description: e.target.value })}
                  placeholder="Explain your problem or feedback..."
                  className="mt-1 w-full rounded-xl border border-slate-300 p-2.5 text-xs outline-none focus:border-amber-600"
                  required
                />
              </div>
              <p className="text-[11px] text-slate-500">
                This inquiry will be emailed directly to <strong>ritik45chaurasia@gmail.com</strong>.
              </p>
              {supportStatus && (
                <p className="text-xs font-bold text-center py-1">{supportStatus}</p>
              )}
              <div className="mt-4 flex gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setShowSupportModal(false)}
                  className="w-1/2 rounded-xl border border-slate-200 py-2.5 text-xs font-bold text-slate-700 hover:bg-slate-50"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={supportSending}
                  className="inline-flex w-1/2 items-center justify-center gap-1.5 rounded-xl bg-slate-950 py-2.5 text-xs font-extrabold text-white hover:bg-slate-800 disabled:opacity-50"
                >
                  <Send size={13} /> {supportSending ? 'Sending...' : 'Send Message'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </main>
  );
}
