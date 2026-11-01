'use client';

import { useCallback, useEffect, useState } from 'react';
import { AlertTriangle, ChevronLeft, ChevronRight, RotateCw } from 'lucide-react';

const tabs = [
  ['bookings', 'Bookings'], ['redemptions', 'Redemptions'], ['payments', 'Payments'], ['refunds', 'Refunds'],
  ['settlements', 'Settlements'], ['support', 'Support'], ['audit', 'Audit log'],
] as const;
type Source = (typeof tabs)[number][0];
type RecordRow = Record<string, string | number | null>;
const statuses: Partial<Record<Source, string[]>> = {
  bookings: ['draft', 'pending_payment', 'confirmed', 'ready', 'assigned', 'accepted', 'picked_up', 'redeemed', 'delivered', 'cancelled', 'missed', 'failed_delivery', 'refund_pending', 'refunded'],
  payments: ['created', 'pending', 'succeeded', 'failed', 'cancelled'], refunds: ['requested', 'pending', 'succeeded', 'failed', 'rejected'],
  settlements: ['draft', 'pending', 'processing', 'paid', 'failed', 'cancelled'], support: ['open', 'triaged', 'in_progress', 'waiting_for_user', 'resolved', 'closed'],
};
const labels: Record<string, string> = {
  id: 'Record ID', customer_id: 'Customer', provider_id: 'Partner', booking_id: 'Booking', subscription_id: 'Subscription',
  payment_transaction_id: 'Payment', created_by: 'Created by', about_user_id: 'About user', assigned_to: 'Assigned to', redeemed_by: 'Redeemed by',
  status: 'Status', booking_type: 'Type', fulfillment_mode: 'Fulfillment', total_due_paise: 'Amount', amount_paise: 'Amount',
  gross_food_paise: 'Gross food', commission_paise: 'Commission', refund_paise: 'Refunds', adjustment_paise: 'Adjustment', net_payable_paise: 'Net payable',
  purpose: 'Purpose', gateway_name: 'Gateway', currency: 'Currency', verified_at: 'Verified', created_at: 'Created', updated_at: 'Updated',
  requested_at: 'Requested', completed_at: 'Completed', settled_at: 'Settled', redeemed_at: 'Redeemed', resolved_at: 'Resolved',
  service_date: 'Service date', period_start: 'Period start', period_end: 'Period end', meal_slot_id: 'Meal slot', confirmation_method: 'Confirmation',
  category: 'Category', subject: 'Subject', priority: 'Priority', reason_code: 'Reason code', actor_user_id: 'Actor', action: 'Action',
  subject_type: 'Subject type', subject_id: 'Subject ID', reason: 'Reason', request_id: 'Request ID', processed_by: 'Processed by',
};
const dateFields = new Set(['created_at', 'updated_at', 'requested_at', 'completed_at', 'settled_at', 'redeemed_at', 'resolved_at', 'verified_at']);
const paiseFields = new Set(['total_due_paise', 'amount_paise', 'gross_food_paise', 'commission_paise', 'refund_paise', 'adjustment_paise', 'net_payable_paise']);
const idFields = new Set(['id', 'customer_id', 'provider_id', 'booking_id', 'subscription_id', 'payment_transaction_id', 'created_by', 'about_user_id', 'assigned_to', 'redeemed_by', 'subject_id', 'meal_slot_id', 'request_id', 'actor_user_id', 'processed_by']);
const money = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 });
function display(field: string, value: string | number | null) {
  if (value === null || value === '') return '—';
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
  const load = useCallback(async () => {
    setLoading(true); setError('');
    try {
      const params = new URLSearchParams({ source, page: String(page), page_size: '20' });
      if (status) params.set('status', status);
      const response = await fetch(`/api/admin/operations?${params}`, { cache: 'no-store' });
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(result.error || 'Operations records are unavailable.');
      setRecords(result.records ?? []); setTotal(result.total ?? 0);
    } catch (cause) { setRecords([]); setTotal(0); setError(cause instanceof Error ? cause.message : 'Operations records are unavailable.'); }
    finally { setLoading(false); }
  }, [source, status, page]);
  useEffect(() => { void load(); }, [load]);
  function selectSource(next: Source) { setSource(next); setStatus(''); setPage(1); }
  const columns = records.length ? Object.keys(records[0]) : [];
  const pageCount = Math.max(1, Math.ceil(total / 20));

  return <div className="admin-page-stack">
    <header className="admin-page-heading"><div><p className="admin-eyebrow">PERSISTED RECORDS · READ ONLY</p><h2>Operations</h2><p>Inspect bookings, redemptions, payments, refunds, settlements, support tickets and admin actions from the shared database.</p></div><button type="button" onClick={() => void load()} disabled={loading} className="admin-secondary-button"><RotateCw size={15} className={loading ? 'animate-spin' : ''} /> Refresh</button></header>
    <div className="admin-operation-tabs" role="tablist" aria-label="Operations record type">{tabs.map(([key, label]) => <button type="button" role="tab" aria-selected={source === key} key={key} onClick={() => selectSource(key)}>{label}</button>)}</div>
    <section className="admin-table-panel" aria-label={`${source} records`}>
      <div className="admin-table-toolbar"><strong className="admin-ops-title">{tabs.find(([key]) => key === source)?.[1]}</strong>{statuses[source] && <label className="admin-filter-label">Status<select value={status} onChange={(event) => { setStatus(event.target.value); setPage(1); }}><option value="">All statuses</option>{statuses[source]?.map((value) => <option key={value} value={value}>{value.replaceAll('_', ' ')}</option>)}</select></label>}<span className="admin-record-count">{total.toLocaleString('en-IN')} records</span></div>
      {error && <div role="alert" className="admin-error"><AlertTriangle size={18} /><div><strong>Records unavailable</strong><p>{error}</p><button type="button" onClick={() => void load()}>Retry</button></div></div>}
      {loading ? <div className="admin-loading-table" aria-label="Loading operations records">{Array.from({ length: 6 }, (_, i) => <div key={i} />)}</div> : error ? null : records.length === 0 ? <div className="admin-empty"><h3>No {source} records</h3><p>There are no matching records in the database.</p></div> : <div className="admin-table-wrap"><table className="admin-data-table"><thead><tr>{columns.map((field) => <th key={field}>{labels[field] ?? field.replaceAll('_', ' ')}</th>)}</tr></thead><tbody>{records.map((record, index) => <tr key={String(record.id ?? index)}>{columns.map((field) => <td key={field}>{field === 'status' ? <span className={`admin-status admin-status-${String(record[field])}`}>{display(field, record[field])}</span> : display(field, record[field])}</td>)}</tr>)}</tbody></table></div>}
      <footer className="admin-pagination"><span>Page {page} of {pageCount}</span><div><button type="button" aria-label="Previous page" disabled={page <= 1 || loading} onClick={() => setPage((value) => value - 1)}><ChevronLeft size={16} /></button><button type="button" aria-label="Next page" disabled={page >= pageCount || loading} onClick={() => setPage((value) => value + 1)}><ChevronRight size={16} /></button></div></footer>
    </section>
  </div>;
}
