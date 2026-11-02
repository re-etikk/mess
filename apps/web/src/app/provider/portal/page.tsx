'use client';

import { FormEvent, useState, useEffect } from 'react';
import Link from 'next/link';
import QRCode from 'qrcode';
import {
  ArrowLeft,
  ArrowRight,
  CheckCircle2,
  Clock,
  Copy,
  DollarSign,
  HelpCircle,
  MapPin,
  Plus,
  Printer,
  QrCode,
  RefreshCw,
  Share2,
  Store,
  Trash2,
  Users,
  Utensils,
  UtensilsCrossed,
  Power,
  Lock,
} from 'lucide-react';

interface MenuDish {
  name: string;
  isExtra: boolean;
  price: number;
  available: boolean;
  slot: string;
}

interface CustomPlan {
  id?: string;
  name: string;
  days: number;
  price: number;
  type: 'fixed_period' | 'meal_credits';
  credits?: number;
  discount?: number;
  published?: boolean;
  active?: boolean;
  mealSlotIds?: string[];
}

interface ProviderMealSlot {
  id: string;
  name: string;
  starts_at_local: string;
  ends_at_local: string;
  active: boolean;
}

export default function ProviderPortal() {
  const [activeStep, setActiveStep] = useState(1);
  const [activeTab, setActiveTab] = useState<'overview' | 'menu' | 'plans' | 'qr' | 'subscribers' | 'orders' | 'support'>('overview');

  // Session state if provider is already registered/signed in
  const [session, setSession] = useState<{
    providerId: string;
    businessName: string;
    email: string;
    phone: string;
    status: string;
  } | null>(null);
  const [sessionChecked, setSessionChecked] = useState(false);
  const [authenticated, setAuthenticated] = useState(false);

  // Form State for 5-Step Wizard - NO FAKE / PRE-FILLED DEFAULTS
  const [businessName, setBusinessName] = useState('');
  const [phone, setPhone] = useState('');
  const [description, setDescription] = useState('');

  // Step 2: Location
  const [address, setAddress] = useState('');
  const [locality, setLocality] = useState('');
  const [city, setCity] = useState('');
  const [stateName, setStateName] = useState('');
  const [pincode, setPincode] = useState('');

  // Step 3: Timings
  const [bfTime, setBfTime] = useState('');
  const [lunchTime, setLunchTime] = useState('');
  const [dinnerTime, setDinnerTime] = useState('');

  // Step 4: Real Custom Menu (starts completely EMPTY - user must add real dishes)
  const [dishes, setDishes] = useState<MenuDish[]>([]);
  const [newDishName, setNewDishName] = useState('');
  const [newDishPrice, setNewDishPrice] = useState('');
  const [newDishIsExtra, setNewDishIsExtra] = useState(false);
  const [newDishSlot, setNewDishSlot] = useState('lunch');

  // Step 5: Real Custom Plans (starts completely EMPTY - user must configure their real prices)
  const [plans, setPlans] = useState<CustomPlan[]>([]);
  const [newPlanName, setNewPlanName] = useState('');
  const [newPlanDays, setNewPlanDays] = useState('30');
  const [newPlanPrice, setNewPlanPrice] = useState('');
  const [newPlanType, setNewPlanType] = useState<'fixed_period' | 'meal_credits'>('fixed_period');
  const [newPlanCredits, setNewPlanCredits] = useState('');
  const [newPlanDiscount, setNewPlanDiscount] = useState('');
  const [mealSlots, setMealSlots] = useState<ProviderMealSlot[]>([]);
  const [selectedPlanSlots, setSelectedPlanSlots] = useState<string[]>([]);
  const [slotDrafts, setSlotDrafts] = useState<Record<string, { enabled: boolean; start: string; end: string }>>({});
  const [customSlotName, setCustomSlotName] = useState('');
  const [customSlotStart, setCustomSlotStart] = useState('');
  const [customSlotEnd, setCustomSlotEnd] = useState('');
  const [savingSlots, setSavingSlots] = useState(false);
  const [selectedQrSlot, setSelectedQrSlot] = useState('');
  const [mealQr, setMealQr] = useState('');
  const [qrExpiresAt, setQrExpiresAt] = useState(0);
  const [qrLoading, setQrLoading] = useState(false);
  const [qrError, setQrError] = useState('');

  useEffect(() => {
    if (!qrExpiresAt || !mealQr) return;
    const remaining = Math.max(0, qrExpiresAt - Date.now());
    const timer = window.setTimeout(() => {
      setMealQr('');
      setQrError('This QR expired. Generate a fresh one before scanning.');
    }, remaining);
    return () => window.clearTimeout(timer);
  }, [qrExpiresAt, mealQr]);
  const [agreedTerms, setAgreedTerms] = useState(false);

  // Exact step validation functions
  function isStep1Valid(): boolean {
    const cleanPhone = phone.replace(/\D/g, '');
    return (
      businessName.trim().length >= 3 &&
      cleanPhone.length === 10
    );
  }

  function isStep2Valid(): boolean {
    const cleanPin = pincode.replace(/\D/g, '');
    return (
      address.trim().length >= 5 &&
      city.trim().length >= 2 &&
      stateName.trim().length >= 2 &&
      cleanPin.length === 6
    );
  }

  function isStep3Valid(): boolean {
    return lunchTime.trim().length >= 4 && dinnerTime.trim().length >= 4;
  }

  function isStep4Valid(): boolean {
    return dishes.length > 0;
  }

  function isStep5Valid(): boolean {
    return plans.length > 0 && agreedTerms;
  }

  function handleStepClick(targetStep: number) {
    if (targetStep === activeStep) return;
    if (targetStep < activeStep) {
      setError('');
      setActiveStep(targetStep);
      return;
    }
    if (targetStep >= 2 && !isStep1Valid()) {
      setError('Please complete Step 1 with your business name and verified contact phone.');
      return;
    }
    if (targetStep >= 3 && !isStep2Valid()) {
      setError('Please complete Step 2 (Location) with street address, city, state, and 6-digit PIN code.');
      return;
    }
    if (targetStep >= 4 && !isStep3Valid()) {
      setError('Please set your meal serving schedule in Step 3.');
      return;
    }
    if (targetStep >= 5 && !isStep4Valid()) {
      setError('Please add at least one dish to your menu in Step 4 before configuring subscription plans.');
      return;
    }
    setError('');
    setActiveStep(targetStep);
  }

  function addCustomPlan() {
    const name = newPlanName.trim();
    const price = Number(newPlanPrice) || 0;
    const days = Number(newPlanDays) || 30;
    if (!name || name.length < 3) {
      setError('Please enter a descriptive plan name (e.g. 30 Days Unlimited Standard Thali).');
      return;
    }
    if (price <= 0) {
      setError('Please enter a valid subscription price in ₹ (greater than ₹0).');
      return;
    }
    setError('');
    setPlans([
      ...plans,
      {
        name,
        days,
        price,
        type: newPlanType,
        credits: newPlanType === 'meal_credits' ? (Number(newPlanCredits) || 60) : undefined,
        discount: Number(newPlanDiscount) > 0 ? Number(newPlanDiscount) : undefined,
      },
    ]);
    setNewPlanName('');
    setNewPlanPrice('');
    setNewPlanDiscount('');
  }

  function removeCustomPlan(index: number) {
    setPlans(plans.filter((_, i) => i !== index));
  }

  // Portal Management Live Data
  const [subscribers, setSubscribers] = useState<any[]>([]);
  const [redemptions, setRedemptions] = useState<any[]>([]);
  const [counterOrders, setCounterOrders] = useState<any[]>([]);
  const [loadingData, setLoadingData] = useState(false);
  const [selectedSubHistory, setSelectedSubHistory] = useState<any | null>(null);
  const [isOpenToday, setIsOpenToday] = useState(false);
  const [togglingStatus, setTogglingStatus] = useState(false);

  // New counter sale modal state
  const [orderCustomer, setOrderCustomer] = useState('');
  const [orderItems, setOrderItems] = useState('');
  const [orderAmount, setOrderAmount] = useState('');
  const [orderMode, setOrderMode] = useState('cash');

  // Support ticket state
  const [ticketSubject, setTicketSubject] = useState('');
  const [ticketMessage, setTicketMessage] = useState('');
  const [ticketCategory, setTicketCategory] = useState('general');
  const [ticketSuccess, setTicketSuccess] = useState('');

  const [saving, setSaving] = useState(false);
  const [savingPlan, setSavingPlan] = useState(false);
  const [planFormOpen, setPlanFormOpen] = useState(false);
  const [error, setError] = useState('');
  const [successNotice, setSuccessNotice] = useState('');

  // Resolve the signed Supabase session and provider membership; never trust browser storage for authorization.
  useEffect(() => {
    fetch('/api/provider/session', { cache: 'no-store' })
      .then(async (response) => {
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || 'Sign in required.');
        setAuthenticated(true);
        if (result.provider) {
          const providerSession = {
            providerId: result.provider.id,
            businessName: result.provider.name,
            email: result.provider.email,
            phone: result.provider.phone,
            status: result.provider.status,
          };
          setSession(providerSession);
          if (providerSession.status === 'active') loadPortalData(providerSession.providerId);
        }
      })
      .catch(() => setAuthenticated(false))
      .finally(() => setSessionChecked(true));
  }, []);

  async function loadPortalData(providerId: string) {
    setLoadingData(true);
    try {
      const [subsRes, redRes, ordRes, statusRes, plansRes, slotsRes] = await Promise.all([
        fetch(`/api/provider/subscriptions?provider_id=${providerId}`).catch(() => null),
        fetch(`/api/provider/redemptions?provider_id=${providerId}`).catch(() => null),
        fetch(`/api/provider/orders?provider_id=${providerId}`).catch(() => null),
        fetch(`/api/provider/status?provider_id=${providerId}`).catch(() => null),
        fetch(`/api/provider/plans?provider_id=${providerId}`, { cache: 'no-store' }).catch(() => null),
        fetch(`/api/provider/timings?provider_id=${providerId}`, { cache: 'no-store' }).catch(() => null),
      ]);
      if (statusRes?.ok) {
        const sData = await statusRes.json().catch(() => ({}));
        if (typeof sData.is_open_today === 'boolean') {
          setIsOpenToday(sData.is_open_today);
        }
      }
      if (subsRes?.ok) {
        const d = await subsRes.json();
        setSubscribers(d.subscriptions || []);
      }
      if (redRes?.ok) {
        const d = await redRes.json();
        setRedemptions(d.redemptions || []);
      }
      if (ordRes?.ok) {
        const d = await ordRes.json();
        setCounterOrders(d.orders || []);
      }
      if (plansRes?.ok) {
        const d = await plansRes.json();
        setPlans((d.plans || []).map((plan: any) => ({
          id: plan.id,
          name: plan.name,
          days: plan.duration_months ? Number(plan.duration_months) * 30 : 0,
          price: Number(plan.price_paise || 0) / 100,
          type: plan.plan_type,
          credits: plan.meal_credits ?? undefined,
          discount: plan.promo_price_paise && plan.price_paise
            ? Math.round((1 - Number(plan.promo_price_paise) / Number(plan.price_paise)) * 100)
            : undefined,
          published: plan.published,
          active: plan.active,
        })));
      }
      if (slotsRes?.ok) {
        const d = await slotsRes.json();
        const slots = (d.slots || []) as ProviderMealSlot[];
        setMealSlots(slots);
        setSlotDrafts(Object.fromEntries(slots.map((slot) => [slot.name.toLowerCase(), {
          enabled: slot.active,
          start: String(slot.starts_at_local).slice(0, 5),
          end: String(slot.ends_at_local).slice(0, 5),
        }])));
        const activeSlots = slots.filter((slot) => slot.active);
        setSelectedQrSlot((current) => activeSlots.some((slot) => slot.name.toLowerCase() === current)
          ? current
          : activeSlots[0]?.name.toLowerCase() || '');
      }
    } catch {}
    setLoadingData(false);
  }

  async function saveMealSlots() {
    if (!session?.providerId) return;
    setSavingSlots(true);
    setError('');
    try {
      const slots = Object.entries(slotDrafts).flatMap(([name, timing]) => {
        if (!timing?.enabled) return [];
        if (!timing.start || !timing.end || timing.end <= timing.start) {
          throw new Error(`Set a valid end time after the start time for ${name}.`);
        }
        return [{ name, starts_at_local: `${timing.start}:00`, ends_at_local: `${timing.end}:00`, active: true }];
      });
      const response = await fetch('/api/provider/timings', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider_id: session.providerId, slots, replace_slots: true }),
      });
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(result.error || 'Meal slots could not be saved.');
      await loadPortalData(session.providerId);
      setSuccessNotice('Serving times saved. You can now attach plans to these meal slots.');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Meal slots could not be saved.');
    } finally { setSavingSlots(false); }
  }

  function addCustomMealSlot() {
    const name = customSlotName.trim();
    const key = name.toLowerCase();
    if (name.length < 2 || name.length > 40) return setError('Custom meal slot name must be 2–40 characters.');
    if (!customSlotStart || !customSlotEnd || customSlotEnd <= customSlotStart) return setError('Choose a valid custom serving time; the end must be later than the start.');
    if (Object.keys(slotDrafts).some((existing) => existing.toLowerCase() === key)) return setError('A meal slot with this name already exists.');
    setSlotDrafts((current) => ({ ...current, [key]: { enabled: true, start: customSlotStart, end: customSlotEnd } }));
    setCustomSlotName('');
    setCustomSlotStart('');
    setCustomSlotEnd('');
    setError('');
  }

  async function generateMealQr() {
    if (!session?.providerId || !selectedQrSlot) return;
    setQrLoading(true); setQrError(''); setMealQr('');
    try {
      const response = await fetch('/api/provider/qr/generate', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider_id: session.providerId, slot: selectedQrSlot }),
      });
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(result.error || 'Daily meal QR could not be issued.');
      setMealQr(await QRCode.toDataURL(result.token, { width: 320, margin: 2, errorCorrectionLevel: 'H' }));
      setQrExpiresAt(Date.now() + 5 * 60 * 1000);
    } catch (cause) {
      setQrError(cause instanceof Error ? cause.message : 'Daily meal QR could not be issued.');
    } finally { setQrLoading(false); }
  }

  async function saveProviderPlan() {
    if (!session?.providerId) return;
    const name = newPlanName.trim();
    const price = Number(newPlanPrice);
    const days = Number(newPlanDays);
    const credits = Number(newPlanCredits);
    const discount = Number(newPlanDiscount);
    if (name.length < 2) return setError('Enter a plan name with at least 2 characters.');
    if (!Number.isFinite(price) || price <= 0) return setError('Enter a plan price greater than ₹0.');
    if (newPlanType === 'fixed_period' && ![30, 90, 180, 360].includes(days)) {
      return setError('Choose a supported duration: 1, 3, 6, or 12 months.');
    }
    if (newPlanType === 'meal_credits' && (!Number.isInteger(credits) || credits < 1)) {
      return setError('Enter at least 1 meal credit.');
    }
    if (newPlanDiscount && (!Number.isFinite(discount) || discount < 1 || discount > 90)) {
      return setError('Discount must be between 1% and 90%.');
    }

    setSavingPlan(true);
    setError('');
    try {
      const response = await fetch('/api/provider/plans', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: session.providerId,
          name,
          plan_type: newPlanType,
          duration_days: newPlanType === 'fixed_period' ? days : undefined,
          meal_credits: newPlanType === 'meal_credits' ? credits : undefined,
          price_inr: price,
          discount_percent: newPlanDiscount ? discount : undefined,
          meal_slot_ids: selectedPlanSlots,
          published: selectedPlanSlots.length > 0,
        }),
      });
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(result.error || 'Plan could not be saved.');
      const plan = result.plan;
      setPlans((current) => [{
        id: plan.id,
        name: plan.name,
        days: plan.duration_months ? Number(plan.duration_months) * 30 : 0,
        price: Number(plan.price_paise) / 100,
        type: plan.plan_type,
        credits: plan.meal_credits ?? undefined,
        discount: plan.promo_price_paise && plan.price_paise
          ? Math.round((1 - Number(plan.promo_price_paise) / Number(plan.price_paise)) * 100)
          : undefined,
        published: plan.published,
        active: plan.active,
      }, ...current]);
      setNewPlanName('');
      setNewPlanPrice('');
      setNewPlanCredits('');
      setNewPlanDiscount('');
      setSelectedPlanSlots([]);
      setPlanFormOpen(false);
      setSuccessNotice('Plan saved to your Thali account.');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Plan could not be saved. Try again.');
    } finally {
      setSavingPlan(false);
    }
  }

  async function handleToggleStatus() {
    if (!session?.providerId) return;
    setTogglingStatus(true);
    try {
      const nextStatus = !isOpenToday;
      const res = await fetch('/api/provider/status', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: session.providerId,
          is_open: nextStatus,
        }),
      });
      if (res.ok) {
        setIsOpenToday(nextStatus);
        setSuccessNotice(
          nextStatus
            ? '🟢 Kitchen marked OPEN & SERVING TODAY. Students can scan and claim meals.'
            : '🔴 Kitchen marked CLOSED / OFF TODAY. Dark shade applied and scans are paused.'
        );
      }
    } catch {}
    setTogglingStatus(false);
  }

  async function handleOnboardingSubmit(e: FormEvent) {
    e.preventDefault();
    if (!authenticated) {
      setError('Sign in to your Thali account before submitting a partner application.');
      return;
    }
    if (!agreedTerms) {
      setError('Please agree to the platform provider terms to continue.');
      return;
    }
    setSaving(true);
    setError('');
    try {
      const res = await fetch('/api/providers/applications', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          display_name: businessName,
          phone,
          description,
          address_line1: address,
          locality: locality || city,
          city,
          state: stateName,
          pincode,
        }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Failed to submit application.');
      const providerId = data.application?.provider_id || data.application?.id;
      if (!providerId) throw new Error('The application was not saved with a provider ID. Please retry.');

      const newSession = {
        providerId,
        businessName,
        email: data.user?.email || '',
        phone,
        status: 'pending_review',
      };
      setSession(newSession);
      setSuccessNotice('Your application was submitted to Thali for review. Partner tools become available after approval.');
    } catch (err: any) {
      setError(err.message || 'Registration failed.');
    } finally {
      setSaving(false);
    }
  }

  function addDish() {
    if (!newDishName.trim()) return;
    setDishes([
      ...dishes,
      {
        name: newDishName.trim(),
        isExtra: newDishIsExtra,
        price: newDishIsExtra ? Number(newDishPrice) || 30 : 0,
        available: true,
        slot: newDishSlot,
      },
    ]);
    setNewDishName('');
  }

  function removeDish(index: number) {
    setDishes(dishes.filter((_, i) => i !== index));
  }

  async function recordCounterOrder() {
    if (!session) return;
    try {
      const response = await fetch('/api/provider/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: session.providerId,
          customer_name: orderCustomer.trim(),
          items_summary: orderItems.trim(),
          total_amount_inr: Number(orderAmount),
          payment_mode: orderMode,
        }),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Could not save the order.');
      await loadPortalData(session.providerId);
      setOrderCustomer('');
      setOrderItems('');
      setOrderAmount('');
      alert(result.message || 'Order saved.');
    } catch (error) {
      alert(error instanceof Error ? error.message : 'Could not save the order.');
    }
  }

  async function submitSupportDesk() {
    if (!ticketSubject.trim() || !ticketMessage.trim() || !session) return;
    try {
      await fetch('/api/support/ticket', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: session.businessName,
          email: session.email,
          phone: session.phone,
          role: 'provider',
          subject: ticketSubject,
          message: ticketMessage,
          category: ticketCategory,
        }),
      });
      setTicketSuccess('Support ticket dispatched to support@thali.store! Support will reply via email.');
      setTicketSubject('');
      setTicketMessage('');
    } catch {}
  }

  async function openStudentHistory(subId: string, studentName: string) {
    if (!session) return;
    try {
      const res = await fetch(`/api/provider/subscribers/${subId}/history?provider_id=${session.providerId}`);
      if (res.ok) {
        const d = await res.json();
        setSelectedSubHistory({ studentName, history: d.history || [] });
      }
    } catch {}
  }

  const siteBase = process.env.NEXT_PUBLIC_SITE_URL || (typeof window !== 'undefined' ? window.location.origin : 'https://mess.store');
  const joinLink = session ? `${siteBase}/join/${session.providerId}` : '';
  const standeeLink = session ? `${siteBase}/provider/standee?provider_id=${session.providerId}` : '';

  // ------------------------------------------------------------------------------------------------
  // RENDER PORTAL (IF LOGGED IN)
  // ------------------------------------------------------------------------------------------------
  if (!sessionChecked) return <main className="mx-auto min-h-[60vh] max-w-3xl px-4 py-16"><p role="status" className="text-sm text-slate-600">Checking your signed-in partner account…</p></main>;
  if (session) {
    if (session.status !== 'active') {
      return <main className="mx-auto min-h-[70vh] max-w-3xl px-4 py-16"><section className="rounded-2xl border border-amber-200 bg-white p-7 shadow-sm"><p className="text-xs font-bold uppercase tracking-widest text-amber-800">Partner application</p><h1 className="mt-2 text-2xl font-black text-slate-950">{session.businessName}</h1><p className="mt-3 text-sm text-slate-700">Your application status: <strong>{session.status.replace('_', ' ')}</strong>.</p><p className="mt-2 text-sm text-slate-600">Menu, plans, QR, and subscriber tools unlock after Thali approves the business.</p><button type="button" onClick={async () => { await fetch('/api/auth/logout', { method: 'POST' }); setSession(null); setAuthenticated(false); }} className="mt-5 min-h-11 rounded-lg border border-slate-300 px-4 text-sm font-semibold">Sign out</button></section></main>;
    }
    return (
      <main className="min-h-screen bg-[#f7f6f2] px-4 py-8 text-slate-900 sm:px-6 lg:px-8">
        <div className="mx-auto max-w-6xl">
          {/* Header */}
          <div className="flex flex-col gap-4 border-b border-slate-200 pb-5 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <div className="inline-flex items-center gap-2 rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-bold text-emerald-800">
                <Store size={14} /> ACTIVE KITCHEN PARTNER PORTAL
              </div>
              <h1 className="mt-2 text-2xl font-black text-slate-950 sm:text-3xl">{session.businessName}</h1>
              <p className="text-xs text-slate-500">ID: {session.providerId} · {session.phone}</p>
            </div>
            <div className="flex gap-2">
              <Link
                href={standeeLink}
                target="_blank"
                className="inline-flex items-center gap-1.5 rounded-xl border border-slate-300 bg-white px-3.5 py-2 text-xs font-bold shadow-sm hover:bg-slate-50 transition"
              >
                <Printer size={15} /> Print Standee
              </Link>
              <button
                type="button"
              onClick={async () => {
                  await fetch('/api/auth/logout', { method: 'POST' });
                  setSession(null);
                  setAuthenticated(false);
                }}
                className="rounded-xl border border-red-200 bg-red-50 px-3.5 py-2 text-xs font-bold text-red-800 hover:bg-red-100 transition"
              >
                Sign Out
              </button>
            </div>
          </div>

          {/* Navigation Tabs */}
          <nav className="mt-6 flex flex-wrap gap-2 border-b border-slate-200 pb-2">
            {[
              { id: 'overview', label: 'Overview & Scans', icon: CheckCircle2 },
              { id: 'menu', label: 'Menu & Dishes', icon: UtensilsCrossed },
              { id: 'plans', label: 'Plans & Pricing', icon: DollarSign },
              { id: 'qr', label: 'Counter QR Hub', icon: QrCode },
              { id: 'subscribers', label: `Subscribers (${subscribers.length})`, icon: Users },
              { id: 'orders', label: 'Counter Sales', icon: Store },
              { id: 'support', label: 'Help Desk', icon: HelpCircle },
            ].map((tab) => {
              const Icon = tab.icon;
              const isSel = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id as any)}
                  className={`inline-flex items-center gap-2 rounded-xl px-4 py-2.5 text-xs font-extrabold transition ${
                    isSel
                      ? 'bg-amber-500 text-slate-950 shadow-sm'
                      : 'bg-white text-slate-600 hover:bg-slate-100'
                  }`}
                >
                  <Icon size={16} />
                  {tab.label}
                </button>
              );
            })}
          </nav>

          {/* TAB 1: OVERVIEW */}
          {activeTab === 'overview' && (
            <div className="mt-6 space-y-6">
              <div className="grid gap-4 sm:grid-cols-3">
                <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                  <p className="text-xs font-bold text-slate-500 uppercase">Today&apos;s Verified Redemptions</p>
                  <p className="mt-2 text-3xl font-black text-emerald-700">{redemptions.length}</p>
                  <p className="mt-1 text-xs text-slate-500">Live QR scans at counter</p>
                </div>
                <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                  <p className="text-xs font-bold text-slate-500 uppercase">Active Subscribers</p>
                  <p className="mt-2 text-3xl font-black text-slate-950">{subscribers.length}</p>
                  <p className="mt-1 text-xs text-slate-500">Monthly & flexi students</p>
                </div>
                <div className="rounded-2xl border border-slate-200 bg-white p-5 shadow-sm">
                  <p className="text-xs font-bold text-slate-500 uppercase">Walk-in Counter Orders</p>
                  <p className="mt-2 text-3xl font-black text-amber-600">{counterOrders.length}</p>
                  <p className="mt-1 text-xs text-slate-500">Direct cash/UPI sales</p>
                </div>
              </div>

              <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
                <div className="flex items-center justify-between pb-4 border-b border-slate-100">
                  <h2 className="text-base font-bold text-slate-950">Today&apos;s Verified Redemptions Log</h2>
                  <button
                    onClick={() => loadPortalData(session.providerId)}
                    className="inline-flex items-center gap-1 text-xs font-bold text-amber-700 hover:underline"
                  >
                    <RefreshCw size={13} className={loadingData ? 'animate-spin' : ''} /> Refresh
                  </button>
                </div>
                {redemptions.length === 0 ? (
                  <p className="mt-6 text-center text-sm text-slate-500 py-6">No meals redeemed yet today. Scanned counter QR entries will appear here instantly.</p>
                ) : (
                  <div className="mt-4 divide-y divide-slate-100">
                    {redemptions.map((r) => (
                      <div key={r.id} className="flex items-center justify-between py-3">
                        <div className="flex items-center gap-3">
                          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-emerald-100 text-emerald-800 font-bold">
                            ✓
                          </div>
                          <div>
                            <p className="text-sm font-bold text-slate-900">{r.customer_name || 'Verified Student'} · {r.slot}</p>
                            <p className="text-xs text-slate-500">{r.plan_name} · {r.time_formatted || r.redeemed_at}</p>
                          </div>
                        </div>
                        <span className="rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-bold text-emerald-700">VERIFIED</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>
          )}

          {/* TAB 2: MENU MANAGEMENT */}
          {activeTab === 'menu' && (
            <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
              <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between border-b border-slate-100 pb-4">
                <div>
                  <h2 className="text-lg font-bold text-slate-950">Daily Menu & Extra Portions</h2>
                  <p className="text-xs text-slate-500">Add dishes, set extra prices, and toggle out-of-stock items.</p>
                </div>
              </div>

              {/* Add dish inline */}
              <div className="mt-5 grid gap-3 rounded-xl border border-slate-200 bg-slate-50/70 p-4 sm:grid-cols-[1.5fr_0.8fr_0.8fr_auto]">
                <input
                  type="text"
                  placeholder="Dish name (e.g. Matar Paneer, Jeera Rice)"
                  value={newDishName}
                  onChange={(e) => setNewDishName(e.target.value)}
                  className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                />
                <select
                  value={newDishSlot}
                  onChange={(e) => setNewDishSlot(e.target.value)}
                  className="rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none bg-white"
                >
                  <option value="lunch">Lunch</option>
                  <option value="dinner">Dinner</option>
                  <option value="breakfast">Breakfast</option>
                </select>
                <div className="flex items-center gap-2">
                  <label className="text-xs font-semibold text-slate-600 flex items-center gap-1 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={newDishIsExtra}
                      onChange={(e) => setNewDishIsExtra(e.target.checked)}
                      className="accent-amber-600"
                    />
                    Extra Add-on
                  </label>
                  {newDishIsExtra && (
                    <input
                      type="number"
                      placeholder="₹"
                      value={newDishPrice}
                      onChange={(e) => setNewDishPrice(e.target.value)}
                      className="w-16 rounded-lg border border-slate-300 px-2 py-1.5 text-xs"
                    />
                  )}
                </div>
                <button
                  type="button"
                  onClick={addDish}
                  className="inline-flex items-center justify-center gap-1 rounded-lg bg-amber-500 px-4 py-2 text-xs font-bold text-slate-950 hover:bg-amber-600 transition"
                >
                  <Plus size={14} /> Add Item
                </button>
              </div>

              {/* Dishes list */}
              <div className="mt-6 divide-y divide-slate-100">
                {dishes.map((dish, idx) => (
                  <div key={idx} className="flex items-center justify-between py-3">
                    <div className="flex items-center gap-3">
                      <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-amber-100 text-amber-900 font-bold">
                        🍽️
                      </div>
                      <div>
                        <p className={`text-sm font-bold ${!dish.available ? 'line-through text-slate-400' : 'text-slate-900'}`}>
                          {dish.name}
                        </p>
                        <p className="text-xs text-slate-500">
                          {dish.isExtra ? `₹${dish.price} extra add-on` : 'Included in standard thali'} · {dish.slot.toUpperCase()}
                        </p>
                      </div>
                    </div>
                    <div className="flex items-center gap-3">
                      <button
                        type="button"
                        onClick={() => {
                          const updated = [...dishes];
                          updated[idx].available = !updated[idx].available;
                          setDishes(updated);
                        }}
                        className={`rounded-full px-2.5 py-1 text-xs font-bold transition ${
                          dish.available ? 'bg-emerald-100 text-emerald-800' : 'bg-red-100 text-red-800'
                        }`}
                      >
                        {dish.available ? 'Available' : 'Sold Out'}
                      </button>
                      <button
                        type="button"
                        onClick={() => removeDish(idx)}
                        className="rounded-lg p-1.5 text-slate-400 hover:bg-slate-100 hover:text-red-700 transition"
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* TAB 3: PLANS & PRICING */}
          {activeTab === 'plans' && (
            <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h2 className="text-lg font-bold text-slate-950">Plans & Pricing</h2>
                  <p className="mt-1 text-xs text-slate-500">Saved plans are shared with the Thali app. Set real prices and terms for your mess.</p>
                </div>
                <button type="button" onClick={() => { setPlanFormOpen((open) => !open); setError(''); }} className="inline-flex min-h-10 items-center gap-2 rounded-lg bg-amber-500 px-4 text-sm font-bold text-slate-950 hover:bg-amber-600">
                  <Plus size={16} /> {planFormOpen ? 'Cancel' : 'Add plan'}
                </button>
              </div>

              {plans.length === 0 ? (
                <div className="mt-5 rounded-xl border border-dashed border-slate-300 bg-slate-50 px-5 py-8 text-center">
                  <DollarSign className="mx-auto text-slate-400" size={24} />
                  <p className="mt-2 text-sm font-semibold text-slate-800">No plans have been saved yet</p>
                  <p className="mt-1 text-xs text-slate-500">Add your first plan. Nothing is prefilled or published as sample data.</p>
                </div>
              ) : (
                <div className="mt-5 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                  {plans.map((p, i) => (
                    <div key={p.id || `${p.name}-${i}`} className="rounded-xl border border-slate-200 p-4">
                      <div className="flex items-start justify-between gap-2">
                        <h3 className="font-extrabold text-sm text-slate-950">{p.name}</h3>
                        {p.discount ? <span className="shrink-0 rounded-full bg-emerald-100 px-2 py-0.5 text-[10px] font-bold text-emerald-800">{p.discount}% OFF</span> : null}
                      </div>
                      <p className="mt-3 text-2xl font-black text-slate-950">₹{p.price.toLocaleString('en-IN')}</p>
                      <p className="mt-1 text-xs text-slate-500">
                        {p.type === 'meal_credits' ? `${p.credits} meal credits` : `${p.days} days · fixed period`}
                      </p>
                      <p className="mt-3 text-[11px] font-semibold text-slate-600">{p.active === false ? 'Inactive' : p.published === false ? 'Draft' : 'Published'}</p>
                    </div>
                  ))}
                </div>
              )}

              {planFormOpen && (
                <div className="mt-5 rounded-xl border border-amber-200 bg-amber-50/50 p-4">
                  <h3 className="font-bold text-slate-950">Create a plan</h3>
                  <div className="mt-4 grid gap-3 sm:grid-cols-2">
                    <label className="text-xs font-semibold text-slate-700">Plan name
                      <input value={newPlanName} onChange={(e) => setNewPlanName(e.target.value)} maxLength={100} placeholder="e.g. Monthly lunch plan" className="mt-1 min-h-10 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm" />
                    </label>
                    <label className="text-xs font-semibold text-slate-700">Plan type
                      <select value={newPlanType} onChange={(e) => setNewPlanType(e.target.value as CustomPlan['type'])} className="mt-1 min-h-10 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm">
                        <option value="fixed_period">Fixed period</option>
                        <option value="meal_credits">Meal credits</option>
                      </select>
                    </label>
                    {newPlanType === 'fixed_period' ? (
                      <label className="text-xs font-semibold text-slate-700">Plan duration
                        <select value={newPlanDays} onChange={(e) => setNewPlanDays(e.target.value)} className="mt-1 min-h-10 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm">
                          <option value="30">1 month (30 days)</option><option value="90">3 months (90 days)</option><option value="180">6 months (180 days)</option><option value="360">12 months (360 days)</option>
                        </select>
                      </label>
                    ) : (
                      <label className="text-xs font-semibold text-slate-700">Meal credits
                        <input type="number" min="1" step="1" value={newPlanCredits} onChange={(e) => setNewPlanCredits(e.target.value)} placeholder="e.g. 60" className="mt-1 min-h-10 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm" />
                      </label>
                    )}
                    <label className="text-xs font-semibold text-slate-700">Price (₹)
                      <input type="number" min="1" step="0.01" value={newPlanPrice} onChange={(e) => setNewPlanPrice(e.target.value)} placeholder="Enter your price" className="mt-1 min-h-10 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm" />
                    </label>
                    <label className="text-xs font-semibold text-slate-700">Discount (optional, 1–90%)
                      <input type="number" min="1" max="90" step="1" value={newPlanDiscount} onChange={(e) => setNewPlanDiscount(e.target.value)} placeholder="Leave blank for no discount" className="mt-1 min-h-10 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm" />
                    </label>
                  </div>
                  {error && <p role="alert" className="mt-3 rounded-lg bg-red-50 p-3 text-sm text-red-800">{error}</p>}
                  <div className="mt-4 flex justify-end">
                    <button type="button" disabled={savingPlan} onClick={saveProviderPlan} className="min-h-10 rounded-lg bg-slate-950 px-5 text-sm font-bold text-white disabled:opacity-60">{savingPlan ? 'Saving…' : 'Save plan'}</button>
                  </div>
                  <div className="mt-4 rounded-lg border border-slate-200 bg-white p-3">
                    <p className="text-xs font-semibold text-slate-800">Meal slots covered by this plan</p>
                    {mealSlots.filter((slot) => slot.active).length ? (
                      <div className="mt-2 flex flex-wrap gap-3">
                        {mealSlots.filter((slot) => slot.active).map((slot) => (
                          <label key={slot.id} className="flex items-center gap-2 text-xs text-slate-700">
                            <input type="checkbox" checked={selectedPlanSlots.includes(slot.id)} onChange={(e) => setSelectedPlanSlots((ids) => e.target.checked ? [...ids, slot.id] : ids.filter((id) => id !== slot.id))} />
                            {slot.name}
                          </label>
                        ))}
                      </div>
                    ) : <p className="mt-1 text-xs text-amber-800">No active serving times configured. Save your real meal times in Counter QR Hub first; this plan will be saved as a draft until you select a slot.</p>}
                  </div>
                  <p className="mt-3 text-[11px] text-slate-500">A plan is published only after you associate it with at least one active meal slot. Payment collection stays subject to verified checkout configuration.</p>
                </div>
              )}
            </div>
          )}

          {/* TAB 4: COUNTER QR HUB */}
          {activeTab === 'qr' && (
            <div className="mt-6 grid gap-6 sm:grid-cols-2">
              <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm text-center">
                <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-bold text-amber-800">
                  SECURE REDEMPTION
                </span>
                <h3 className="mt-3 text-lg font-bold text-slate-950">Daily meal redemption QR</h3>
                <p className="mt-1 text-xs text-slate-500">Generate a signed QR for the selected serving. It expires after five minutes.</p>
                <div className="my-4 flex flex-wrap justify-center gap-2">
                  <select aria-label="Meal slot" disabled={!mealSlots.some((slot) => slot.active)} value={selectedQrSlot} onChange={(e) => { setSelectedQrSlot(e.target.value); setMealQr(''); setQrError(''); }} className="min-h-10 min-w-48 rounded-lg border border-slate-300 bg-white px-3 text-sm disabled:bg-slate-100">
                    {!mealSlots.some((slot) => slot.active) && <option value="">No active serving slot</option>}
                    {mealSlots.filter((slot) => slot.active).map((slot) => <option key={slot.id} value={slot.name.toLowerCase()}>{slot.name}</option>)}
                  </select>
                  <button type="button" onClick={generateMealQr} disabled={qrLoading || !mealSlots.some((slot) => slot.active)} className="inline-flex min-h-10 items-center gap-2 rounded-lg bg-slate-950 px-4 text-sm font-bold text-white disabled:opacity-50">
                    <RefreshCw size={15} className={qrLoading ? 'animate-spin' : ''} /> {qrLoading ? 'Issuing…' : mealQr ? 'Refresh QR' : 'Generate daily QR'}
                  </button>
                </div>
                {mealQr ? <div className="mx-auto my-4 w-fit rounded-xl border border-slate-200 bg-white p-3"><img src={mealQr} alt={`${selectedQrSlot} meal redemption QR`} className="h-56 w-56" /></div> : <div className="my-4 grid min-h-40 place-items-center rounded-2xl border-2 border-dashed border-slate-300 bg-slate-50 px-6 text-sm text-slate-500">{mealSlots.some((slot) => slot.active) ? 'Generate a fresh QR when a subscriber is ready to redeem.' : 'Configure a real serving time below to enable QR generation.'}</div>}
                {mealQr && <p className="text-xs font-semibold text-emerald-800">QR expires at {new Date(qrExpiresAt).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}. Refresh before scanning if expired.</p>}
                {qrError && <p role="alert" className="mt-3 rounded-lg bg-red-50 p-3 text-left text-sm text-red-800">{qrError}</p>}
                {!mealSlots.some((slot) => slot.active) && <p className="text-xs font-bold text-amber-800">No active meal slot is configured.</p>}
              </div>

              <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
                <h3 className="text-lg font-bold text-slate-950">Serving times</h3>
                <p className="mt-1 text-xs text-slate-500">Set actual meal windows for your mess. These slots are shared with plans and redemption checks.</p>
                <div className="mt-4 space-y-3">
                  {Array.from(new Set(['breakfast', 'lunch', 'dinner', ...Object.keys(slotDrafts)])).map((name) => {
                    const timing = slotDrafts[name] || { enabled: false, start: '', end: '' };
                    return <div key={name} className="grid grid-cols-[1fr_1fr_1fr_auto] items-end gap-2 rounded-lg border border-slate-200 p-3">
                      <label className="text-xs font-semibold capitalize text-slate-700">{name}<span className="mt-1 block text-sm font-normal text-slate-500">{timing.enabled ? 'Enabled' : 'Disabled'}</span></label>
                      <label className="text-[11px] font-semibold text-slate-600">Starts<input type="time" value={timing.start} onChange={(e) => setSlotDrafts((all) => ({ ...all, [name]: { ...timing, start: e.target.value } }))} className="mt-1 min-h-9 w-full rounded-md border border-slate-300 px-2 text-sm" /></label>
                      <label className="text-[11px] font-semibold text-slate-600">Ends<input type="time" value={timing.end} onChange={(e) => setSlotDrafts((all) => ({ ...all, [name]: { ...timing, end: e.target.value } }))} className="mt-1 min-h-9 w-full rounded-md border border-slate-300 px-2 text-sm" /></label>
                      <input type="checkbox" aria-label={`Enable ${name}`} checked={timing.enabled} onChange={(e) => setSlotDrafts((all) => ({ ...all, [name]: { ...timing, enabled: e.target.checked } }))} className="mb-3 h-4 w-4" />
                    </div>;
                  })}
                </div>
                <div className="mt-4 rounded-lg border border-dashed border-slate-300 p-3">
                  <p className="text-xs font-semibold text-slate-800">Add a custom meal slot</p>
                  <div className="mt-2 grid gap-2 sm:grid-cols-[1.3fr_1fr_1fr_auto] sm:items-end">
                    <label className="text-[11px] font-semibold text-slate-600">Slot name<input value={customSlotName} onChange={(e) => setCustomSlotName(e.target.value)} maxLength={40} placeholder="e.g. Evening snacks" className="mt-1 min-h-9 w-full rounded-md border border-slate-300 px-2 text-sm" /></label>
                    <label className="text-[11px] font-semibold text-slate-600">Starts<input type="time" value={customSlotStart} onChange={(e) => setCustomSlotStart(e.target.value)} className="mt-1 min-h-9 w-full rounded-md border border-slate-300 px-2 text-sm" /></label>
                    <label className="text-[11px] font-semibold text-slate-600">Ends<input type="time" value={customSlotEnd} onChange={(e) => setCustomSlotEnd(e.target.value)} className="mt-1 min-h-9 w-full rounded-md border border-slate-300 px-2 text-sm" /></label>
                    <button type="button" onClick={addCustomMealSlot} className="min-h-9 rounded-md border border-slate-300 px-3 text-xs font-bold text-slate-800 hover:bg-slate-50">Add slot</button>
                  </div>
                </div>
                <p className="mt-2 text-[11px] text-slate-500">Times use your provider&apos;s local timezone. End time must be later than the start time. Add breakfast, lunch, dinner, or a custom serving window.</p>
                {error && <p role="alert" className="mt-3 rounded-lg bg-red-50 p-3 text-sm text-red-800">{error}</p>}
                <button type="button" onClick={saveMealSlots} disabled={savingSlots} className="mt-4 min-h-10 rounded-lg bg-amber-500 px-4 text-sm font-bold text-slate-950 disabled:opacity-60">{savingSlots ? 'Saving…' : 'Save serving times'}</button>
                <p className="mt-3 text-xs text-slate-500">QR issuance also requires a published plan linked to that slot and the server signing key configured.</p>
              </div>

              <div className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm text-center">
                <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-bold text-amber-800">
                  PARTNER PAGE
                </span>
                <h3 className="mt-3 text-lg font-bold text-slate-950">Walk-in Registration Standee</h3>
                <p className="mt-1 text-xs text-slate-500">Share your partner page. Online checkout is not active yet.</p>
                <div className="my-6 inline-block rounded-2xl border-2 border-amber-500 p-4 bg-white shadow-md">
                  <img
                    src={`https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${encodeURIComponent(joinLink)}`}
                    alt="Join Standee QR"
                    className="h-48 w-48 mx-auto"
                  />
                </div>
                <div className="flex justify-center gap-3">
                  <Link
                    href={standeeLink}
                    target="_blank"
                    className="inline-flex items-center gap-1.5 rounded-xl bg-slate-950 px-4 py-2 text-xs font-bold text-white shadow-sm hover:bg-slate-800 transition"
                  >
                    <Printer size={15} /> Print Standee
                  </Link>
                  <button
                    onClick={() => {
                      navigator.clipboard.writeText(joinLink);
                      alert('Joining link copied! Share it on WhatsApp.');
                    }}
                    className="inline-flex items-center gap-1.5 rounded-xl border border-slate-300 bg-white px-4 py-2 text-xs font-bold text-slate-800 shadow-sm hover:bg-slate-50 transition"
                  >
                    <Share2 size={15} /> WhatsApp Share
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* TAB 5: SUBSCRIBERS */}
          {activeTab === 'subscribers' && (
            <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 className="text-lg font-bold text-slate-950">Registered Student Subscribers ({subscribers.length})</h2>
              <p className="text-xs text-slate-500">Tap on any subscriber to inspect their complete chronological scan history.</p>

              {subscribers.length === 0 ? (
                <p className="mt-6 text-center text-sm text-slate-500 py-8">No subscribers enrolled yet. Have walk-in students scan your Desk Standee QR.</p>
              ) : (
                <div className="mt-5 divide-y divide-slate-100">
                  {subscribers.map((sub) => (
                    <div
                      key={sub.id}
                      onClick={() => openStudentHistory(sub.id, sub.customer_name || 'Student')}
                      className="flex items-center justify-between py-3.5 hover:bg-slate-50 px-3 rounded-xl cursor-pointer transition"
                    >
                      <div className="flex items-center gap-3">
                        <div className="flex h-10 w-10 items-center justify-center rounded-full bg-amber-100 text-amber-900 font-extrabold text-sm">
                          {(sub.customer_name || 'S')[0].toUpperCase()}
                        </div>
                        <div>
                          <p className="text-sm font-bold text-slate-900">{sub.customer_name || 'Member'} · {sub.plan_name}</p>
                          <p className="text-xs text-slate-500">📱 {sub.customer_phone || '—'} · Expiry: {sub.expires_at ? sub.expires_at.split('T')[0] : 'Active'}</p>
                        </div>
                      </div>
                      <div className="text-right">
                        <span className="rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-bold text-emerald-700">
                          {sub.status?.toUpperCase() || 'ACTIVE'}
                        </span>
                        <p className="text-[11px] text-amber-700 font-bold mt-1">View Scans →</p>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* Scan History Modal */}
              {selectedSubHistory && (
                <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/40 p-4 backdrop-blur-sm">
                  <div className="w-full max-w-lg rounded-2xl bg-white p-6 shadow-xl">
                    <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                      <div>
                        <h3 className="font-extrabold text-slate-950">{selectedSubHistory.studentName}&apos;s Scan History</h3>
                        <p className="text-xs text-slate-500">Verified meal redemptions with exact timestamps</p>
                      </div>
                      <button
                        onClick={() => setSelectedSubHistory(null)}
                        className="rounded-lg p-1 text-slate-400 hover:text-slate-900"
                      >
                        ✕
                      </button>
                    </div>
                    <div className="mt-4 max-h-72 overflow-y-auto divide-y divide-slate-100">
                      {selectedSubHistory.history.length === 0 ? (
                        <p className="py-6 text-center text-xs text-slate-500">No scans recorded yet.</p>
                      ) : (
                        selectedSubHistory.history.map((h: any, i: number) => (
                          <div key={i} className="py-2.5 flex justify-between items-center text-xs">
                            <div>
                              <p className="font-bold text-slate-900">{h.slot} Verified</p>
                              <p className="text-slate-500">{h.date} at {h.time_formatted || h.redeemed_at}</p>
                            </div>
                            <span className="rounded-full bg-emerald-100 text-emerald-800 font-bold px-2 py-0.5 text-[10px]">
                              VERIFIED ✓
                            </span>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                </div>
              )}
            </div>
          )}

          {/* TAB 6: COUNTER ORDERS */}
          {activeTab === 'orders' && (
            <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 className="text-lg font-bold text-slate-950">Walk-in Counter Orders Ledger</h2>
              <p className="text-xs text-slate-500">Record cash/UPI single meals, extra rotis and paneer portions sold at the desk.</p>

              <div className="mt-5 grid gap-3 rounded-xl border border-slate-200 bg-slate-50/70 p-4 sm:grid-cols-[1fr_1.5fr_0.8fr_0.8fr_auto]">
                <input
                  type="text"
                  placeholder="Customer name"
                  value={orderCustomer}
                  onChange={(e) => setOrderCustomer(e.target.value)}
                  className="rounded-lg border border-slate-300 px-3 py-2 text-sm bg-white"
                />
                <input
                  type="text"
                  placeholder="Items (e.g. 1x Thali, 1x Paneer)"
                  value={orderItems}
                  onChange={(e) => setOrderItems(e.target.value)}
                  className="rounded-lg border border-slate-300 px-3 py-2 text-sm bg-white"
                />
                <input
                  type="number"
                  placeholder="₹ Amount"
                  value={orderAmount}
                  onChange={(e) => setOrderAmount(e.target.value)}
                  className="rounded-lg border border-slate-300 px-3 py-2 text-sm bg-white"
                />
                <select
                  value={orderMode}
                  onChange={(e) => setOrderMode(e.target.value)}
                  className="rounded-lg border border-slate-300 px-2 py-2 text-sm bg-white"
                >
                  <option value="cash">Cash</option>
                  <option value="counter_upi">UPI</option>
                </select>
                <button
                  type="button"
                  onClick={recordCounterOrder}
                  className="rounded-lg bg-emerald-700 px-4 py-2 text-xs font-bold text-white hover:bg-emerald-800 transition"
                >
                  + Record Sale
                </button>
              </div>

              <div className="mt-6 divide-y divide-slate-100">
                {counterOrders.length === 0 ? (
                  <p className="py-6 text-center text-xs text-slate-500">No counter sales recorded yet.</p>
                ) : (
                  counterOrders.map((ord) => (
                    <div key={ord.id} className="flex justify-between items-center py-3">
                      <div>
                        <p className="text-sm font-bold text-slate-900">{ord.customer_name}</p>
                        <p className="text-xs text-slate-500">{ord.items_summary}</p>
                      </div>
                      <div className="text-right">
                        <p className="text-sm font-extrabold text-slate-900">₹{ord.total_amount_inr}</p>
                        <span className="rounded-full bg-slate-100 text-slate-700 font-bold px-2 py-0.5 text-[10px]">
                          {(ord.payment_mode || 'CASH').toUpperCase()}
                        </span>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          )}

          {/* TAB 7: HELP & SUPPORT DESK */}
          {activeTab === 'support' && (
            <div className="mt-6 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm max-w-xl">
              <h2 className="text-lg font-bold text-slate-950">Partner Help & Support Desk</h2>
              <p className="text-xs text-slate-500">Submit requests directly to support@thali.store.</p>

              {ticketSuccess && (
                <div className="mt-4 rounded-xl border border-emerald-200 bg-emerald-50 p-3 text-xs font-bold text-emerald-900">
                  {ticketSuccess}
                </div>
              )}

              <div className="mt-5 space-y-4">
                <div>
                  <label className="text-xs font-bold text-slate-700">Category</label>
                  <select
                    value={ticketCategory}
                    onChange={(e) => setTicketCategory(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm bg-white"
                  >
                    <option value="general">General Support</option>
                    <option value="billing">Billing & Payouts</option>
                    <option value="menu">Menu Customization</option>
                    <option value="scanner">QR Scanner Assistance</option>
                  </select>
                </div>
                <div>
                  <label className="text-xs font-bold text-slate-700">Subject</label>
                  <input
                    type="text"
                    placeholder="Brief description of the inquiry"
                    value={ticketSubject}
                    onChange={(e) => setTicketSubject(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                  />
                </div>
                <div>
                  <label className="text-xs font-bold text-slate-700">Detailed Message</label>
                  <textarea
                    rows={4}
                    placeholder="Describe what happened or request changes..."
                    value={ticketMessage}
                    onChange={(e) => setTicketMessage(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                  />
                </div>
                <button
                  type="button"
                  onClick={submitSupportDesk}
                  className="rounded-xl bg-amber-500 px-5 py-2.5 text-xs font-bold text-slate-950 hover:bg-amber-600 transition"
                >
                  Send Support Request
                </button>
              </div>
            </div>
          )}
        </div>
      </main>
    );
  }

  // ------------------------------------------------------------------------------------------------
  // RENDER 5-STEP ONBOARDING WIZARD (IF NOT LOGGED IN)
  // ------------------------------------------------------------------------------------------------
  return (
    <main className="min-h-screen bg-[#f7f6f2] px-4 py-12 text-slate-900 sm:px-6 lg:px-10">
      <div className="mx-auto max-w-4xl">
        <Link href="/" className="inline-flex items-center gap-1.5 text-sm font-semibold text-slate-600 hover:text-slate-950">
          <ArrowLeft size={16} /> Back to Thali Home
        </Link>

        {/* Wizard Header */}
        <div className="mt-6">
          <div className="inline-flex items-center gap-2 rounded-full border border-amber-200 bg-amber-50 px-3 py-1 text-xs font-bold text-amber-900">
            <Store size={14} /> KITCHEN PARTNER REGISTRATION WIZARD
          </div>
          <h1 className="mt-3 text-3xl font-black tracking-tight text-slate-950 sm:text-4xl">
            Register Your Real Kitchen on Thali
          </h1>
          <p className="mt-2 text-sm text-slate-600">
            Follow the 5 structured steps to configure your mess details, serving hours, custom menu, and student subscription rates.
          </p>
        </div>

        {/* Stepper Bar - Strictly Validated & Locked */}
        <div className="mt-8 flex items-center justify-between border-b border-slate-200 pb-4">
          {[
            { step: 1, title: 'Basics', isValid: isStep1Valid() },
            { step: 2, title: 'Location', isValid: isStep2Valid() },
            { step: 3, title: 'Schedule', isValid: isStep3Valid() },
            { step: 4, title: 'Menu', isValid: isStep4Valid() },
            { step: 5, title: 'Plans & Publish', isValid: isStep5Valid() },
          ].map((s) => (
            <button
              key={s.step}
              type="button"
              onClick={() => handleStepClick(s.step)}
              className={`flex items-center gap-2 text-xs font-extrabold transition ${
                activeStep === s.step
                  ? 'text-amber-700 font-black'
                  : s.isValid
                  ? 'text-emerald-700'
                  : 'text-slate-400'
              }`}
            >
              <span
                className={`flex h-6 w-6 items-center justify-center rounded-full text-[11px] font-black transition ${
                  s.isValid
                    ? 'bg-emerald-600 text-white'
                    : activeStep === s.step
                    ? 'bg-amber-600 text-white'
                    : 'bg-slate-200 text-slate-600'
                }`}
              >
                {s.isValid ? '✓' : s.step}
              </span>
              <span className="hidden sm:inline">{s.title}</span>
            </button>
          ))}
        </div>

        {error && (
          <div className="mt-6 rounded-xl border border-red-200 bg-red-50 p-4 text-xs font-bold text-red-800">
            {error}
          </div>
        )}

        {/* STEP FORMS */}
        {sessionChecked && !authenticated && <div className="mt-8 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-950"><p>Partner onboarding requires a signed-in Thali account.</p><div className="mt-3 flex gap-3"><Link className="font-bold underline" href="/partner/login">Sign in</Link><Link className="font-bold underline" href="/auth/register">Create account</Link></div></div>}
        <form onSubmit={handleOnboardingSubmit} className="mt-8 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm sm:p-8">
          {/* STEP 1: BASICS */}
          {activeStep === 1 && (
            <div className="space-y-4">
              <h2 className="text-lg font-bold text-slate-950">Step 1: Business details</h2>
              <p className="text-xs text-slate-500">Your existing signed-in account is used for partner access.</p>
              <div className="grid gap-4 sm:grid-cols-2 pt-2">
                <label className="text-xs font-bold text-slate-700">
                  Mess / Business Name *
                  <input
                    type="text"
                    required
                    placeholder="e.g. Radhe Krishna Homely Mess"
                    value={businessName}
                    onChange={(e) => setBusinessName(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                  />
                </label>
                <label className="text-xs font-bold text-slate-700">
                  Contact Phone (10 Digits) *
                  <input
                    type="tel"
                    required
                    placeholder="e.g. 7250171036"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                  />
                </label>
                <label className="text-xs font-bold text-slate-700 sm:col-span-2">
                  Business description
                  <textarea
                    rows={3}
                    maxLength={1000}
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                  />
                </label>
              </div>
              <div className="pt-4 flex justify-end">
                <button
                  type="button"
                  onClick={() => {
                    if (!businessName.trim() || businessName.trim().length < 3) {
                      setError('Please enter a valid mess/business name (at least 3 characters).');
                      return;
                    }
                    const cleanPhone = phone.replace(/\D/g, '');
                    if (cleanPhone.length !== 10) {
                      setError('Please enter a valid 10-digit Indian mobile number.');
                      return;
                    }
                    setError('');
                    setActiveStep(2);
                  }}
                  className="inline-flex items-center gap-2 rounded-xl bg-amber-500 px-6 py-2.5 text-xs font-extrabold text-slate-950 hover:bg-amber-600 transition"
                >
                  Next: Location <ArrowRight size={15} />
                </button>
              </div>
            </div>
          )}

          {/* STEP 2: LOCATION */}
          {activeStep === 2 && (
            <div className="space-y-4">
              <h2 className="text-lg font-bold text-slate-950">Step 2: Kitchen Location & Campus Proximity</h2>
              <p className="text-xs text-slate-500">Students browse messes within 3–4 kms of their hostel.</p>
              <div className="grid gap-4 sm:grid-cols-2 pt-2">
                <label className="text-xs font-bold text-slate-700 sm:col-span-2">
                  Street Address / Hostel Lane *
                  <input
                    type="text"
                    required
                    placeholder="Shop 4, Near Gate 2, Hostel Main Road"
                    value={address}
                    onChange={(e) => setAddress(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                  />
                </label>
                <label className="text-xs font-bold text-slate-700">
                  Area / Campus Hub
                  <input
                    type="text"
                    placeholder="e.g. Sector 62 / Knowledge Park"
                    value={locality}
                    onChange={(e) => setLocality(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                  />
                </label>
                <label className="text-xs font-bold text-slate-700">
                  City *
                  <input
                    type="text"
                    required
                    placeholder="e.g. Noida, Kota, Pune, Delhi"
                    value={city}
                    onChange={(e) => setCity(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                  />
                </label>
                <label className="text-xs font-bold text-slate-700">
                  State *
                  <input
                    type="text"
                    required
                    placeholder="e.g. Uttar Pradesh, Rajasthan, Maharashtra"
                    value={stateName}
                    onChange={(e) => setStateName(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                  />
                </label>
                <label className="text-xs font-bold text-slate-700">
                  PIN Code (6 Digits) *
                  <input
                    type="text"
                    required
                    maxLength={6}
                    placeholder="e.g. 201301"
                    value={pincode}
                    onChange={(e) => setPincode(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm outline-none focus:border-amber-600"
                  />
                </label>
              </div>
              <div className="pt-4 flex justify-between">
                <button
                  type="button"
                  onClick={() => setActiveStep(1)}
                  className="rounded-xl border border-slate-300 px-4 py-2 text-xs font-bold hover:bg-slate-50"
                >
                  Back
                </button>
                <button
                  type="button"
                  onClick={() => {
                    if (!address.trim() || address.trim().length < 5) {
                      setError('Please enter your full street address or hostel road.');
                      return;
                    }
                    if (!city.trim() || city.trim().length < 2) {
                      setError('Please enter your city.');
                      return;
                    }
                    if (!stateName.trim() || stateName.trim().length < 2) {
                      setError('Please enter your state.');
                      return;
                    }
                    const cleanPin = pincode.replace(/\D/g, '');
                    if (cleanPin.length !== 6) {
                      setError('Please enter a valid 6-digit postal PIN code.');
                      return;
                    }
                    setError('');
                    setActiveStep(3);
                  }}
                  className="inline-flex items-center gap-2 rounded-xl bg-amber-500 px-6 py-2.5 text-xs font-extrabold text-slate-950 hover:bg-amber-600 transition"
                >
                  Next: Schedule <ArrowRight size={15} />
                </button>
              </div>
            </div>
          )}

          {/* STEP 3: SCHEDULE */}
          {activeStep === 3 && (
            <div className="space-y-4">
              <h2 className="text-lg font-bold text-slate-950">Step 3: Serving Hours & Schedule</h2>
              <p className="text-xs text-slate-500">Configure serving times for counter QR meal redemptions.</p>
              <div className="grid gap-4 sm:grid-cols-3 pt-2">
                <label className="text-xs font-bold text-slate-700">
                  Breakfast Hours
                  <input
                    type="text"
                    value={bfTime}
                    onChange={(e) => setBfTime(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
                  />
                </label>
                <label className="text-xs font-bold text-slate-700">
                  Lunch Hours *
                  <input
                    type="text"
                    required
                    value={lunchTime}
                    onChange={(e) => setLunchTime(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
                  />
                </label>
                <label className="text-xs font-bold text-slate-700">
                  Dinner Hours *
                  <input
                    type="text"
                    required
                    value={dinnerTime}
                    onChange={(e) => setDinnerTime(e.target.value)}
                    className="mt-1.5 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm"
                  />
                </label>
              </div>
              <div className="pt-4 flex justify-between">
                <button
                  type="button"
                  onClick={() => setActiveStep(2)}
                  className="rounded-xl border border-slate-300 px-4 py-2 text-xs font-bold hover:bg-slate-50"
                >
                  Back
                </button>
                <button
                  type="button"
                  onClick={() => setActiveStep(4)}
                  className="inline-flex items-center gap-2 rounded-xl bg-amber-500 px-6 py-2.5 text-xs font-extrabold text-slate-950 hover:bg-amber-600 transition"
                >
                  Next: Menu <ArrowRight size={15} />
                </button>
              </div>
            </div>
          )}

          {/* STEP 4: MENU - NO FAKE PRE-FILLS */}
          {activeStep === 4 && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-bold text-slate-950">Step 4: Configure Daily Menu & Special Add-ons</h2>
                  <p className="text-xs text-slate-500">You must add at least 1 real dish to your menu before proceeding.</p>
                </div>
                <span className="rounded-full bg-amber-100 px-3 py-1 text-xs font-bold text-amber-900">
                  {dishes.length} {dishes.length === 1 ? 'Dish' : 'Dishes'} Added
                </span>
              </div>

              {dishes.length === 0 ? (
                <div className="rounded-2xl border-2 border-dashed border-slate-200 bg-slate-50/80 p-8 text-center">
                  <Utensils className="mx-auto text-amber-600 mb-2" size={32} />
                  <p className="text-sm font-bold text-slate-800">Your Menu is Currently Empty</p>
                  <p className="text-xs text-slate-500 max-w-md mx-auto mt-1">
                    No pre-filled fake dishes are added. Please use the form below to enter dishes that are included in your standard thali (e.g. Dal Tadka, Roti, Rice) or available as paid extras.
                  </p>
                </div>
              ) : (
                <div className="divide-y divide-slate-100 max-h-60 overflow-y-auto rounded-xl border border-slate-200 bg-white p-3">
                  {dishes.map((d, i) => (
                    <div key={i} className="flex justify-between items-center py-2.5 text-xs">
                      <div className="flex items-center gap-2">
                        <span className={`h-2 w-2 rounded-full ${d.isExtra ? 'bg-amber-500' : 'bg-emerald-500'}`} />
                        <div>
                          <p className="font-bold text-slate-900">{d.name}</p>
                          <p className="text-slate-500 text-[11px]">
                            {d.isExtra ? `Special Paid Extra • ₹${d.price}` : 'Included Standard with Thali'} • Slot: {d.slot.toUpperCase()}
                          </p>
                        </div>
                      </div>
                      <button
                        type="button"
                        onClick={() => removeDish(i)}
                        className="text-red-600 font-bold hover:underline px-2 py-1"
                      >
                        Remove
                      </button>
                    </div>
                  ))}
                </div>
              )}

              {/* Form to add real dish */}
              <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4 space-y-3">
                <p className="text-xs font-bold text-slate-800 uppercase tracking-wide">+ Add New Dish</p>
                <div className="grid gap-3 sm:grid-cols-3">
                  <input
                    type="text"
                    placeholder="Dish Name (e.g. Paneer Butter Masala, Roti)"
                    value={newDishName}
                    onChange={(e) => setNewDishName(e.target.value)}
                    className="sm:col-span-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs outline-none focus:border-amber-600"
                  />
                  <select
                    value={newDishSlot}
                    onChange={(e) => setNewDishSlot(e.target.value)}
                    className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs outline-none"
                  >
                    <option value="lunch">Lunch</option>
                    <option value="dinner">Dinner</option>
                    <option value="breakfast">Breakfast</option>
                  </select>
                </div>
                <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
                  <label className="flex items-center gap-2 text-xs font-medium text-slate-700 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={newDishIsExtra}
                      onChange={(e) => setNewDishIsExtra(e.target.checked)}
                      className="accent-amber-600"
                    />
                    Charge as Paid Extra / Special Add-on
                  </label>
                  {newDishIsExtra && (
                    <div className="flex items-center gap-1.5">
                      <span className="text-xs font-bold text-slate-600">Extra Price (₹):</span>
                      <input
                        type="number"
                        placeholder="e.g. 40"
                        value={newDishPrice}
                        onChange={(e) => setNewDishPrice(e.target.value)}
                        className="w-24 rounded-lg border border-slate-300 bg-white px-2 py-1 text-xs outline-none focus:border-amber-600"
                      />
                    </div>
                  )}
                  <button
                    type="button"
                    onClick={addDish}
                    className="rounded-lg bg-amber-500 px-5 py-2 text-xs font-extrabold text-slate-950 hover:bg-amber-600 transition shadow-sm ml-auto"
                  >
                    + Add Dish to Menu
                  </button>
                </div>
              </div>

              <div className="pt-4 flex justify-between">
                <button
                  type="button"
                  onClick={() => setActiveStep(3)}
                  className="rounded-xl border border-slate-300 px-4 py-2 text-xs font-bold hover:bg-slate-50"
                >
                  Back
                </button>
                <button
                  type="button"
                  onClick={() => {
                    if (dishes.length === 0) {
                      setError('Please add at least one real dish to your menu before proceeding.');
                      return;
                    }
                    setError('');
                    setActiveStep(5);
                  }}
                  className="inline-flex items-center gap-2 rounded-xl bg-amber-500 px-6 py-2.5 text-xs font-extrabold text-slate-950 hover:bg-amber-600 transition"
                >
                  Next: Plans & Pricing <ArrowRight size={15} />
                </button>
              </div>
            </div>
          )}

          {/* STEP 5: PLANS & PUBLISH - NO FAKE PRE-FILLS */}
          {activeStep === 5 && (
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-lg font-bold text-slate-950">Step 5: Custom Subscription Plans & Rates</h2>
                  <p className="text-xs text-slate-500">Configure real pricing for student passes. At least 1 plan required.</p>
                </div>
                <span className="rounded-full bg-emerald-100 px-3 py-1 text-xs font-bold text-emerald-900">
                  {plans.length} {plans.length === 1 ? 'Plan' : 'Plans'} Configured
                </span>
              </div>

              {plans.length === 0 ? (
                <div className="rounded-2xl border-2 border-dashed border-slate-200 bg-slate-50/80 p-8 text-center">
                  <p className="text-sm font-bold text-slate-800">No Subscription Plans Created Yet</p>
                  <p className="text-xs text-slate-500 max-w-md mx-auto mt-1">
                    No fake plans or automatic rates have been added. Use the form below to configure your mess packages (e.g. 30 Days Monthly Unlimited, 15 Days Pass, or Flexi 60 Meals).
                  </p>
                </div>
              ) : (
                <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
                  {plans.map((p, idx) => (
                    <div key={idx} className="rounded-2xl border border-slate-200 bg-white p-4 shadow-sm relative">
                      <div className="flex items-start justify-between">
                        <span className="rounded-md bg-amber-100 px-2 py-0.5 text-[10px] font-extrabold text-amber-900">
                          {p.days} Days Pass
                        </span>
                        <button
                          type="button"
                          onClick={() => removeCustomPlan(idx)}
                          className="text-red-500 hover:text-red-700 font-bold text-xs"
                        >
                          ✕ Remove
                        </button>
                      </div>
                      <h4 className="font-extrabold text-sm text-slate-900 mt-2">{p.name}</h4>
                      <p className="text-xs text-slate-500">
                        {p.type === 'meal_credits' ? `${p.credits || 60} Meal Credits (with Tracker)` : 'Fixed Calendar Unlimited'}
                      </p>
                      <div className="mt-3 pt-2 border-t border-slate-100 flex items-baseline justify-between">
                        <span className="text-lg font-black text-slate-950">₹{p.price}</span>
                        {p.discount ? (
                          <span className="text-[11px] font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded">
                            {p.discount}% Discount
                          </span>
                        ) : null}
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* Form to add custom plan */}
              <div className="rounded-2xl border border-slate-200 bg-slate-50 p-4 space-y-3">
                <p className="text-xs font-bold text-slate-800 uppercase tracking-wide">+ Configure New Custom Plan</p>
                <div className="grid gap-3 sm:grid-cols-2">
                  <div>
                    <label className="text-[11px] font-bold text-slate-600 block mb-1">Plan Name *</label>
                    <input
                      type="text"
                      placeholder="e.g. 30 Days Full Unlimited Pass"
                      value={newPlanName}
                      onChange={(e) => setNewPlanName(e.target.value)}
                      className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs outline-none focus:border-amber-600"
                    />
                  </div>
                  <div>
                    <label className="text-[11px] font-bold text-slate-600 block mb-1">Pass Duration (Days) *</label>
                    <select
                      value={newPlanDays}
                      onChange={(e) => setNewPlanDays(e.target.value)}
                      className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs outline-none"
                    >
                      <option value="15">15 Days (Short Pass)</option>
                      <option value="30">30 Days (Full Monthly)</option>
                      <option value="45">45 Days</option>
                      <option value="60">60 Days (Two Months)</option>
                    </select>
                  </div>
                  <div>
                    <label className="text-[11px] font-bold text-slate-600 block mb-1">Your Price in ₹ *</label>
                    <input
                      type="number"
                      placeholder="e.g. 2800"
                      value={newPlanPrice}
                      onChange={(e) => setNewPlanPrice(e.target.value)}
                      className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs outline-none focus:border-amber-600 font-bold"
                    />
                  </div>
                  <div>
                    <label className="text-[11px] font-bold text-slate-600 block mb-1">Plan Model *</label>
                    <select
                      value={newPlanType}
                      onChange={(e) => setNewPlanType(e.target.value as any)}
                      className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs outline-none"
                    >
                      <option value="fixed_period">Fixed Calendar (Expires strictly in days)</option>
                      <option value="meal_credits">Meal Credits Tracker (Counts actual scans)</option>
                    </select>
                  </div>
                  {newPlanType === 'meal_credits' && (
                    <div>
                      <label className="text-[11px] font-bold text-slate-600 block mb-1">Total Meal Credits</label>
                      <input
                        type="number"
                        placeholder="e.g. 60"
                        value={newPlanCredits}
                        onChange={(e) => setNewPlanCredits(e.target.value)}
                        className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs outline-none"
                      />
                    </div>
                  )}
                  <div>
                    <label className="text-[11px] font-bold text-slate-600 block mb-1">Discount % (Optional)</label>
                    <input
                      type="number"
                      placeholder="e.g. 10 (Optional)"
                      value={newPlanDiscount}
                      onChange={(e) => setNewPlanDiscount(e.target.value)}
                      className="w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-xs outline-none"
                    />
                  </div>
                </div>
                <div className="pt-2 flex justify-end">
                  <button
                    type="button"
                    onClick={addCustomPlan}
                    className="rounded-lg bg-slate-950 px-5 py-2 text-xs font-extrabold text-white hover:bg-slate-800 transition shadow-sm"
                  >
                    + Add Plan to Package
                  </button>
                </div>
              </div>

              <div className="pt-4 border-t border-slate-100">
                <label className="flex items-center gap-2 text-xs font-bold text-slate-700 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={agreedTerms}
                    onChange={(e) => setAgreedTerms(e.target.checked)}
                    className="accent-amber-600"
                  />
                  I confirm that all kitchen details, serving hours, and subscription rates entered above are accurate.
                </label>
              </div>

              <div className="pt-4 flex justify-between">
                <button
                  type="button"
                  onClick={() => setActiveStep(4)}
                  className="rounded-xl border border-slate-300 px-4 py-2 text-xs font-bold hover:bg-slate-50"
                >
                  Back
                </button>
                <button
                  type="submit"
                  disabled={saving}
                  className="inline-flex items-center gap-2 rounded-xl bg-emerald-700 px-7 py-3 text-xs font-extrabold text-white hover:bg-emerald-800 disabled:opacity-60 shadow-md transition"
                >
                  {saving ? 'Publishing Kitchen...' : 'Publish Kitchen & Launch Portal'}
                </button>
              </div>
            </div>
          )}
        </form>
      </div>
    </main>
  );
}
