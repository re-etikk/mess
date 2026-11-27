'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import QRCode from 'qrcode';
import { Copy, CreditCard, Download, Edit3, ExternalLink, Eye, EyeOff, Plus, QrCode, RefreshCw, Trash2 } from 'lucide-react';
import { MealSlotConfig, SubscriptionPlanItem, formatInr } from './types';

interface PlansAndQrProps {
  providerId: string;
  businessName: string;
  plans: SubscriptionPlanItem[];
  mealSlots: MealSlotConfig[];
  onRefresh: () => Promise<void> | void;
  onNotify: (msg: string, isError?: boolean) => void;
}

export default function PartnerPlansAndQrTab({
  providerId,
  businessName,
  plans,
  mealSlots,
  onRefresh,
  onNotify,
}: PlansAndQrProps) {
  const [editingPlanId, setEditingPlanId] = useState<string | null>(null);
  const [planName, setPlanName] = useState('');
  const [planDesc, setPlanDesc] = useState('');
  const [planType, setPlanType] = useState<'fixed_period' | 'meal_credits' | 'daily'>('fixed_period');
  const [durationDays, setDurationDays] = useState('30');
  const [mealCredits, setMealCredits] = useState('30');
  const [priceInr, setPriceInr] = useState('3000');
  const [discountPercent, setDiscountPercent] = useState('0');
  const [published, setPublished] = useState(true);
  const [selectedSlotIds, setSelectedSlotIds] = useState<string[]>(() => mealSlots.filter((s) => s.active).map((s) => s.id));
  const [savingPlan, setSavingPlan] = useState(false);

  // Daily QR state
  const [qrSlot, setQrSlot] = useState<'BREAKFAST' | 'LUNCH' | 'SNACKS' | 'DINNER'>('LUNCH');
  const [qrToken, setQrToken] = useState('');
  const [qrDataUrl, setQrDataUrl] = useState('');
  const [qrLoading, setQrLoading] = useState(false);

  async function refreshQr(slotName: string) {
    setQrLoading(true);
    try {
      const res = await fetch(`/api/provider/qr/generate?provider_id=${providerId}&slot=${slotName}`, {
        cache: 'no-store',
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok && data.token) {
        setQrToken(data.token);
        const pngUrl = await QRCode.toDataURL(data.token, { width: 320, margin: 2 });
        setQrDataUrl(pngUrl);
      }
    } finally {
      setQrLoading(false);
    }
  }

  useEffect(() => {
    if (providerId) void refreshQr(qrSlot);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [providerId, qrSlot]);

  function startEditPlan(p: SubscriptionPlanItem) {
    setEditingPlanId(p.id);
    setPlanName(p.name);
    setPlanDesc(p.description || '');
    setPlanType((p.plan_type as any) || 'fixed_period');
    setDurationDays(String(p.duration_days || 30));
    setMealCredits(String(p.meal_credits || 30));
    setPriceInr(String(p.price_inr || 0));
    setDiscountPercent(String(p.discount_percent || 0));
    setPublished(p.published !== false);
  }

  function resetPlanForm() {
    setEditingPlanId(null);
    setPlanName('');
    setPlanDesc('');
    setPlanType('fixed_period');
    setDurationDays('30');
    setMealCredits('30');
    setPriceInr('3000');
    setDiscountPercent('0');
    setPublished(true);
  }

  async function handleSavePlan(e: React.FormEvent) {
    e.preventDefault();
    if (!planName.trim() || Number(priceInr) <= 0) {
      onNotify('Enter a valid plan name and price in INR.', true);
      return;
    }
    setSavingPlan(true);
    try {
      const res = await fetch('/api/provider/plans', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          id: editingPlanId || undefined,
          name: planName.trim(),
          description: planDesc.trim(),
          plan_type: planType,
          duration_days: Math.max(1, Number(durationDays) || 30),
          meal_credits: planType === 'meal_credits' ? Math.max(1, Number(mealCredits) || 30) : undefined,
          price_inr: Number(priceInr),
          discount_percent: Number(discountPercent) > 0 ? Number(discountPercent) : undefined,
          meal_slot_ids: selectedSlotIds,
          published,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not save subscription plan.', true);
      } else {
        onNotify(editingPlanId ? 'Subscription plan updated.' : 'Subscription plan created and synced!');
        resetPlanForm();
        await onRefresh();
      }
    } catch {
      onNotify('Network error saving subscription plan.', true);
    } finally {
      setSavingPlan(false);
    }
  }

  async function togglePublished(p: SubscriptionPlanItem) {
    const res = await fetch('/api/provider/plans', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        provider_id: providerId,
        id: p.id,
        name: p.name,
        description: p.description || '',
        plan_type: p.plan_type,
        duration_days: p.duration_days || 30,
        meal_credits: p.meal_credits ?? undefined,
        price_inr: p.price_inr,
        discount_percent: p.discount_percent ?? undefined,
        published: !p.published,
      }),
    });
    if (res.ok) {
      onNotify(`${p.name} is now ${!p.published ? 'Live for diners' : 'Unlisted'}.`);
      await onRefresh();
    }
  }

  async function handleDeletePlan(p: SubscriptionPlanItem) {
    const res = await fetch(`/api/provider/plans?provider_id=${providerId}&plan_id=${p.id}`, {
      method: 'DELETE',
    });
    const data = await res.json().catch(() => ({}));
    if (res.ok && data.success) {
      onNotify(data.message || 'Plan removed.');
      await onRefresh();
    } else {
      onNotify(data.error || 'Could not remove plan.', true);
    }
  }

  return (
    <div className="grid gap-6 lg:grid-cols-12">
      {/* SUBSCRIPTION PLANS MANAGER */}
      <div className="lg:col-span-7 space-y-5">
        <form onSubmit={handleSavePlan} className="rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <CreditCard size={18} className="text-orange-600" />
              <h2 className="text-base font-black text-slate-950">
                {editingPlanId ? 'Edit Subscription Plan' : 'Create Subscription Plan'}
              </h2>
            </div>
            {editingPlanId && (
              <button
                type="button"
                onClick={resetPlanForm}
                className="text-xs font-bold text-slate-500 hover:text-slate-900"
              >
                Cancel Edit
              </button>
            )}
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <input
              type="text"
              required
              value={planName}
              onChange={(e) => setPlanName(e.target.value)}
              placeholder="Plan Title (e.g. Monthly 2-Meal Pass)"
              className="rounded-xl border border-slate-300 px-3 py-2 text-xs outline-none focus:border-amber-600"
            />
            <select
              value={planType}
              onChange={(e) => setPlanType(e.target.value as any)}
              className="rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs font-semibold"
            >
              <option value="fixed_period">Fixed Duration Pass</option>
              <option value="meal_credits">Flex Meal Credits Pass</option>
              <option value="daily">Daily Trial Pass</option>
            </select>
            <input
              type="number"
              min={1}
              required
              value={priceInr}
              onChange={(e) => setPriceInr(e.target.value)}
              placeholder="Price in ₹"
              className="rounded-xl border border-slate-300 px-3 py-2 text-xs font-bold"
            />
            <div className="grid grid-cols-2 gap-2">
              <input
                type="number"
                min={1}
                value={durationDays}
                onChange={(e) => setDurationDays(e.target.value)}
                placeholder="Days (e.g. 30)"
                className="rounded-xl border border-slate-300 px-3 py-2 text-xs"
              />
              {planType === 'meal_credits' ? (
                <input
                  type="number"
                  min={1}
                  value={mealCredits}
                  onChange={(e) => setMealCredits(e.target.value)}
                  placeholder="Meals count"
                  className="rounded-xl border border-slate-300 px-3 py-2 text-xs"
                />
              ) : (
                <input
                  type="number"
                  min={0}
                  max={80}
                  value={discountPercent}
                  onChange={(e) => setDiscountPercent(e.target.value)}
                  placeholder="Discount %"
                  className="rounded-xl border border-slate-300 px-3 py-2 text-xs"
                />
              )}
            </div>
            <input
              type="text"
              value={planDesc}
              onChange={(e) => setPlanDesc(e.target.value)}
              placeholder="Short description shown to students..."
              className="sm:col-span-2 rounded-xl border border-slate-300 px-3 py-2 text-xs outline-none focus:border-amber-600"
            />
          </div>

          {mealSlots.length > 0 && (
            <div className="flex flex-wrap items-center gap-2 text-xs">
              <span className="font-bold text-slate-600">Eligible Slots:</span>
              {mealSlots.map((s) => (
                <label key={s.id} className="inline-flex cursor-pointer items-center gap-1 rounded-lg border border-slate-200 px-2.5 py-1 capitalize">
                  <input
                    type="checkbox"
                    checked={selectedSlotIds.includes(s.id)}
                    onChange={(e) =>
                      setSelectedSlotIds((prev) =>
                        e.target.checked ? [...prev, s.id] : prev.filter((id) => id !== s.id)
                      )
                    }
                    className="h-3.5 w-3.5 accent-amber-600"
                  />
                  {s.name}
                </label>
              ))}
            </div>
          )}

          <div className="flex flex-wrap items-center justify-between gap-3 pt-1">
            <label className="inline-flex cursor-pointer items-center gap-2 text-xs font-semibold text-slate-700">
              <input
                type="checkbox"
                checked={published}
                onChange={(e) => setPublished(e.target.checked)}
                className="h-4 w-4 accent-amber-600"
              />
              Published &amp; Visible to Diners
            </label>
            <button
              type="submit"
              disabled={savingPlan}
              className="inline-flex items-center gap-1.5 rounded-xl bg-orange-600 px-4 py-2 text-xs font-bold text-white hover:bg-orange-700 disabled:bg-slate-400"
            >
              <Plus size={14} /> {savingPlan ? 'Saving...' : editingPlanId ? 'Update Plan' : 'Publish Plan'}
            </button>
          </div>
        </form>

        {/* Active & Unlisted Plans */}
        <div className="space-y-2.5">
          {plans.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-6 text-center text-xs text-slate-500">
              No subscription plans published yet. Create your weekly or monthly pass above.
            </div>
          ) : (
            plans.map((p) => (
              <div key={p.id} className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-4">
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-bold text-slate-950">{p.name}</p>
                    <span
                      className={`rounded-full px-2 py-0.5 text-[10px] font-bold uppercase ${
                        p.published !== false ? 'bg-emerald-50 text-emerald-800' : 'bg-slate-100 text-slate-600'
                      }`}
                    >
                      {p.published !== false ? 'Live' : 'Unlisted'}
                    </span>
                  </div>
                  <p className="mt-0.5 text-xs text-slate-500">
                    {formatInr(p.price_inr)} · {p.duration_days} days
                    {p.plan_type === 'meal_credits' && p.meal_credits ? ` · ${p.meal_credits} meal credits` : ''}
                    {p.discount_percent ? ` · ${p.discount_percent}% off` : ''}
                  </p>
                </div>
                <div className="flex items-center gap-1.5">
                  <button
                    type="button"
                    onClick={() => togglePublished(p)}
                    title={p.published !== false ? 'Unlist plan' : 'Publish plan'}
                    className="rounded-lg border border-slate-200 p-1.5 text-slate-600 hover:bg-slate-50"
                  >
                    {p.published !== false ? <Eye size={14} /> : <EyeOff size={14} />}
                  </button>
                  <button
                    type="button"
                    onClick={() => startEditPlan(p)}
                    title="Edit plan"
                    className="rounded-lg border border-slate-200 p-1.5 text-slate-600 hover:bg-slate-50"
                  >
                    <Edit3 size={14} />
                  </button>
                  <button
                    type="button"
                    onClick={() => handleDeletePlan(p)}
                    title="Delete or archive plan"
                    className="rounded-lg border border-red-200 p-1.5 text-red-600 hover:bg-red-50"
                  >
                    <Trash2 size={14} />
                  </button>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* DAILY CHECK-IN QR + COUNTER STANDEE */}
      <div className="lg:col-span-5">
        <div className="rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <QrCode size={18} className="text-orange-600" />
              <h2 className="text-base font-black text-slate-950">Daily Counter QR</h2>
            </div>
            <Link
              href={`/provider/standee?provider_id=${providerId}`}
              className="inline-flex items-center gap-1 text-xs font-bold text-orange-600 hover:text-orange-700"
            >
              Print Standee <ExternalLink size={12} />
            </Link>
          </div>

          <div className="grid grid-cols-4 gap-1.5">
            {(['BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER'] as const).map((slotName) => (
              <button
                key={slotName}
                type="button"
                onClick={() => setQrSlot(slotName)}
                className={`rounded-lg py-2 text-[11px] font-bold transition ${
                  qrSlot === slotName
                    ? 'bg-orange-600 text-white'
                    : 'border border-slate-200 text-slate-600 hover:bg-slate-50'
                }`}
              >
                {slotName.slice(0, 1) + slotName.slice(1).toLowerCase()}
              </button>
            ))}
          </div>

          <div className="flex flex-col items-center rounded-xl border border-slate-200 bg-slate-50 p-6">
            <p className="text-sm font-black text-slate-950">{businessName}</p>
            <p className="mt-0.5 text-xs font-bold text-orange-700">{qrSlot} Attendance QR</p>
            {qrLoading ? (
              <p className="py-20 text-xs text-slate-500">Generating encrypted QR...</p>
            ) : qrDataUrl ? (
              <img src={qrDataUrl} alt={`${qrSlot} Counter QR`} className="mt-4 h-56 w-56 rounded-xl bg-white p-2 shadow-sm" />
            ) : (
              <p className="py-20 text-xs text-slate-500">Unavailable</p>
            )}
          </div>

          <div className="grid grid-cols-3 gap-2">
            <button
              type="button"
              onClick={() => refreshQr(qrSlot)}
              className="inline-flex items-center justify-center gap-1 rounded-xl border border-slate-300 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50"
            >
              <RefreshCw size={13} /> Refresh
            </button>
            <button
              type="button"
              disabled={!qrToken}
              onClick={() => {
                void navigator.clipboard.writeText(qrToken);
                onNotify('Counter QR token copied.');
              }}
              className="inline-flex items-center justify-center gap-1 rounded-xl border border-slate-300 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50"
            >
              <Copy size={13} /> Copy
            </button>
            <a
              href={qrDataUrl || '#'}
              download={`${businessName.toLowerCase().replace(/\s+/g, '-')}-${qrSlot.toLowerCase()}-qr.png`}
              className="inline-flex items-center justify-center gap-1 rounded-xl bg-slate-900 py-2 text-xs font-bold text-white hover:bg-slate-800"
            >
              <Download size={13} /> PNG
            </a>
          </div>
        </div>
      </div>
    </div>
  );
}
