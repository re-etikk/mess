'use client';

import { useState } from 'react';
import { Check, History, Plus, Receipt, RefreshCw, Search, ShieldCheck, UserPlus, X } from 'lucide-react';
import {
  CounterOrderItem,
  PendingApprovalItem,
  SubscriberItem,
  SubscriptionPlanItem,
  formatInr,
  formatShortDate,
} from './types';

interface ApprovalsAndSubscribersProps {
  mode: 'approvals' | 'subscribers';
  providerId: string;
  pendingApprovals: PendingApprovalItem[];
  subscribers: SubscriberItem[];
  plans: SubscriptionPlanItem[];
  counterOrders: CounterOrderItem[];
  onRefresh: () => Promise<void> | void;
  onNotify: (msg: string, isError?: boolean) => void;
}

export default function PartnerApprovalsAndSubscribersTab({
  mode,
  providerId,
  pendingApprovals,
  subscribers,
  plans,
  counterOrders,
  onRefresh,
  onNotify,
}: ApprovalsAndSubscribersProps) {
  const [busyId, setBusyId] = useState<string | null>(null);
  const [rejectReasonMap, setRejectReasonMap] = useState<Record<string, string>>({});

  // Subscribers filters & modals
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'active' | 'paused' | 'pending_payment' | 'expired'>('ALL');
  const [historySub, setHistorySub] = useState<SubscriberItem | null>(null);
  const [historyRows, setHistoryRows] = useState<any[]>([]);
  const [loadingHistory, setLoadingHistory] = useState(false);

  // Manual walk-in enrollment form
  const [showEnroll, setShowEnroll] = useState(false);
  const [enrollName, setEnrollName] = useState('');
  const [enrollPhone, setEnrollPhone] = useState('');
  const [enrollPlanId, setEnrollPlanId] = useState(plans[0]?.id || '');
  const [enrollAmount, setEnrollAmount] = useState('');
  const [enrollMode, setEnrollMode] = useState<'cash' | 'upi'>('cash');
  const [enrolling, setEnrolling] = useState(false);

  // Walk-in single order form
  const [showCounterOrder, setShowCounterOrder] = useState(false);
  const [orderName, setOrderName] = useState('');
  const [orderPhone, setOrderPhone] = useState('');
  const [orderSlot, setOrderSlot] = useState('LUNCH');
  const [orderSummary, setOrderSummary] = useState('Regular Thali');
  const [orderAmount, setOrderAmount] = useState('80');
  const [orderMode, setOrderMode] = useState<'counter_cash' | 'counter_upi'>('counter_cash');
  const [savingOrder, setSavingOrder] = useState(false);

  async function approvePending(item: PendingApprovalItem) {
    setBusyId(item.id);
    try {
      const res = await fetch('/api/provider/subscriptions/approve', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider_id: providerId, subscription_id: item.id }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not approve pass.', true);
      } else {
        onNotify(`${item.customer_name}'s pass is now Active!`);
        await onRefresh();
      }
    } finally {
      setBusyId(null);
    }
  }

  async function rejectPending(item: PendingApprovalItem) {
    const reason = (rejectReasonMap[item.id] || '').trim() || 'Payment could not be verified at counter.';
    setBusyId(item.id);
    try {
      const res = await fetch('/api/provider/subscriptions/reject', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider_id: providerId, subscription_id: item.id, reason }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not decline pass.', true);
      } else {
        onNotify(`Declined ${item.customer_name}'s request.`);
        await onRefresh();
      }
    } finally {
      setBusyId(null);
    }
  }

  async function openHistory(sub: SubscriberItem) {
    setHistorySub(sub);
    setLoadingHistory(true);
    try {
      const res = await fetch(`/api/provider/subscribers/${sub.id}/history?provider_id=${providerId}`, {
        cache: 'no-store',
      });
      const data = await res.json().catch(() => ({}));
      setHistoryRows(data.history || []);
    } catch {
      setHistoryRows([]);
    } finally {
      setLoadingHistory(false);
    }
  }

  async function handleRenewOrPause(sub: SubscriberItem, action: 'renew' | 'pause') {
    setBusyId(sub.id);
    try {
      const res = await fetch('/api/provider/subscribers/reactivate', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          subscription_id: sub.id,
          action,
          days: 30,
          credits: 30,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not update subscriber pass.', true);
      } else {
        onNotify(data.message || 'Subscriber pass updated.');
        await onRefresh();
      }
    } finally {
      setBusyId(null);
    }
  }

  async function handleManualEnroll(e: React.FormEvent) {
    e.preventDefault();
    if (!enrollName.trim() || enrollPhone.replace(/\D/g, '').length < 10) {
      onNotify('Enter customer name and valid 10-digit mobile number.', true);
      return;
    }
    setEnrolling(true);
    try {
      const res = await fetch('/api/provider/subscribers/manual', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          customer_name: enrollName.trim(),
          customer_phone: enrollPhone.trim(),
          plan_id: enrollPlanId || plans[0]?.id,
          payment_mode: enrollMode,
          amount_paid_inr: enrollAmount ? Number(enrollAmount) : undefined,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not enroll walk-in member.', true);
      } else {
        onNotify(data.message || 'Member enrolled and activated!');
        setEnrollName('');
        setEnrollPhone('');
        setEnrollAmount('');
        setShowEnroll(false);
        await onRefresh();
      }
    } finally {
      setEnrolling(false);
    }
  }

  async function handleLogCounterOrder(e: React.FormEvent) {
    e.preventDefault();
    if (!orderName.trim() || Number(orderAmount) <= 0) {
      onNotify('Enter customer name and valid amount.', true);
      return;
    }
    setSavingOrder(true);
    try {
      const res = await fetch('/api/provider/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          customer_name: orderName.trim(),
          customer_phone: orderPhone.trim(),
          slot: orderSlot,
          items_summary: orderSummary.trim() || 'Counter Meal',
          amount_inr: Number(orderAmount),
          payment_mode: orderMode,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not log walk-in order.', true);
      } else {
        onNotify('Counter walk-in order recorded.');
        setOrderName('');
        setOrderPhone('');
        setShowCounterOrder(false);
        await onRefresh();
      }
    } finally {
      setSavingOrder(false);
    }
  }

  if (mode === 'approvals') {
    return (
      <div className="space-y-4">
        <div className="flex flex-wrap items-center justify-between gap-2 rounded-2xl border border-slate-200 bg-white p-5">
          <div className="flex items-center gap-2">
            <ShieldCheck size={18} className="text-orange-600" />
            <div>
              <h2 className="text-base font-black text-slate-950">Pending Counter Cash &amp; UPI Approvals</h2>
              <p className="text-xs text-slate-500">
                Verify cash or UPI received at the desk before activating a diner&apos;s meal pass.
              </p>
            </div>
          </div>
          <span className="rounded-full bg-amber-50 px-3 py-1 text-xs font-bold text-amber-800">
            {pendingApprovals.length} pending
          </span>
        </div>

        {pendingApprovals.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center text-xs text-slate-500">
            All counter cash &amp; UPI payment requests have been cleared.
          </div>
        ) : (
          <div className="space-y-3">
            {pendingApprovals.map((item) => {
              const amountInr = Math.round((item.price_paise || 0) / 100) || item.price_inr || 0;
              return (
                <article key={item.id} className="rounded-2xl border border-slate-200 bg-white p-5">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <p className="text-sm font-black text-slate-950">{item.customer_name}</p>
                      <p className="mt-0.5 text-xs text-slate-600">
                        {item.customer_phone || 'No phone'} · {item.plan_name} ·{' '}
                        <span className="uppercase font-semibold">{item.payment_mode.replace(/_/g, ' ')}</span>
                      </p>
                      <p className="mt-1 text-[11px] text-slate-400">Requested {formatShortDate(item.created_at)}</p>
                    </div>
                    <p className="text-xl font-black tabular-nums text-amber-900">{formatInr(amountInr)}</p>
                  </div>

                  <div className="mt-4 flex flex-wrap items-center gap-2 border-t border-slate-100 pt-3">
                    <input
                      type="text"
                      value={rejectReasonMap[item.id] || ''}
                      onChange={(e) => setRejectReasonMap((prev) => ({ ...prev, [item.id]: e.target.value }))}
                      placeholder="Optional decline note..."
                      className="flex-1 rounded-xl border border-slate-300 px-3 py-2 text-xs"
                    />
                    <button
                      type="button"
                      disabled={busyId === item.id}
                      onClick={() => rejectPending(item)}
                      className="inline-flex items-center gap-1 rounded-xl border border-red-200 px-3.5 py-2 text-xs font-bold text-red-700 hover:bg-red-50"
                    >
                      <X size={14} /> Decline
                    </button>
                    <button
                      type="button"
                      disabled={busyId === item.id}
                      onClick={() => approvePending(item)}
                      className="inline-flex items-center gap-1 rounded-xl bg-emerald-700 px-4 py-2 text-xs font-bold text-white hover:bg-emerald-800"
                    >
                      <Check size={14} /> Confirm Cash &amp; Activate
                    </button>
                  </div>
                </article>
              );
            })}
          </div>
        )}
      </div>
    );
  }

  // SUBSCRIBERS + WALK-IN COUNTER ORDERS MODE
  const filteredSubs = subscribers.filter((s) => {
    const q = search.trim().toLowerCase();
    const matchSearch =
      !q ||
      s.customer_name.toLowerCase().includes(q) ||
      s.customer_phone.toLowerCase().includes(q) ||
      s.plan_name.toLowerCase().includes(q);
    const matchStatus = statusFilter === 'ALL' || s.status === statusFilter;
    return matchSearch && matchStatus;
  });

  return (
    <div className="space-y-6">
      {/* ACTION HEADER */}
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-4">
        <div className="flex flex-wrap items-center gap-2 flex-1 min-w-[240px]">
          <div className="relative flex-1 max-w-xs">
            <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search name, mobile, plan..."
              className="w-full rounded-xl border border-slate-300 pl-8 pr-3 py-2 text-xs outline-none focus:border-amber-600"
            />
          </div>
          {(['ALL', 'active', 'paused', 'pending_payment'] as const).map((st) => (
            <button
              key={st}
              type="button"
              onClick={() => setStatusFilter(st)}
              className={`rounded-xl px-3 py-1.5 text-xs font-bold ${
                statusFilter === st
                  ? 'bg-slate-900 text-white'
                  : 'border border-slate-200 text-slate-600 hover:bg-slate-50'
              }`}
            >
              {st === 'ALL' ? 'All' : st.replace(/_/g, ' ')}
            </button>
          ))}
        </div>

        <div className="flex flex-wrap gap-2">
          <button
            type="button"
            onClick={() => setShowEnroll((v) => !v)}
            className="inline-flex items-center gap-1.5 rounded-xl bg-orange-600 px-3.5 py-2 text-xs font-bold text-white hover:bg-orange-700"
          >
            <UserPlus size={14} /> Enroll Cash Member
          </button>
          <button
            type="button"
            onClick={() => setShowCounterOrder((v) => !v)}
            className="inline-flex items-center gap-1.5 rounded-xl border border-slate-300 bg-white px-3.5 py-2 text-xs font-bold text-slate-800 hover:bg-slate-50"
          >
            <Receipt size={14} /> Log Single Walk-In Meal
          </button>
        </div>
      </div>

      {/* MANUAL MEMBER ENROLL DRAWER */}
      {showEnroll && (
        <form onSubmit={handleManualEnroll} className="rounded-2xl border border-amber-200 bg-white p-5 space-y-3">
          <h3 className="text-sm font-black text-slate-950">Enroll Walk-In Subscriber (Instant Cash / UPI)</h3>
          <div className="grid gap-3 sm:grid-cols-5">
            <input
              type="text"
              required
              value={enrollName}
              onChange={(e) => setEnrollName(e.target.value)}
              placeholder="Student Full Name"
              className="rounded-xl border border-slate-300 px-3 py-2 text-xs"
            />
            <input
              type="tel"
              required
              value={enrollPhone}
              onChange={(e) => setEnrollPhone(e.target.value)}
              placeholder="10-digit Mobile"
              className="rounded-xl border border-slate-300 px-3 py-2 text-xs font-mono"
            />
            <select
              value={enrollPlanId || plans[0]?.id || ''}
              onChange={(e) => setEnrollPlanId(e.target.value)}
              className="rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs"
            >
              {plans.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name} (₹{p.price_inr})
                </option>
              ))}
            </select>
            <input
              type="number"
              min={1}
              value={enrollAmount}
              onChange={(e) => setEnrollAmount(e.target.value)}
              placeholder="Custom ₹ (optional)"
              className="rounded-xl border border-slate-300 px-3 py-2 text-xs"
            />
            <select
              value={enrollMode}
              onChange={(e) => setEnrollMode(e.target.value as 'cash' | 'upi')}
              className="rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs font-semibold"
            >
              <option value="cash">Counter Cash</option>
              <option value="upi">Counter UPI</option>
            </select>
          </div>
          <div className="flex justify-end gap-2">
            <button type="button" onClick={() => setShowEnroll(false)} className="rounded-xl border border-slate-300 px-3.5 py-2 text-xs font-bold text-slate-600">
              Cancel
            </button>
            <button type="submit" disabled={enrolling} className="rounded-xl bg-slate-900 px-4 py-2 text-xs font-bold text-white hover:bg-slate-800">
              {enrolling ? 'Enrolling...' : 'Activate Member Pass'}
            </button>
          </div>
        </form>
      )}

      {/* LOG SINGLE COUNTER WALK-IN ORDER */}
      {showCounterOrder && (
        <form onSubmit={handleLogCounterOrder} className="rounded-2xl border border-slate-200 bg-white p-5 space-y-3">
          <h3 className="text-sm font-black text-slate-950">Log Single Walk-In Counter Plate</h3>
          <div className="grid gap-3 sm:grid-cols-6">
            <input type="text" required value={orderName} onChange={(e) => setOrderName(e.target.value)} placeholder="Customer Name" className="rounded-xl border border-slate-300 px-3 py-2 text-xs" />
            <input type="tel" value={orderPhone} onChange={(e) => setOrderPhone(e.target.value)} placeholder="Phone (optional)" className="rounded-xl border border-slate-300 px-3 py-2 text-xs" />
            <select value={orderSlot} onChange={(e) => setOrderSlot(e.target.value)} className="rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs">
              <option value="BREAKFAST">Breakfast</option>
              <option value="LUNCH">Lunch</option>
              <option value="SNACKS">Snacks</option>
              <option value="DINNER">Dinner</option>
            </select>
            <input type="text" value={orderSummary} onChange={(e) => setOrderSummary(e.target.value)} placeholder="Items (e.g. 1 Special Thali)" className="rounded-xl border border-slate-300 px-3 py-2 text-xs" />
            <input type="number" min={1} required value={orderAmount} onChange={(e) => setOrderAmount(e.target.value)} placeholder="₹ Amount" className="rounded-xl border border-slate-300 px-3 py-2 text-xs" />
            <select value={orderMode} onChange={(e) => setOrderMode(e.target.value as any)} className="rounded-xl border border-slate-300 bg-white px-3 py-2 text-xs">
              <option value="counter_cash">Cash</option>
              <option value="counter_upi">Counter UPI</option>
            </select>
          </div>
          <div className="flex justify-end gap-2">
            <button type="button" onClick={() => setShowCounterOrder(false)} className="rounded-xl border border-slate-300 px-3.5 py-2 text-xs font-bold text-slate-600">
              Cancel
            </button>
            <button type="submit" disabled={savingOrder} className="inline-flex items-center gap-1 rounded-xl bg-orange-600 px-4 py-2 text-xs font-bold text-white hover:bg-orange-700">
              <Plus size={14} /> {savingOrder ? 'Saving...' : 'Save Order'}
            </button>
          </div>
        </form>
      )}

      {/* SUBSCRIBERS LIST */}
      <div className="space-y-2.5">
        {filteredSubs.length === 0 ? (
          <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center text-xs text-slate-500">
            No matching subscribers found.
          </div>
        ) : (
          filteredSubs.map((sub) => (
            <article key={sub.id} className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-4">
              <div>
                <div className="flex items-center gap-2">
                  <p className="text-sm font-bold text-slate-950">{sub.customer_name}</p>
                  <span
                    className={`rounded-full px-2 py-0.5 text-[10px] font-bold uppercase ${
                      sub.status === 'active'
                        ? 'bg-emerald-50 text-emerald-800'
                        : sub.status === 'paused'
                        ? 'bg-amber-50 text-amber-800'
                        : 'bg-slate-100 text-slate-600'
                    }`}
                  >
                    {sub.status}
                  </span>
                </div>
                <p className="mt-0.5 text-xs text-slate-500">
                  {sub.plan_name} · {sub.customer_phone || 'No phone'}
                  {sub.expires_at ? ` · Valid until ${formatShortDate(sub.expires_at)}` : ''}
                  {sub.plan_type === 'meal_credits' ? ` · ${sub.remaining_meal_credits ?? 0} credits left` : ''}
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <button
                  type="button"
                  onClick={() => openHistory(sub)}
                  className="inline-flex items-center gap-1 rounded-xl border border-slate-200 px-3 py-1.5 text-xs font-bold text-slate-700 hover:bg-slate-50"
                >
                  <History size={13} /> Scan History
                </button>
                {sub.status === 'active' ? (
                  <button
                    type="button"
                    disabled={busyId === sub.id}
                    onClick={() => handleRenewOrPause(sub, 'pause')}
                    className="rounded-xl border border-amber-200 bg-amber-50 px-3 py-1.5 text-xs font-bold text-amber-900 hover:bg-amber-100"
                  >
                    Pause
                  </button>
                ) : (
                  <button
                    type="button"
                    disabled={busyId === sub.id}
                    onClick={() => handleRenewOrPause(sub, 'renew')}
                    className="inline-flex items-center gap-1 rounded-xl bg-slate-900 px-3 py-1.5 text-xs font-bold text-white hover:bg-slate-800"
                  >
                    <RefreshCw size={12} /> Renew +30d
                  </button>
                )}
              </div>
            </article>
          ))
        )}
      </div>

      {/* SCAN HISTORY INLINE PANEL */}
      {historySub && (
        <div className="rounded-2xl border border-slate-200 bg-white p-5 space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-black text-slate-950">Meal Scan History · {historySub.customer_name}</h3>
            <button type="button" onClick={() => setHistorySub(null)} className="text-xs font-bold text-slate-500 hover:text-slate-900">
              Close
            </button>
          </div>
          {loadingHistory ? (
            <p className="text-xs text-slate-500">Loading scans...</p>
          ) : historyRows.length === 0 ? (
            <p className="text-xs text-slate-500">No meal scans recorded yet for this subscriber.</p>
          ) : (
            <ul className="divide-y divide-slate-100 text-xs">
              {historyRows.map((h) => (
                <li key={h.id} className="flex items-center justify-between py-2">
                  <span className="font-semibold text-slate-800">
                    {h.slot} · {h.confirmation_method || 'qr_scan'}
                  </span>
                  <span className="font-mono text-slate-500">
                    {h.date} {h.time_formatted}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </div>
      )}

      {/* COUNTER WALK-IN ORDERS LOG */}
      <div className="rounded-2xl border border-slate-200 bg-white p-5 space-y-3">
        <h3 className="text-sm font-black text-slate-950">Daily Walk-In Counter Orders ({counterOrders.length})</h3>
        {counterOrders.length === 0 ? (
          <p className="text-xs text-slate-500">No walk-in single meals logged yet today.</p>
        ) : (
          <ul className="divide-y divide-slate-100 text-xs">
            {counterOrders.slice(0, 15).map((o) => (
              <li key={o.id} className="flex flex-wrap items-center justify-between gap-2 py-2.5">
                <div>
                  <p className="font-bold text-slate-900">{o.customer_name}</p>
                  <p className="text-slate-500">
                    {o.slot} · {o.items_summary} · {o.payment_mode.replace(/_/g, ' ')}
                  </p>
                </div>
                <span className="font-bold tabular-nums text-slate-950">{formatInr(o.amount_inr)}</span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}
