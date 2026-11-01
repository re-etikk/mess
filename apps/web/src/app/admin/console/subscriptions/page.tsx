'use client';

import { useCallback, useEffect, useState } from 'react';
import { AlertTriangle, ChevronLeft, ChevronRight, CreditCard, RotateCw } from 'lucide-react';

type Subscription = {
  id: string; customer_id: string; provider_id: string; plan_id: string; status: string;
  plan_type_snapshot: string; plan_name_snapshot: string; price_paid_paise: number;
  initial_meal_credits: number | null; remaining_meal_credits: number | null;
  starts_at: string | null; expires_at: string | null; created_at: string;
  customer_name: string; provider_name: string;
};
type Result = { success: true; total: number; page: number; page_size: number; subscriptions: Subscription[] };
const statuses = ['', 'pending_payment', 'active', 'paused', 'expired', 'cancelled', 'refund_pending', 'refunded', 'payment_failed'];
const money = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 });

export default function AdminSubscriptionsPage() {
  const [result, setResult] = useState<Result | null>(null);
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const params = new URLSearchParams({ page: String(page), page_size: '20' });
      if (status) params.set('status', status);
      const response = await fetch(`/api/admin/subscriptions?${params}`, { cache: 'no-store' });
      const data = await response.json();
      if (!response.ok || !data.success) throw new Error(data.error || 'Subscription records could not be loaded.');
      setResult(data);
    } catch (cause) {
      setResult(null); setError(cause instanceof Error ? cause.message : 'Subscription records could not be loaded.');
    } finally { setLoading(false); }
  }, [page, status]);

  useEffect(() => { void load(); }, [load]);
  const pages = result ? Math.max(1, Math.ceil(result.total / result.page_size)) : 1;

  return <div className="admin-page-stack">
    <header className="admin-page-heading"><div><p className="admin-eyebrow">ENTITLEMENT RECORDS</p><h2>Subscriptions</h2><p>Persisted subscription status and plan snapshots. Entitlements are not editable from this screen.</p></div><button type="button" onClick={() => void load()} disabled={loading} className="admin-secondary-button"><RotateCw size={15} className={loading ? 'animate-spin' : ''} /> Refresh</button></header>
    <section className="admin-table-panel">
      <div className="admin-table-toolbar"><label className="admin-filter-label">Status<select value={status} onChange={(event) => { setPage(1); setStatus(event.target.value); }}><option value="">All statuses</option>{statuses.filter(Boolean).map((value) => <option value={value} key={value}>{value.replaceAll('_', ' ')}</option>)}</select></label><span className="admin-record-count">{result ? `${result.total.toLocaleString('en-IN')} subscriptions` : '—'}</span></div>
      {error && <div role="alert" className="admin-error"><AlertTriangle size={18} /><div><strong>Subscription records unavailable</strong><p>{error}</p><button type="button" onClick={() => void load()}>Retry</button></div></div>}
      {loading && !result ? <div className="admin-loading-table"><div /><div /><div /><div /></div> : null}
      {!loading && result && result.subscriptions.length === 0 ? <div className="admin-empty"><CreditCard size={22} /><h3>No subscriptions in this view</h3><p>When matching records exist, they will appear here.</p></div> : null}
      {result && result.subscriptions.length > 0 && <>
        <div className="admin-table-wrap"><table className="admin-data-table"><thead><tr><th>Customer / Partner</th><th>Plan</th><th>Status</th><th>Paid</th><th>Entitlement</th><th>Validity</th></tr></thead><tbody>{result.subscriptions.map((row) => <tr key={row.id}><td><strong>{row.customer_name}</strong><small>{row.provider_name}</small><code>{row.id}</code></td><td><strong>{row.plan_name_snapshot}</strong><small>{row.plan_type_snapshot.replaceAll('_', ' ')}</small></td><td><span className={`admin-status admin-status-${row.status}`}>{row.status.replaceAll('_', ' ')}</span></td><td>{money.format(row.price_paid_paise / 100)}</td><td>{row.plan_type_snapshot === 'meal_credits' ? `${row.remaining_meal_credits ?? 0} / ${row.initial_meal_credits ?? 0} credits` : 'Fixed period'}</td><td>{row.starts_at ? new Date(row.starts_at).toLocaleDateString('en-IN') : '—'} – {row.expires_at ? new Date(row.expires_at).toLocaleDateString('en-IN') : 'No expiry'}</td></tr>)}</tbody></table></div>
        <div className="admin-pagination"><span>Page {page} of {pages}</span><div><button type="button" onClick={() => setPage((value) => Math.max(1, value - 1))} disabled={page <= 1 || loading} aria-label="Previous page"><ChevronLeft size={17} /></button><button type="button" onClick={() => setPage((value) => Math.min(pages, value + 1))} disabled={page >= pages || loading} aria-label="Next page"><ChevronRight size={17} /></button></div></div>
      </>}
    </section>
    <section className="admin-info-panel"><div className="admin-info-icon"><AlertTriangle size={18} /></div><div><h3>No manual entitlement edits</h3><p>Subscription changes affect customer meal access and money. Pause, cancellation, extension, and correction controls need verified product policy and an auditable server-side transaction before they can be enabled.</p></div></section>
  </div>;
}
