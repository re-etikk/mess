'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import {
  AlertTriangle,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Plus,
  RotateCw,
  ShieldCheck,
  Trash2,
  X,
} from 'lucide-react';

const tabs = [
  ['bookings', 'Bookings'],
  ['redemptions', 'Redemptions'],
  ['payments', 'Payments'],
  ['refunds', 'Refunds'],
  ['settlements', 'Settlements'],
  ['support', 'Support Feed'],
  ['audit', 'Audit Log'],
  ['access', 'Team Access (RBAC)'],
] as const;

type Source = (typeof tabs)[number][0];
type RecordRow = Record<string, any>;

const statuses: Partial<Record<Source, string[]>> = {
  bookings: ['draft', 'pending_payment', 'confirmed', 'ready', 'assigned', 'accepted', 'picked_up', 'redeemed', 'delivered', 'cancelled', 'missed', 'failed_delivery', 'refund_pending', 'refunded'],
  payments: ['created', 'pending', 'succeeded', 'failed', 'cancelled'],
  refunds: ['requested', 'pending', 'succeeded', 'failed', 'rejected'],
  settlements: ['draft', 'pending', 'processing', 'paid', 'failed', 'cancelled'],
  support: ['open', 'triaged', 'in_progress', 'waiting_for_user', 'resolved', 'closed'],
};

const dateFields = new Set(['created_at', 'updated_at', 'requested_at', 'completed_at', 'settled_at', 'redeemed_at', 'resolved_at', 'verified_at']);
const paiseFields = new Set(['total_due_paise', 'amount_paise', 'gross_food_paise', 'commission_paise', 'refund_paise', 'adjustment_paise', 'net_payable_paise']);
const idFields = new Set(['id', 'customer_id', 'provider_id', 'booking_id', 'subscription_id', 'payment_transaction_id', 'created_by', 'about_user_id', 'assigned_to', 'redeemed_by', 'subject_id', 'meal_slot_id', 'request_id', 'actor_user_id', 'processed_by']);
const money = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 });

function display(field: string, value: any) {
  if (value === null || value === '' || value === undefined) return '—';
  if (dateFields.has(field)) return new Date(String(value)).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  if (paiseFields.has(field) && typeof value === 'number') return money.format(value / 100);
  if (idFields.has(field)) return String(value).slice(0, 8) + '…';
  return String(value).replaceAll('_', ' ');
}

export default function AdminOperationsPage() {
  const [source, setSource] = useState<Source>('bookings');
  const [status, setStatus] = useState('');
  const [page, setPage] = useState(1);
  const [records, setRecords] = useState<RecordRow[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [selectedRow, setSelectedRow] = useState<RecordRow | null>(null);

  // RBAC Team state
  const [team, setTeam] = useState<any[]>([]);
  const [grantEmail, setGrantEmail] = useState('');
  const [grantRole, setGrantRole] = useState<'operations' | 'finance' | 'support' | 'developer_readonly' | 'super_admin'>('support');
  const [grantReason, setGrantReason] = useState('');
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      if (source === 'access') {
        const res = await fetch('/api/admin/access', { cache: 'no-store' });
        const json = await res.json();
        if (!res.ok || !json.success) throw new Error(json.error || 'Team access requires Super Admin privileges.');
        setTeam(json.team ?? []);
        setRecords([]);
        setTotal((json.team ?? []).length);
        return;
      }
      const params = new URLSearchParams({ source, page: String(page), page_size: '20' });
      if (status) params.set('status', status);
      const response = await fetch(`/api/admin/operations?${params}`, { cache: 'no-store' });
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(result.error || 'Operations records are unavailable.');
      setRecords(result.records ?? []);
      setTotal(result.total ?? 0);
    } catch (cause) {
      setRecords([]);
      setTotal(0);
      setError(cause instanceof Error ? cause.message : 'Records unavailable.');
    } finally {
      setLoading(false);
    }
  }, [source, status, page]);

  useEffect(() => {
    void load();
  }, [load]);

  function selectSource(next: Source) {
    setSource(next);
    setStatus('');
    setPage(1);
    setError('');
    setNotice('');
  }

  async function grantAccess(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/access', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: grantEmail.trim(), admin_role: grantRole, reason: grantReason.trim() }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Grant failed.');
      setGrantEmail('');
      setGrantReason('');
      setNotice(json.message);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Grant failed.');
    } finally {
      setBusy(false);
    }
  }

  async function revokeAccess(userId: string) {
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/access', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: userId, reason: 'Revoked via Operations & Access Desk' }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Revoke failed.');
      setNotice(json.message);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Revoke failed.');
    } finally {
      setBusy(false);
    }
  }

  const columns = records.length ? Object.keys(records[0]) : [];
  const pageCount = Math.max(1, Math.ceil(total / 20));

  return (
    <div className="admin-page-stack">
      <header className="admin-page-heading">
        <div>
          <h2>Operations Ledger & Team Access</h2>
          <p>Inspect append-only audit logs, live bookings/redemptions, and assign scoped Admin RBAC roles.</p>
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

      <div className="admin-operation-tabs" role="tablist" aria-label="Operations record type">
        {tabs.map(([key, label]) => (
          <button type="button" role="tab" aria-selected={source === key} key={key} onClick={() => selectSource(key)}>
            {label}
          </button>
        ))}
      </div>

      {source === 'access' ? (
        <div className="admin-page-stack">
          <section className="admin-panel">
            <h3 className="admin-panel-title">Assign Scoped Team Role (Super Admin Only)</h3>
            <form onSubmit={grantAccess} className="admin-field-grid">
              <div className="admin-field">
                <label>Registered User Email</label>
                <input type="email" required className="admin-input" value={grantEmail} onChange={(e) => setGrantEmail(e.target.value)} placeholder="teammate@thali.store" />
              </div>
              <div className="admin-field">
                <label>Scoped Role</label>
                <select className="admin-select" value={grantRole} onChange={(e) => setGrantRole(e.target.value as any)}>
                  <option value="support">Support Desk (Tickets, Coupons, Customer Moderation)</option>
                  <option value="operations">Operations (Partners, Banners, App Customize, Passes)</option>
                  <option value="finance">Finance (Settlements, Refunds, Commission)</option>
                  <option value="developer_readonly">Developer Read-Only (Masked Metrics/Logs)</option>
                  <option value="super_admin">Super Admin (Full Control)</option>
                </select>
              </div>
              <div className="admin-field">
                <label>Reason for Assignment</label>
                <input required minLength={3} className="admin-input" value={grantReason} onChange={(e) => setGrantReason(e.target.value)} placeholder="Joined customer support team" />
              </div>
              <div style={{ display: 'flex', alignItems: 'flex-end' }}>
                <button type="submit" disabled={busy} className="admin-primary-button">
                  <Plus size={14} /> Grant Scoped Role
                </button>
              </div>
            </form>
          </section>

          <section className="admin-table-panel">
            <div className="admin-table-wrap">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Team Member</th>
                    <th>Assigned Role</th>
                    <th>Status</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {team.map((m) => (
                    <tr key={m.user_id}>
                      <td>
                        <strong>{m.name}</strong>
                        <small>{m.email}</small>
                        <code>{m.user_id}</code>
                      </td>
                      <td>
                        <span className="admin-status admin-status-pending_payment">{m.admin_role.replace('_', ' ')}</span>
                      </td>
                      <td>
                        <span className={`admin-status ${m.active ? 'admin-status-active' : 'admin-status-expired'}`}>
                          {m.active ? 'Active' : 'Revoked'}
                        </span>
                      </td>
                      <td>
                        {m.active && (
                          <button type="button" disabled={busy} onClick={() => void revokeAccess(m.user_id)} className="admin-danger-button">
                            <Trash2 size={13} /> Revoke
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </div>
      ) : (
        <section className="admin-table-panel" aria-label={`${source} records`}>
          <div className="admin-table-toolbar">
            <strong style={{ fontSize: 13 }}>{tabs.find(([key]) => key === source)?.[1]}</strong>
            {statuses[source] && (
              <label className="admin-filter-label">
                Status
                <select
                  value={status}
                  onChange={(event) => {
                    setStatus(event.target.value);
                    setPage(1);
                  }}
                >
                  <option value="">All statuses</option>
                  {statuses[source]?.map((value) => (
                    <option key={value} value={value}>
                      {value.replaceAll('_', ' ')}
                    </option>
                  ))}
                </select>
              </label>
            )}
            <span className="admin-record-count">{total.toLocaleString('en-IN')} records</span>
          </div>

          {loading ? (
            <div className="admin-loading-table">
              <div />
              <div />
              <div />
              <div />
            </div>
          ) : records.length === 0 ? (
            <div className="admin-empty">
              <ShieldCheck size={22} />
              <h3>No {source} records</h3>
              <p>There are no matching records in the database.</p>
            </div>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    {columns.map((field) => (
                      <th key={field}>{field.replaceAll('_', ' ')}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {records.map((record, index) => (
                    <tr key={String(record.id ?? index)} style={{ cursor: 'pointer' }} onClick={() => setSelectedRow(record)}>
                      {columns.map((field) => (
                        <td key={field}>
                          {field === 'status' ? (
                            <span className={`admin-status admin-status-${String(record[field])}`}>{display(field, record[field])}</span>
                          ) : (
                            display(field, record[field])
                          )}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}

          <footer className="admin-pagination">
            <span>
              Page {page} of {pageCount}
            </span>
            <div>
              <button type="button" aria-label="Previous page" disabled={page <= 1 || loading} onClick={() => setPage((value) => value - 1)}>
                <ChevronLeft size={16} />
              </button>
              <button type="button" aria-label="Next page" disabled={page >= pageCount || loading} onClick={() => setPage((value) => value + 1)}>
                <ChevronRight size={16} />
              </button>
            </div>
          </footer>
        </section>
      )}

      {selectedRow && (
        <div className="admin-drawer-backdrop" onClick={() => setSelectedRow(null)}>
          <div className="admin-drawer" onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
              <h3 style={{ margin: 0, fontSize: 17, fontWeight: 850 }}>Record Details</h3>
              <button type="button" onClick={() => setSelectedRow(null)} className="admin-secondary-button">
                <X size={15} />
              </button>
            </div>
            <pre style={{ background: '#fcfaf6', border: '1px solid #e9e5dd', borderRadius: 10, padding: 14, fontSize: 12, overflowX: 'auto' }}>
              {JSON.stringify(selectedRow, null, 2)}
            </pre>
          </div>
        </div>
      )}
    </div>
  );
}
