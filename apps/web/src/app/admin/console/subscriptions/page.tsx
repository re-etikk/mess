'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import {
  AlertTriangle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  CreditCard,
  RotateCw,
  Search,
  X,
} from 'lucide-react';

type Subscription = {
  id: string;
  customer_id: string;
  provider_id: string;
  plan_id: string;
  status: string;
  plan_type_snapshot: string;
  plan_name_snapshot: string;
  price_paid_paise: number;
  discount_paise?: number;
  promo_code?: string | null;
  payment_mode?: string | null;
  initial_meal_credits: number | null;
  remaining_meal_credits: number | null;
  starts_at: string | null;
  expires_at: string | null;
  created_at: string;
  customer_name: string;
  provider_name: string;
};

type Result = { success: true; total: number; page: number; page_size: number; subscriptions: Subscription[] };
const statuses = ['', 'pending_payment', 'active', 'paused', 'expired', 'cancelled', 'refund_pending', 'refunded', 'payment_failed'];
const money = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 });

export default function AdminSubscriptionsPage() {
  const [result, setResult] = useState<Result | null>(null);
  const [status, setStatus] = useState('');
  const [query, setQuery] = useState('');
  const [appliedQ, setAppliedQ] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const [selected, setSelected] = useState<Subscription | null>(null);
  const [reason, setReason] = useState('');
  const [extendDays, setExtendDays] = useState(7);
  const [creditsDelta, setCreditsDelta] = useState(2);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ page: String(page), page_size: '20' });
      if (status) params.set('status', status);
      if (appliedQ) params.set('q', appliedQ);
      const response = await fetch(`/api/admin/subscriptions?${params}`, { cache: 'no-store' });
      const data = await response.json();
      if (!response.ok || !data.success) throw new Error(data.error || 'Subscription records could not be loaded.');
      setResult(data);
    } catch (cause) {
      setResult(null);
      setError(cause instanceof Error ? cause.message : 'Subscription records could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [page, status, appliedQ]);

  useEffect(() => {
    void load();
  }, [load]);

  async function runAction(action: 'pause' | 'resume' | 'extend_days' | 'adjust_credits' | 'cancel') {
    if (!selected) return;
    if (reason.trim().length < 3) {
      setError('Enter an audit reason (min 3 characters) before modifying an entitlement.');
      return;
    }
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/subscriptions', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          subscription_id: selected.id,
          action,
          reason: reason.trim(),
          extend_days: extendDays,
          credits_delta: creditsDelta,
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Action failed.');
      setNotice(`Subscription ${action.replace('_', ' ')} applied.`);
      setSelected(null);
      setReason('');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Subscription update failed.');
    } finally {
      setBusy(false);
    }
  }

  function submitSearch(e: FormEvent) {
    e.preventDefault();
    setPage(1);
    setAppliedQ(query.trim());
  }

  const pages = result ? Math.max(1, Math.ceil(result.total / result.page_size)) : 1;

  return (
    <div className="admin-page-stack">
      <header className="admin-page-heading">
        <div>
          <h2>Subscriptions & Entitlements</h2>
          <p>Search orders/subscriptions, verify applied promo codes, pause, resume, extend validity, or cancel passes with audit tracking.</p>
        </div>
        <button type="button" onClick={() => void load()} disabled={loading} className="admin-secondary-button">
          <RotateCw size={15} className={loading ? 'animate-spin' : ''} /> Refresh
        </button>
      </header>

      {error && (
        <div role="alert" className="admin-error">
          <AlertTriangle size={18} />
          <span>{error}</span>
        </div>
      )}
      {notice && (
        <div className="admin-notice-success">
          <CheckCircle2 size={18} />
          <span>{notice}</span>
        </div>
      )}

      <section className="admin-table-panel">
        <form onSubmit={submitSearch} className="admin-table-toolbar">
          <label className="admin-search">
            <Search size={15} />
            <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Customer name or UUID..." />
          </label>
          <select
            className="admin-select"
            style={{ width: 'auto' }}
            value={status}
            onChange={(event) => {
              setPage(1);
              setStatus(event.target.value);
            }}
          >
            <option value="">All statuses</option>
            {statuses.filter(Boolean).map((value) => (
              <option value={value} key={value}>
                {value.replaceAll('_', ' ')}
              </option>
            ))}
          </select>
          <button type="submit" className="admin-primary-button">
            Search
          </button>
          <span className="admin-record-count">{result ? `${result.total.toLocaleString('en-IN')} subscriptions` : '—'}</span>
        </form>

        {loading && !result ? (
          <div className="admin-loading-table">
            <div />
            <div />
            <div />
            <div />
          </div>
        ) : null}

        {!loading && result && result.subscriptions.length === 0 ? (
          <div className="admin-empty">
            <CreditCard size={22} />
            <h3>No subscriptions in this view</h3>
            <p>When matching records exist, they will appear here.</p>
          </div>
        ) : null}

        {result && result.subscriptions.length > 0 && (
          <>
            <div className="admin-table-wrap">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Customer / Partner</th>
                    <th>Plan</th>
                    <th>Status</th>
                    <th>Paid & Promo</th>
                    <th>Entitlement</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {result.subscriptions.map((row) => (
                    <tr key={row.id}>
                      <td>
                        <strong>{row.customer_name}</strong>
                        <small>{row.provider_name}</small>
                        <code>{row.id.slice(0, 8)}…</code>
                      </td>
                      <td>
                        <strong>{row.plan_name_snapshot}</strong>
                        <small>{row.plan_type_snapshot.replaceAll('_', ' ')}</small>
                      </td>
                      <td>
                        <span className={`admin-status admin-status-${row.status}`}>{row.status.replaceAll('_', ' ')}</span>
                      </td>
                      <td>
                        <strong>{money.format(row.price_paid_paise / 100)}</strong>
                        {row.promo_code && <small>Promo: {row.promo_code}</small>}
                      </td>
                      <td>
                        {row.plan_type_snapshot === 'meal_credits'
                          ? `${row.remaining_meal_credits ?? 0} / ${row.initial_meal_credits ?? 0} credits`
                          : 'Fixed period'}
                        <small>{row.expires_at ? `Ends ${new Date(row.expires_at).toLocaleDateString('en-IN')}` : 'No expiry'}</small>
                      </td>
                      <td>
                        <button type="button" onClick={() => { setSelected(row); setReason(''); }} className="admin-secondary-button">
                          Manage
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="admin-pagination">
              <span>
                Page {page} of {pages}
              </span>
              <div>
                <button type="button" onClick={() => setPage((value) => Math.max(1, value - 1))} disabled={page <= 1 || loading} aria-label="Previous page">
                  <ChevronLeft size={17} />
                </button>
                <button type="button" onClick={() => setPage((value) => Math.min(pages, value + 1))} disabled={page >= pages || loading} aria-label="Next page">
                  <ChevronRight size={17} />
                </button>
              </div>
            </div>
          </>
        )}
      </section>

      {selected && (
        <div className="admin-drawer-backdrop" onClick={() => setSelected(null)}>
          <div className="admin-drawer" onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <div>
                <h3 style={{ margin: 0, fontSize: 18, fontWeight: 850 }}>{selected.customer_name}</h3>
                <p style={{ margin: '4px 0 0', fontSize: 12, color: '#5a646d' }}>
                  {selected.plan_name_snapshot} · {selected.provider_name}
                </p>
              </div>
              <button type="button" onClick={() => setSelected(null)} className="admin-secondary-button">
                <X size={15} />
              </button>
            </div>

            <div className="admin-page-stack">
              <div className="admin-panel" style={{ padding: 14, display: 'grid', gap: 10 }}>
                <div className="admin-field">
                  <label>Audit Reason (Required)</label>
                  <input className="admin-input" value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Customer requested support resolution..." />
                </div>
                <div className="admin-field-grid">
                  <div className="admin-field">
                    <label>Extend Expiry (+Days)</label>
                    <input type="number" className="admin-input" min={1} max={365} value={extendDays} onChange={(e) => setExtendDays(Number(e.target.value))} />
                  </div>
                  <div className="admin-field">
                    <label>Credits Delta (+/-)</label>
                    <input type="number" className="admin-input" min={-50} max={200} value={creditsDelta} onChange={(e) => setCreditsDelta(Number(e.target.value))} />
                  </div>
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                  <button type="button" disabled={busy} onClick={() => void runAction('extend_days')} className="admin-primary-button">
                    Extend +{extendDays}d
                  </button>
                  <button type="button" disabled={busy} onClick={() => void runAction('adjust_credits')} className="admin-secondary-button">
                    Adjust Credits ({creditsDelta >= 0 ? `+${creditsDelta}` : creditsDelta})
                  </button>
                  {selected.status === 'active' ? (
                    <button type="button" disabled={busy} onClick={() => void runAction('pause')} className="admin-secondary-button">
                      Pause Pass
                    </button>
                  ) : (
                    <button type="button" disabled={busy} onClick={() => void runAction('resume')} className="admin-secondary-button">
                      Resume Pass
                    </button>
                  )}
                  <button type="button" disabled={busy} onClick={() => void runAction('cancel')} className="admin-danger-button">
                    Cancel Pass
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
