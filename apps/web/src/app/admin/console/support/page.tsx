'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import {
  AlertTriangle,
  CheckCircle2,
  Gift,
  Headset,
  MessageSquare,
  RotateCw,
  Search,
  Send,
} from 'lucide-react';

interface Ticket {
  id: string;
  category: string;
  subject: string;
  description: string;
  status: string;
  priority: string;
  requester_name?: string;
  requester_email?: string;
  requester_phone?: string;
  requester_role?: string;
  provider_id?: string | null;
  resolution_note?: string | null;
  resolution_action?: string | null;
  promo_code_granted?: string | null;
  created_at: string;
  updated_at: string;
}

interface TicketMsg {
  id: string;
  sender_role: string;
  sender_name: string;
  message: string;
  is_internal: boolean;
  created_at: string;
}

export default function AdminSupportPage() {
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const [statusFilter, setStatusFilter] = useState('');
  const [roleFilter, setRoleFilter] = useState('');
  const [query, setQuery] = useState('');
  const [appliedQ, setAppliedQ] = useState('');

  const [selectedId, setSelectedId] = useState<string>('');
  const [detail, setDetail] = useState<{
    ticket: Ticket;
    messages: TicketMsg[];
    requester_profile: any;
    provider_info: any;
    related_subscriptions: any[];
  } | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  const [replyText, setReplyText] = useState('');
  const [isInternal, setIsInternal] = useState(false);
  const [replyNextStatus, setReplyNextStatus] = useState('');
  const [compType, setCompType] = useState<'none' | 'apology_coupon' | 'extend_subscription' | 'refund_request'>('none');
  const [couponInr, setCouponInr] = useState(50);
  const [extendDays, setExtendDays] = useState(3);
  const [selectedSubId, setSelectedSubId] = useState('');
  const [resolutionNote, setResolutionNote] = useState('');
  const [busy, setBusy] = useState(false);

  const loadQueue = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const p = new URLSearchParams({ page_size: '30' });
      if (statusFilter) p.set('status', statusFilter);
      if (roleFilter) p.set('role', roleFilter);
      if (appliedQ) p.set('q', appliedQ);
      const res = await fetch(`/api/admin/support?${p}`, { cache: 'no-store' });
      const data = await res.json();
      if (!res.ok || !data.success) throw new Error(data.error || 'Unable to load support tickets.');
      setTickets(data.tickets ?? []);
      setTotal(data.total ?? 0);
      if (!selectedId && data.tickets?.[0]?.id) {
        setSelectedId(data.tickets[0].id);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to load support tickets.');
    } finally {
      setLoading(false);
    }
  }, [statusFilter, roleFilter, appliedQ, selectedId]);

  const loadDetail = useCallback(async (id: string) => {
    if (!id) {
      setDetail(null);
      return;
    }
    setDetailLoading(true);
    try {
      const res = await fetch(`/api/admin/support?ticket_id=${encodeURIComponent(id)}`, { cache: 'no-store' });
      const data = await res.json();
      if (res.ok && data.success) {
        setDetail({
          ticket: data.ticket,
          messages: data.messages ?? [],
          requester_profile: data.requester_profile,
          provider_info: data.provider_info,
          related_subscriptions: data.related_subscriptions ?? [],
        });
        setSelectedSubId(data.related_subscriptions?.[0]?.id || '');
      }
    } finally {
      setDetailLoading(false);
    }
  }, []);

  useEffect(() => {
    void loadQueue();
  }, [loadQueue]);

  useEffect(() => {
    if (selectedId) void loadDetail(selectedId);
  }, [selectedId, loadDetail]);

  function onSearch(e: FormEvent) {
    e.preventDefault();
    setAppliedQ(query.trim());
  }

  async function sendReply(e: FormEvent) {
    e.preventDefault();
    if (!detail || replyText.trim().length < 2) return;
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/support', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ticket_id: detail.ticket.id,
          action: 'reply',
          message: replyText.trim(),
          is_internal: isInternal,
          ...(replyNextStatus ? { next_status: replyNextStatus } : {}),
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Reply could not be sent.');
      setReplyText('');
      setNotice(json.message || 'Reply dispatched.');
      await Promise.all([loadQueue(), loadDetail(detail.ticket.id)]);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Reply failed.');
    } finally {
      setBusy(false);
    }
  }

  async function updateMeta(next: { status?: string; priority?: string }) {
    if (!detail) return;
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/support', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ticket_id: detail.ticket.id,
          action: 'update_meta',
          ...next,
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Could not update ticket.');
      setNotice('Ticket status updated.');
      await Promise.all([loadQueue(), loadDetail(detail.ticket.id)]);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Ticket update failed.');
    } finally {
      setBusy(false);
    }
  }

  async function resolveWithAction(e: FormEvent) {
    e.preventDefault();
    if (!detail || resolutionNote.trim().length < 3) {
      setError('Enter a clear resolution summary (at least 3 characters).');
      return;
    }
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/support', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          ticket_id: detail.ticket.id,
          action: 'resolve_with_compensation',
          resolution_note: resolutionNote.trim(),
          compensation_type: compType,
          coupon_amount_inr: couponInr,
          extend_days: extendDays,
          ...(selectedSubId ? { subscription_id: selectedSubId } : {}),
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Resolution failed.');
      setResolutionNote('');
      setNotice(json.promo_code ? `Resolved & issued promo code ${json.promo_code}` : 'Ticket resolved cleanly.');
      await Promise.all([loadQueue(), loadDetail(detail.ticket.id)]);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Resolution failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="admin-page-stack">
      <header className="admin-page-heading">
        <div>
          <h2>Customer & Partner Support Desk</h2>
          <p>Respond to raised tickets, add internal audit notes, grant courtesy coupons, extend passes, or close cases.</p>
        </div>
        <button type="button" onClick={() => void loadQueue()} disabled={loading} className="admin-secondary-button">
          <RotateCw size={15} className={loading ? 'animate-spin' : ''} /> Refresh
        </button>
      </header>

      {error && (
        <div role="alert" className="admin-error">
          <AlertTriangle size={17} />
          <span>{error}</span>
        </div>
      )}
      {notice && (
        <div className="admin-notice-success">
          <CheckCircle2 size={17} />
          <span>{notice}</span>
        </div>
      )}

      <section className="admin-panel" style={{ padding: '12px 15px' }}>
        <form onSubmit={onSearch} style={{ display: 'flex', flexWrap: 'wrap', gap: 10, alignItems: 'center' }}>
          <label className="admin-search">
            <Search size={15} />
            <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search subject, name, email or ID" />
          </label>
          <select className="admin-select" style={{ width: 'auto' }} value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)}>
            <option value="">All Roles</option>
            <option value="customer">Customer</option>
            <option value="provider">Partner</option>
          </select>
          <select className="admin-select" style={{ width: 'auto' }} value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
            <option value="">All Statuses</option>
            <option value="open">Open</option>
            <option value="in_progress">In Progress</option>
            <option value="waiting_for_user">Waiting For User</option>
            <option value="resolved">Resolved</option>
            <option value="closed">Closed</option>
          </select>
          <button type="submit" className="admin-primary-button">
            Filter
          </button>
          <span className="admin-record-count">{total} tickets</span>
        </form>
      </section>

      <div className="admin-split-workbench">
        <aside className="admin-table-panel" style={{ maxHeight: '72vh', overflowY: 'auto' }}>
          {loading && tickets.length === 0 ? (
            <div className="admin-loading-table">
              <div />
              <div />
              <div />
            </div>
          ) : tickets.length === 0 ? (
            <div className="admin-empty">
              <Headset size={22} />
              <h3>No matching tickets</h3>
              <p>Customer and Partner tickets submitted in apps or /contact appear here.</p>
            </div>
          ) : (
            <div>
              {tickets.map((t) => {
                const active = selectedId === t.id;
                return (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => setSelectedId(t.id)}
                    style={{
                      width: '100%',
                      textAlign: 'left',
                      padding: '13px 15px',
                      border: 0,
                      borderBottom: '1px solid #f0ede7',
                      background: active ? '#fff8eb' : '#fff',
                      cursor: 'pointer',
                    }}
                  >
                    <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'center' }}>
                      <span className={`admin-status admin-status-${t.status}`}>{t.status.replaceAll('_', ' ')}</span>
                      <span className={`admin-status admin-status-${t.priority}`}>{t.priority}</span>
                    </div>
                    <strong style={{ display: 'block', marginTop: 7, fontSize: 13, color: '#18222a' }}>{t.subject}</strong>
                    <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4, fontSize: 11, color: '#6b7280' }}>
                      <span>
                        {t.requester_name || 'User'} · {(t.requester_role || 'customer').toUpperCase()}
                      </span>
                      <span>{new Date(t.created_at).toLocaleDateString('en-IN')}</span>
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </aside>

        <section className="admin-panel">
          {!selectedId || !detail ? (
            <div className="admin-empty">
              <MessageSquare size={22} />
              <h3>{detailLoading ? 'Loading ticket conversation...' : 'Select a ticket to inspect'}</h3>
              <p>Read the full history, reply to the requester, or resolve with a coupon/extension.</p>
            </div>
          ) : (
            <div className="admin-page-stack">
              <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'space-between', gap: 12, borderBottom: '1px solid #f0ede7', paddingBottom: 14 }}>
                <div>
                  <h3 style={{ margin: 0, fontSize: 17, fontWeight: 850 }}>{detail.ticket.subject}</h3>
                  <p style={{ margin: '4px 0 0', fontSize: 12, color: '#5a646d' }}>
                    From <strong>{detail.ticket.requester_name || 'User'}</strong> ({detail.ticket.requester_role || 'customer'}) ·{' '}
                    {detail.ticket.requester_email || 'No email'} · {detail.ticket.requester_phone || 'No phone'}
                  </p>
                  {detail.provider_info && (
                    <p style={{ margin: '3px 0 0', fontSize: 11, color: '#805100' }}>
                      Kitchen: {detail.provider_info.display_name} ({detail.provider_info.status})
                    </p>
                  )}
                </div>
                <div className="admin-actions-row">
                  <select
                    className="admin-select"
                    style={{ width: 'auto' }}
                    value={detail.ticket.priority}
                    disabled={busy}
                    onChange={(e) => void updateMeta({ priority: e.target.value })}
                  >
                    <option value="low">Low Priority</option>
                    <option value="normal">Normal Priority</option>
                    <option value="high">High Priority</option>
                    <option value="urgent">Urgent Priority</option>
                  </select>
                  <select
                    className="admin-select"
                    style={{ width: 'auto' }}
                    value={detail.ticket.status}
                    disabled={busy}
                    onChange={(e) => void updateMeta({ status: e.target.value })}
                  >
                    <option value="open">Open</option>
                    <option value="triaged">Triaged</option>
                    <option value="in_progress">In Progress</option>
                    <option value="waiting_for_user">Waiting For User</option>
                    <option value="resolved">Resolved</option>
                    <option value="closed">Closed</option>
                  </select>
                </div>
              </div>

              <div style={{ background: '#fcfaf6', border: '1px solid #ece7dc', borderRadius: 10, padding: 14, display: 'grid', gap: 10, maxHeight: 320, overflowY: 'auto' }}>
                {detail.messages.length === 0 ? (
                  <div style={{ fontSize: 13, whiteSpace: 'pre-wrap' }}>{detail.ticket.description}</div>
                ) : (
                  detail.messages.map((m) => (
                    <div
                      key={m.id}
                      style={{
                        background: m.is_internal ? '#fff8e6' : m.sender_role === 'admin' ? '#eef6ff' : '#fff',
                        border: '1px solid #e7e2d8',
                        borderRadius: 9,
                        padding: '10px 12px',
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 11, color: '#5a646d', marginBottom: 4 }}>
                        <strong>
                          {m.sender_name} ({m.sender_role}) {m.is_internal ? '· INTERNAL NOTE' : ''}
                        </strong>
                        <span>{new Date(m.created_at).toLocaleString('en-IN', { dateStyle: 'short', timeStyle: 'short' })}</span>
                      </div>
                      <p style={{ margin: 0, fontSize: 13, whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>{m.message}</p>
                    </div>
                  ))
                )}
              </div>

              <form onSubmit={sendReply} style={{ display: 'grid', gap: 10 }}>
                <textarea
                  className="admin-textarea"
                  value={replyText}
                  onChange={(e) => setReplyText(e.target.value)}
                  placeholder={isInternal ? 'Write internal ops/support note (hidden from user)...' : 'Write reply visible to the customer/partner...'}
                />
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, justifyContent: 'space-between', alignItems: 'center' }}>
                  <div className="admin-actions-row">
                    <label style={{ display: 'inline-flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
                      <input type="checkbox" checked={isInternal} onChange={(e) => setIsInternal(e.target.checked)} />
                      Internal Note Only
                    </label>
                    <select className="admin-select" style={{ width: 'auto' }} value={replyNextStatus} onChange={(e) => setReplyNextStatus(e.target.value)}>
                      <option value="">Auto Status</option>
                      <option value="waiting_for_user">Waiting For User</option>
                      <option value="in_progress">In Progress</option>
                      <option value="resolved">Mark Resolved</option>
                    </select>
                  </div>
                  <button type="submit" disabled={busy || replyText.trim().length < 2} className="admin-primary-button">
                    <Send size={14} /> {isInternal ? 'Save Note' : 'Send Public Reply'}
                  </button>
                </div>
              </form>

              <form onSubmit={resolveWithAction} style={{ borderTop: '1px solid #f0ede7', paddingTop: 14, display: 'grid', gap: 10 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontWeight: 800, fontSize: 13 }}>
                  <Gift size={15} /> Resolve & Issue Action
                </div>
                <div className="admin-field-grid">
                  <div className="admin-field">
                    <label>Compensation / Action</label>
                    <select className="admin-select" value={compType} onChange={(e) => setCompType(e.target.value as any)}>
                      <option value="none">Resolve Without Compensation</option>
                      <option value="apology_coupon">Issue Single-Use Apology Coupon</option>
                      <option value="extend_subscription">Extend Active Pass Days</option>
                      <option value="refund_request">Queue Refund Request (if payment linked)</option>
                    </select>
                  </div>
                  {compType === 'apology_coupon' && (
                    <div className="admin-field">
                      <label>Coupon Discount (₹)</label>
                      <input type="number" className="admin-input" min={10} max={2000} value={couponInr} onChange={(e) => setCouponInr(Number(e.target.value))} />
                    </div>
                  )}
                  {compType === 'extend_subscription' && (
                    <>
                      <div className="admin-field">
                        <label>Target Subscription</label>
                        <select className="admin-select" value={selectedSubId} onChange={(e) => setSelectedSubId(e.target.value)}>
                          <option value="">Select subscription...</option>
                          {detail.related_subscriptions.map((s) => (
                            <option key={s.id} value={s.id}>
                              {s.plan_name_snapshot} ({s.status})
                            </option>
                          ))}
                        </select>
                      </div>
                      <div className="admin-field">
                        <label>Extend By Days</label>
                        <input type="number" className="admin-input" min={1} max={90} value={extendDays} onChange={(e) => setExtendDays(Number(e.target.value))} />
                      </div>
                    </>
                  )}
                </div>
                <div className="admin-field">
                  <label>Resolution Summary</label>
                  <input
                    className="admin-input"
                    value={resolutionNote}
                    onChange={(e) => setResolutionNote(e.target.value)}
                    placeholder="e.g. Verified missing meal, extended pass by 3 days & notified customer"
                  />
                </div>
                <div>
                  <button type="submit" disabled={busy} className="admin-primary-button">
                    <CheckCircle2 size={14} /> Resolve Ticket
                  </button>
                </div>
              </form>
            </div>
          )}
        </section>
      </div>
    </div>
  );
}
