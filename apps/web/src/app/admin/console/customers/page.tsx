'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import { AlertTriangle, ChevronLeft, ChevronRight, RotateCw, Search, Users } from 'lucide-react';

type Customer = { id: string; name: string; phone_masked: string | null; role: string; created_at: string };
type Result = { success: true; total: number; page: number; page_size: number; users: Customer[] };

export default function AdminCustomersPage() {
  const [result, setResult] = useState<Result | null>(null);
  const [query, setQuery] = useState('');
  const [appliedQuery, setAppliedQuery] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const params = new URLSearchParams({ page: String(page), page_size: '20' });
      if (appliedQuery) params.set('q', appliedQuery);
      const response = await fetch(`/api/admin/users?${params}`, { cache: 'no-store' });
      const data = await response.json();
      if (!response.ok || !data.success) throw new Error(data.error || 'Customer records could not be loaded.');
      setResult(data);
    } catch (cause) {
      setResult(null); setError(cause instanceof Error ? cause.message : 'Customer records could not be loaded.');
    } finally { setLoading(false); }
  }, [page, appliedQuery]);

  useEffect(() => { void load(); }, [load]);

  function search(event: FormEvent) {
    event.preventDefault(); setPage(1); setAppliedQuery(query.trim());
  }

  const pages = result ? Math.max(1, Math.ceil(result.total / result.page_size)) : 1;

  return <div className="admin-page-stack">
    <header className="admin-page-heading"><div><p className="admin-eyebrow">CUSTOMER DIRECTORY</p><h2>Customers</h2><p>Customer records from active database roles. Phone numbers are masked in this list.</p></div><button type="button" onClick={() => void load()} disabled={loading} className="admin-secondary-button"><RotateCw size={15} className={loading ? 'animate-spin' : ''} /> Refresh</button></header>
    <section className="admin-table-panel">
      <form onSubmit={search} className="admin-table-toolbar"><label className="admin-search"><Search size={16} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search by name or profile ID" aria-label="Search customers by name or profile ID" /></label><button type="submit" className="admin-primary-button">Search</button><span className="admin-record-count">{result ? `${result.total.toLocaleString('en-IN')} customers` : '—'}</span></form>
      {error && <div role="alert" className="admin-error"><AlertTriangle size={18} /><div><strong>Customer directory unavailable</strong><p>{error}</p><button type="button" onClick={() => void load()}>Retry</button></div></div>}
      {loading && !result ? <div className="admin-loading-table"><div /><div /><div /><div /></div> : null}
      {!loading && result && result.users.length === 0 ? <div className="admin-empty"><Users size={22} /><h3>{appliedQuery ? 'No matching customers' : 'No customer accounts yet'}</h3><p>{appliedQuery ? 'Try another name or profile ID.' : 'Customer accounts will appear here when they are created.'}</p></div> : null}
      {result && result.users.length > 0 && <>
        <div className="admin-table-wrap"><table className="admin-data-table"><thead><tr><th>Customer</th><th>Profile ID</th><th>Phone</th><th>Joined</th></tr></thead><tbody>{result.users.map((customer) => <tr key={customer.id}><td><strong>{customer.name || 'Name not provided'}</strong><small>Customer account</small></td><td><code>{customer.id}</code></td><td>{customer.phone_masked ?? 'Not provided'}</td><td>{new Date(customer.created_at).toLocaleDateString('en-IN')}</td></tr>)}</tbody></table></div>
        <div className="admin-pagination"><span>Page {page} of {pages}</span><div><button type="button" onClick={() => setPage((value) => Math.max(1, value - 1))} disabled={page <= 1 || loading} aria-label="Previous page"><ChevronLeft size={17} /></button><button type="button" onClick={() => setPage((value) => Math.min(pages, value + 1))} disabled={page >= pages || loading} aria-label="Next page"><ChevronRight size={17} /></button></div></div>
      </>}
    </section>
    <section className="admin-info-panel"><div className="admin-info-icon"><AlertTriangle size={18} /></div><div><h3>Actions are read-only in this release slice</h3><p>The existing schema has no customer account status field or audited block/unblock workflow. Refund and complaint actions will appear only after their policies and transaction-safe APIs are verified.</p></div></section>
  </div>;
}
