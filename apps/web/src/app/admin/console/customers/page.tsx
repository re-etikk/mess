'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import {
  AlertTriangle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  RotateCw,
  Search,
  ShieldAlert,
  Users,
  X,
} from 'lucide-react';

type Customer = {
  id: string;
  name: string;
  phone_masked: string | null;
  city?: string | null;
  account_status?: string;
  suspension_reason?: string | null;
  created_at: string;
};

type Result = { success: true; total: number; page: number; page_size: number; users: Customer[] };

export default function AdminCustomersPage() {
  const [result, setResult] = useState<Result | null>(null);
  const [query, setQuery] = useState('');
  const [appliedQuery, setAppliedQuery] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const [detail, setDetail] = useState<{
    customer: any;
    subscriptions: any[];
    addresses: any[];
    tickets: any[];
  } | null>(null);
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const params = new URLSearchParams({ page: String(page), page_size: '20' });
      if (appliedQuery) params.set('q', appliedQuery);
      if (statusFilter) params.set('status', statusFilter);
      const response = await fetch(`/api/admin/users?${params}`, { cache: 'no-store' });
      const data = await response.json();
      if (!response.ok || !data.success) throw new Error(data.error || 'Customer records could not be loaded.');
      setResult(data);
    } catch (cause) {
      setResult(null);
      setError(cause instanceof Error ? cause.message : 'Customer records could not be loaded.');
    } finally {
      setLoading(false);
    }
  }, [page, appliedQuery, statusFilter]);

  useEffect(() => {
    void load();
  }, [load]);

  function search(event: FormEvent) {
    event.preventDefault();
    setPage(1);
    setAppliedQuery(query.trim());
  }

  async function openDetail(id: string) {
    setError('');
    setReason('');
    const res = await fetch(`/api/admin/users?detail_id=${encodeURIComponent(id)}`, { cache: 'no-store' });
    const data = await res.json();
    if (res.ok && data.success) {
      setDetail({
        customer: data.customer,
        subscriptions: data.subscriptions ?? [],
        addresses: data.addresses ?? [],
        tickets: data.tickets ?? [],
      });
    } else {
      setError(data.error || 'Could not load customer profile.');
    }
  }

  async function moderateCustomer(action: 'suspend' | 'block' | 'reactivate') {
    if (!detail) return;
    if (reason.trim().length < 3) {
      setError('Enter a clear audit reason (min 3 chars).');
      return;
    }
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/users', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: detail.customer.id, action, reason: reason.trim() }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) throw new Error(data.error || 'Customer action failed.');
      setNotice(data.message);
      setDetail(null);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Customer action failed.');
    } finally {
      setBusy(false);
    }
  }

  const pages = result ? Math.max(1, Math.ceil(result.total / result.page_size)) : 1;

  return (
    <div className="admin-page-stack">
      <header className="admin-page-heading">
        <div>
          <h2>Customer Directory & Moderation</h2>
          <p>Inspect customer profiles, active passes, delivery addresses, support history, or suspend compromised/abusive accounts.</p>
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
        <form onSubmit={search} className="admin-table-toolbar">
          <label className="admin-search">
            <Search size={16} />
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search by name, phone, email, or UUID"
              aria-label="Search customers"
            />
          </label>
          <select className="admin-select" style={{ width: 'auto' }} value={statusFilter} onChange={(e) => { setPage(1); setStatusFilter(e.target.value); }}>
            <option value="">All Statuses</option>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
            <option value="blocked">Blocked</option>
          </select>
          <button type="submit" className="admin-primary-button">
            Search
          </button>
          <span className="admin-record-count">{result ? `${result.total.toLocaleString('en-IN')} customers` : '—'}</span>
        </form>

        {loading && !result ? (
          <div className="admin-loading-table">
            <div />
            <div />
            <div />
            <div />
          </div>
        ) : null}

        {!loading && result && result.users.length === 0 ? (
          <div className="admin-empty">
            <Users size={22} />
            <h3>{appliedQuery ? 'No matching customers' : 'No customer accounts yet'}</h3>
            <p>{appliedQuery ? 'Try another search term or UUID.' : 'Customer accounts will appear here when created.'}</p>
          </div>
        ) : null}

        {result && result.users.length > 0 && (
          <>
            <div className="admin-table-wrap">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Customer</th>
                    <th>City</th>
                    <th>Phone</th>
                    <th>Status</th>
                    <th>Joined</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {result.users.map((customer) => (
                    <tr key={customer.id}>
                      <td>
                        <strong>{customer.name || 'Name not provided'}</strong>
                        <code>{customer.id}</code>
                      </td>
                      <td>{customer.city || '—'}</td>
                      <td>{customer.phone_masked ?? 'Not provided'}</td>
                      <td>
                        <span className={`admin-status admin-status-${customer.account_status || 'active'}`}>
                          {customer.account_status || 'active'}
                        </span>
                      </td>
                      <td>{new Date(customer.created_at).toLocaleDateString('en-IN')}</td>
                      <td>
                        <button type="button" onClick={() => void openDetail(customer.id)} className="admin-secondary-button">
                          Inspect
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

      {detail && (
        <div className="admin-drawer-backdrop" onClick={() => setDetail(null)}>
          <div className="admin-drawer" onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <div>
                <h3 style={{ margin: 0, fontSize: 18, fontWeight: 850 }}>{detail.customer.name || 'Customer'}</h3>
                <p style={{ margin: '4px 0 0', fontSize: 12, color: '#5a646d' }}>
                  {detail.customer.email || 'Email masked'} · {detail.customer.phone || 'No phone'}
                </p>
              </div>
              <button type="button" onClick={() => setDetail(null)} className="admin-secondary-button">
                <X size={15} />
              </button>
            </div>

            <div className="admin-page-stack">
              <div className="admin-panel" style={{ padding: 14 }}>
                <strong style={{ fontSize: 13 }}>Account Moderation</strong>
                <p style={{ fontSize: 12, color: '#5a646d', margin: '4px 0 10px' }}>
                  Current Status: <span className={`admin-status admin-status-${detail.customer.account_status}`}>{detail.customer.account_status}</span>
                </p>
                <input
                  className="admin-input"
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  placeholder="Reason for suspend / block / reactivate (required)"
                />
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 10 }}>
                  {detail.customer.account_status === 'active' ? (
                    <>
                      <button type="button" disabled={busy} onClick={() => void moderateCustomer('suspend')} className="admin-danger-button">
                        <ShieldAlert size={14} /> Suspend Account
                      </button>
                      <button type="button" disabled={busy} onClick={() => void moderateCustomer('block')} className="admin-danger-button">
                        Block Account
                      </button>
                    </>
                  ) : (
                    <button type="button" disabled={busy} onClick={() => void moderateCustomer('reactivate')} className="admin-primary-button">
                      Reactivate Account
                    </button>
                  )}
                </div>
              </div>

              <div className="admin-panel" style={{ padding: 14 }}>
                <strong style={{ fontSize: 13 }}>Recent Subscriptions ({detail.subscriptions.length})</strong>
                <div style={{ display: 'grid', gap: 8, marginTop: 8 }}>
                  {detail.subscriptions.length === 0 ? (
                    <small style={{ color: '#6b7280' }}>No subscriptions found.</small>
                  ) : (
                    detail.subscriptions.map((s) => (
                      <div key={s.id} style={{ fontSize: 12, borderBottom: '1px solid #f0ede7', paddingBottom: 6 }}>
                        <strong>{s.plan_name_snapshot}</strong> · {s.providers?.display_name || 'Kitchen'} ·{' '}
                        <span className={`admin-status admin-status-${s.status}`}>{s.status}</span>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {detail.addresses.length > 0 && (
                <div className="admin-panel" style={{ padding: 14 }}>
                  <strong style={{ fontSize: 13 }}>Saved Delivery Addresses ({detail.addresses.length})</strong>
                  {detail.addresses.map((a) => (
                    <p key={a.id} style={{ fontSize: 12, margin: '6px 0 0', color: '#425059' }}>
                      {a.label}: {a.address_line1}, {a.locality} {a.city}
                    </p>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
