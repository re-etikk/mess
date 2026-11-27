'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import QRCode from 'qrcode';
import {
  AlertTriangle,
  Brain,
  Check,
  ChefHat,
  Clock,
  Copy,
  ExternalLink,
  RefreshCw,
  ScanLine,
  Truck,
  Users,
  Wallet,
} from 'lucide-react';
import {
  DeliveryRider,
  KitchenForecast,
  KitchenQueueItem,
  PartnerMetrics,
  formatInr,
} from './types';

interface OverviewAndQueueProps {
  mode: 'overview' | 'queue';
  providerId: string;
  businessName: string;
  isOpenToday: boolean;
  onToggleOpen: () => void;
  togglingStatus: boolean;
  metrics: PartnerMetrics | null;
  forecast: KitchenForecast | null;
  recentRedemptions: any[];
  queueItems: KitchenQueueItem[];
  riders: DeliveryRider[];
  queueDate: string;
  queueSlot: string;
  onQueueFilterChange: (nextDate: string, nextSlot: string) => void;
  onRefresh: () => void;
  onNotify: (msg: string, isError?: boolean) => void;
}

const QUEUE_STATUS_OPTIONS = [
  { value: 'scheduled', label: 'Scheduled' },
  { value: 'preparing', label: 'Preparing' },
  { value: 'ready_at_counter', label: 'Ready at Counter' },
  { value: 'out_for_delivery', label: 'Out for Delivery' },
  { value: 'delivered', label: 'Delivered / Served' },
  { value: 'cancelled_by_kitchen', label: 'Cancelled' },
];

export default function PartnerOverviewAndQueueTab({
  mode,
  providerId,
  businessName,
  isOpenToday,
  onToggleOpen,
  togglingStatus,
  metrics,
  forecast,
  recentRedemptions,
  queueItems,
  riders,
  queueDate,
  queueSlot,
  onQueueFilterChange,
  onRefresh,
  onNotify,
}: OverviewAndQueueProps) {
  const [qrSlot, setQrSlot] = useState<'BREAKFAST' | 'LUNCH' | 'SNACKS' | 'DINNER'>('LUNCH');
  const [qrToken, setQrToken] = useState('');
  const [qrDataUrl, setQrDataUrl] = useState('');
  const [qrBusy, setQrBusy] = useState(false);

  const [busySubId, setBusySubId] = useState<string | null>(null);
  const [etaDrafts, setEtaDrafts] = useState<Record<string, string>>({});

  async function loadQuickQr(slotToFetch: string) {
    setQrBusy(true);
    try {
      const res = await fetch(`/api/provider/qr/generate?provider_id=${providerId}&slot=${slotToFetch}`, {
        cache: 'no-store',
      });
      const data = await res.json().catch(() => ({}));
      if (res.ok && data.token) {
        setQrToken(data.token);
        const imgUrl = await QRCode.toDataURL(data.token, { width: 220, margin: 1 });
        setQrDataUrl(imgUrl);
      }
    } catch {
    } finally {
      setQrBusy(false);
    }
  }

  useEffect(() => {
    if (mode === 'overview' && providerId) {
      void loadQuickQr(qrSlot);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, providerId, qrSlot]);

  async function updateQueueStatus(item: KitchenQueueItem, nextStatus: string) {
    setBusySubId(item.subscription_id);
    try {
      const etaNum = etaDrafts[item.subscription_id] ? Number(etaDrafts[item.subscription_id]) : item.eta_minutes;
      const res = await fetch('/api/provider/kitchen-queue', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          subscription_id: item.subscription_id,
          customer_id: item.customer_id,
          service_date: queueDate,
          slot: item.slot || (queueSlot === 'ALL' ? 'LUNCH' : queueSlot),
          status: nextStatus,
          eta_minutes: etaNum && Number.isFinite(etaNum) ? etaNum : undefined,
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not update meal status.', true);
      } else {
        onNotify(`${item.customer_name} marked ${nextStatus.replace(/_/g, ' ')}.`);
        onRefresh();
      }
    } catch {
      onNotify('Network error updating kitchen queue.', true);
    } finally {
      setBusySubId(null);
    }
  }

  async function assignRider(item: KitchenQueueItem, riderId: string) {
    if (!riderId) return;
    setBusySubId(item.subscription_id);
    try {
      const res = await fetch('/api/delivery/riders', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: providerId,
          rider_id: riderId,
          subscription_id: item.subscription_id,
          customer_id: item.customer_id,
          service_date: queueDate,
          slot: item.slot || (queueSlot === 'ALL' ? 'LUNCH' : queueSlot),
        }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok || !data.success) {
        onNotify(data.error || 'Could not assign rider.', true);
      } else {
        onNotify(`Assigned ${data.rider_name || 'rider'} to ${item.customer_name}.`);
        onRefresh();
      }
    } catch {
      onNotify('Network error assigning rider.', true);
    } finally {
      setBusySubId(null);
    }
  }

  if (mode === 'overview') {
    return (
      <div className="space-y-6">
        {/* TOP METRICS STRIP */}
        <section className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-2xl border border-slate-200 bg-white p-5">
            <div className="flex items-center justify-between text-xs font-bold text-slate-500">
              <span>Today&apos;s Scans</span>
              <ScanLine size={16} className="text-orange-600" />
            </div>
            <p className="mt-2 text-3xl font-black tabular-nums text-slate-950">
              {metrics?.today_scans_count ?? 0}
            </p>
            <p className="mt-1 text-xs text-slate-500">{metrics?.total_scans ?? 0} total check-ins</p>
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-5">
            <div className="flex items-center justify-between text-xs font-bold text-slate-500">
              <span>Active Subscribers</span>
              <Users size={16} className="text-emerald-700" />
            </div>
            <p className="mt-2 text-3xl font-black tabular-nums text-slate-950">
              {metrics?.active_subscribers ?? 0}
            </p>
            <p className="mt-1 text-xs text-slate-500">{metrics?.active_plans_count ?? 0} active plans</p>
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-5">
            <div className="flex items-center justify-between text-xs font-bold text-slate-500">
              <span>Pending Counter Cash</span>
              <Clock size={16} className="text-amber-700" />
            </div>
            <p className="mt-2 text-3xl font-black tabular-nums text-slate-950">
              {formatInr(metrics?.pending_cash_inr ?? 0)}
            </p>
            <p className="mt-1 text-xs text-slate-500">
              {metrics?.pending_cash_count ?? 0} passes awaiting counter check
            </p>
          </div>

          <div className="rounded-2xl border border-slate-200 bg-white p-5">
            <div className="flex items-center justify-between text-xs font-bold text-slate-500">
              <span>Online Settled</span>
              <Wallet size={16} className="text-slate-700" />
            </div>
            <p className="mt-2 text-3xl font-black tabular-nums text-slate-950">
              {formatInr(metrics?.online_settled_inr ?? 0)}
            </p>
            <p className="mt-1 text-xs text-slate-500">
              {metrics?.average_rating ? `Rating ${metrics.average_rating}/5 (${metrics.reviews_count})` : 'No ratings yet'}
            </p>
          </div>
        </section>

        {/* KITCHEN AVAILABILITY & LIVE QR PANEL */}
        <section className="grid gap-5 lg:grid-cols-12">
          <div className="lg:col-span-7 space-y-5">
            <div className="rounded-2xl border border-slate-200 bg-white p-5">
              <div className="flex flex-wrap items-center justify-between gap-4">
                <div>
                  <div className="flex items-center gap-2">
                    <span
                      className={`h-2.5 w-2.5 rounded-full ${isOpenToday ? 'bg-emerald-500' : 'bg-slate-900'}`}
                    />
                    <h2 className="text-base font-black text-slate-950">
                      {businessName} is {isOpenToday ? 'Open & Serving Today' : 'Closed / Off Today'}
                    </h2>
                  </div>
                  <p className="mt-1 text-xs text-slate-500">
                    When turned Off, diners see a darkened closed card and Open Now filters hide your kitchen.
                  </p>
                </div>
                <button
                  type="button"
                  disabled={togglingStatus}
                  onClick={onToggleOpen}
                  className={`min-h-10 rounded-xl px-4 text-xs font-bold transition ${
                    isOpenToday
                      ? 'border border-red-200 bg-red-50 text-red-700 hover:bg-red-100'
                      : 'bg-emerald-700 text-white hover:bg-emerald-800'
                  }`}
                >
                  {togglingStatus ? 'Updating...' : isOpenToday ? 'Mark Closed Today' : 'Mark Open Today'}
                </button>
              </div>
            </div>

            {/* AI DEMAND & PREP FORECAST */}
            <div className="rounded-2xl border border-slate-200 bg-white p-5">
              <div className="flex items-center justify-between gap-3">
                <div className="flex items-center gap-2">
                  <Brain size={18} className="text-orange-600" />
                  <h2 className="text-base font-black text-slate-950">AI Kitchen Prep Forecast</h2>
                </div>
                {forecast?.waste_saved_inr ? (
                  <span className="rounded-full bg-emerald-50 px-2.5 py-1 text-[11px] font-bold text-emerald-800">
                    ~{formatInr(forecast.waste_saved_inr)} est. waste saved
                  </span>
                ) : null}
              </div>

              {forecast?.slots && forecast.slots.length > 0 ? (
                <div className="mt-4 grid gap-2.5 sm:grid-cols-2">
                  {forecast.slots.map((s) => (
                    <div key={s.slot} className="rounded-xl border border-slate-100 bg-slate-50/70 p-3.5">
                      <div className="flex items-center justify-between">
                        <span className="text-xs font-extrabold uppercase text-slate-700">{s.slot}</span>
                        <span className="text-lg font-black tabular-nums text-slate-950">
                          {s.expected_diners} thalis
                        </span>
                      </div>
                      <p className="mt-1 text-[11px] text-slate-500">
                        Dine-in: {s.dine_in_count} · Delivery: {s.delivery_count} · 4-wk avg: {s.avg_last_4_weeks}
                      </p>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="mt-3 text-xs text-slate-500">
                  Forecast builds automatically as subscribers redeem breakfast, lunch, snacks, and dinner meals.
                </p>
              )}

              {forecast?.churn_alerts && forecast.churn_alerts.length > 0 && (
                <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50/70 p-3.5">
                  <p className="flex items-center gap-1.5 text-xs font-bold text-amber-950">
                    <AlertTriangle size={14} className="text-amber-700" />
                    Re-engagement Watchlist ({forecast.churn_alerts.length})
                  </p>
                  <ul className="mt-2 space-y-1 text-xs text-amber-900">
                    {forecast.churn_alerts.slice(0, 4).map((alert) => (
                      <li key={alert.customer_id} className="flex justify-between gap-2">
                        <span className="font-semibold">{alert.customer_name}</span>
                        <span className="text-amber-700">{alert.reason || `${alert.days_absent ?? 5}+ days absent`}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              )}
            </div>

            {/* RECENT CHECK-INS */}
            <div className="rounded-2xl border border-slate-200 bg-white p-5">
              <h2 className="text-base font-black text-slate-950">Recent Check-Ins</h2>
              {recentRedemptions.length === 0 ? (
                <p className="mt-3 text-xs text-slate-500">
                  No QR scans recorded today yet. Display the counter QR for members to scan.
                </p>
              ) : (
                <ul className="mt-3 divide-y divide-slate-100">
                  {recentRedemptions.slice(0, 8).map((r: any) => (
                    <li key={r.id} className="flex items-center justify-between gap-2 py-2.5 text-xs">
                      <div>
                        <p className="font-bold text-slate-900">{r.customer_name || 'Subscriber'}</p>
                        <p className="text-slate-500">
                          {r.slot} · {r.confirmation_method || 'qr_scan'}
                        </p>
                      </div>
                      <time className="font-mono text-slate-500">
                        {r.redeemed_at
                          ? new Date(r.redeemed_at).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
                          : r.date}
                      </time>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>

          {/* LIVE COUNTER QR COLUMN */}
          <div className="lg:col-span-5">
            <div className="rounded-2xl border border-slate-200 bg-white p-5 space-y-4">
              <div className="flex items-center justify-between">
                <h2 className="text-base font-black text-slate-950">Counter Meal QR</h2>
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
                    className={`rounded-lg py-1.5 text-[11px] font-bold transition ${
                      qrSlot === slotName
                        ? 'bg-slate-900 text-white'
                        : 'border border-slate-200 text-slate-600 hover:bg-slate-50'
                    }`}
                  >
                    {slotName.slice(0, 1) + slotName.slice(1).toLowerCase()}
                  </button>
                ))}
              </div>
              <div className="flex flex-col items-center rounded-xl border border-slate-100 bg-slate-50 p-5">
                {qrBusy ? (
                  <p className="py-16 text-xs text-slate-500">Refreshing Counter QR...</p>
                ) : qrDataUrl ? (
                  <img src={qrDataUrl} alt={`${qrSlot} Check-In QR`} className="h-48 w-48 rounded-lg bg-white p-2 shadow-sm" />
                ) : (
                  <p className="py-16 text-xs text-slate-500">QR token unavailable right now.</p>
                )}
                <p className="mt-2 text-[11px] font-semibold text-slate-600">Active Slot: {qrSlot}</p>
              </div>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => loadQuickQr(qrSlot)}
                  className="inline-flex flex-1 items-center justify-center gap-1.5 rounded-xl border border-slate-300 py-2 text-xs font-bold text-slate-700 hover:bg-slate-50"
                >
                  <RefreshCw size={13} /> Refresh
                </button>
                <button
                  type="button"
                  disabled={!qrToken}
                  onClick={() => {
                    void navigator.clipboard.writeText(qrToken);
                    onNotify('QR verification token copied.');
                  }}
                  className="inline-flex flex-1 items-center justify-center gap-1.5 rounded-xl bg-slate-900 py-2 text-xs font-bold text-white hover:bg-slate-800 disabled:bg-slate-300"
                >
                  <Copy size={13} /> Copy Token
                </button>
              </div>
            </div>
          </div>
        </section>
      </div>
    );
  }

  // LIVE KITCHEN QUEUE MODE
  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-white p-4">
        <div className="flex flex-wrap items-center gap-2">
          <ChefHat size={18} className="text-orange-600" />
          <h2 className="text-base font-black text-slate-950">Live Kitchen Preparation &amp; Dispatch Queue</h2>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <input
            type="date"
            value={queueDate}
            onChange={(e) => onQueueFilterChange(e.target.value, queueSlot)}
            className="rounded-xl border border-slate-300 px-3 py-1.5 text-xs font-semibold text-slate-900"
          />
          {(['BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER'] as const).map((slotName) => (
            <button
              key={slotName}
              type="button"
              onClick={() => onQueueFilterChange(queueDate, slotName)}
              className={`rounded-xl px-3 py-1.5 text-xs font-bold ${
                queueSlot === slotName
                  ? 'bg-orange-600 text-white'
                  : 'border border-slate-200 bg-white text-slate-600 hover:bg-slate-50'
              }`}
            >
              {slotName}
            </button>
          ))}
        </div>
      </div>

      {queueItems.length === 0 ? (
        <div className="rounded-2xl border border-dashed border-slate-300 bg-white p-8 text-center">
          <p className="text-sm font-bold text-slate-900">No subscribers scheduled for {queueSlot} on {queueDate}.</p>
          <p className="mt-1 text-xs text-slate-500">
            Active subscribers matching this weekday and meal slot appear here automatically.
          </p>
        </div>
      ) : (
        <div className="space-y-3">
          {queueItems.map((item) => (
            <article key={item.subscription_id} className="rounded-2xl border border-slate-200 bg-white p-4">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-bold text-slate-950">{item.customer_name}</p>
                    <span
                      className={`rounded-full px-2 py-0.5 text-[10px] font-bold uppercase ${
                        item.fulfillment_mode === 'delivery'
                          ? 'bg-amber-50 text-amber-800'
                          : 'bg-slate-100 text-slate-700'
                      }`}
                    >
                      {item.fulfillment_mode === 'delivery' ? 'Delivery' : 'Counter Pickup'}
                    </span>
                  </div>
                  <p className="mt-0.5 text-xs text-slate-500">
                    {item.plan_name}
                    {item.customer_phone ? ` · ${item.customer_phone}` : ''}
                    {item.drop_address ? ` · ${item.drop_address}` : ''}
                  </p>
                </div>

                <div className="flex flex-wrap items-center gap-2">
                  <input
                    type="number"
                    min={5}
                    max={180}
                    placeholder="ETA min"
                    value={etaDrafts[item.subscription_id] ?? (item.eta_minutes ? String(item.eta_minutes) : '')}
                    onChange={(e) =>
                      setEtaDrafts((prev) => ({ ...prev, [item.subscription_id]: e.target.value }))
                    }
                    className="w-20 rounded-xl border border-slate-300 px-2.5 py-1.5 text-xs tabular-nums"
                  />
                  <select
                    disabled={busySubId === item.subscription_id}
                    value={item.status || 'scheduled'}
                    onChange={(e) => updateQueueStatus(item, e.target.value)}
                    className="rounded-xl border border-slate-300 bg-white px-3 py-1.5 text-xs font-bold text-slate-900"
                  >
                    {QUEUE_STATUS_OPTIONS.map((opt) => (
                      <option key={opt.value} value={opt.value}>
                        {opt.label}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {item.fulfillment_mode === 'delivery' && (
                <div className="mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-slate-100 pt-3 text-xs">
                  <span className="flex items-center gap-1.5 text-slate-600">
                    <Truck size={14} className="text-amber-700" />
                    {item.rider_name ? `Assigned Rider: ${item.rider_name} (${item.rider_phone || ''})` : 'No rider assigned yet'}
                  </span>
                  <div className="flex items-center gap-2">
                    <select
                      disabled={busySubId === item.subscription_id || riders.length === 0}
                      value={item.rider_id || ''}
                      onChange={(e) => assignRider(item, e.target.value)}
                      className="rounded-xl border border-slate-300 bg-white px-3 py-1.5 text-xs font-semibold text-slate-800"
                    >
                      <option value="">{riders.length ? 'Assign delivery rider...' : 'No riders added'}</option>
                      {riders.map((r) => (
                        <option key={r.id} value={r.id}>
                          {r.name} ({r.phone})
                        </option>
                      ))}
                    </select>
                    <button
                      type="button"
                      disabled={busySubId === item.subscription_id}
                      onClick={() => updateQueueStatus(item, 'delivered')}
                      className="inline-flex items-center gap-1 rounded-xl bg-emerald-700 px-3 py-1.5 text-xs font-bold text-white hover:bg-emerald-800"
                    >
                      <Check size={13} /> Mark Delivered
                    </button>
                  </div>
                </div>
              )}
            </article>
          ))}
        </div>
      )}
    </div>
  );
}
