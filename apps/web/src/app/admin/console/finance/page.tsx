'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import {
  AlertTriangle,
  Building2,
  Check,
  CheckCircle2,
  IndianRupee,
  Plus,
  RotateCw,
} from 'lucide-react';

const money = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 2 });

export default function AdminFinancePage() {
  const [summary, setSummary] = useState<any>(null);
  const [settlements, setSettlements] = useState<any[]>([]);
  const [refunds, setRefunds] = useState<any[]>([]);
  const [providers, setProviders] = useState<any[]>([]);
  const [tab, setTab] = useState<'settlements' | 'refunds'>('settlements');

  const [provId, setProvId] = useState('');
  const [start, setStart] = useState(new Date(Date.now() - 7 * 86400000).toISOString().slice(0, 10));
  const [end, setEnd] = useState(new Date().toISOString().slice(0, 10));
  const [grossInr, setGrossInr] = useState(0);
  const [commInr, setCommInr] = useState(0);
  const [payoutRefs, setPayoutRefs] = useState<Record<string, string>>({});

  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/admin/finance', { cache: 'no-store' });
      const data = await res.json();
      if (!res.ok || !data.success) throw new Error(data.error || 'Could not load finance data.');
      setSummary(data.summary);
      setSettlements(data.settlements ?? []);
      setRefunds(data.refunds ?? []);
      setProviders(data.providers ?? []);
      if (!provId && data.providers?.[0]?.id) setProvId(data.providers[0].id);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to load finance records.');
    } finally {
      setLoading(false);
    }
  }, [provId]);

  useEffect(() => {
    void load();
  }, [load]);

  async function createSettlement(e: FormEvent) {
    e.preventDefault();
    if (!provId) return;
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/finance', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'create_settlement',
          provider_id: provId,
          period_start: start,
          period_end: end,
          gross_food_paise: Math.round(grossInr * 100),
          commission_paise: Math.round(commInr * 100),
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Settlement creation failed.');
      setNotice('Settlement payout batch created cleanly.');
      setGrossInr(0);
      setCommInr(0);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to create settlement.');
    } finally {
      setBusy(false);
    }
  }

  async function markSettlementPaid(settlementId: string) {
    const ref = (payoutRefs[settlementId] || '').trim();
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/finance', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'mark_settlement_paid',
          settlement_id: settlementId,
          status: 'paid',
          gateway_payout_reference: ref || `UTR-${Date.now().toString().slice(-8)}`,
          reason: 'Settled by Thali Finance desk',
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Update failed.');
      setNotice('Settlement marked paid & partner notified.');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Settlement payout update failed.');
    } finally {
      setBusy(false);
    }
  }

  async function decideRefund(refundId: string, decision: 'approve' | 'reject') {
    setBusy(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/finance', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action: 'process_refund',
          refund_id: refundId,
          decision,
          reason: decision === 'approve' ? 'Approved by Finance Desk' : 'Rejected after ledger verification',
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Refund update failed.');
      setNotice(json.message);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Refund processing failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="admin-page-stack">
      <header className="admin-page-heading">
        <div>
          <h2>Finance, Settlements & Refunds</h2>
          <p>Reconcile verified Cashfree collections, issue partner payout settlements, and process refund requests.</p>
        </div>
        <button type="button" onClick={() => void load()} disabled={loading} className="admin-secondary-button">
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

      {summary && (
        <section className="admin-metric-grid">
          <article className="admin-metric-card">
            <div className="admin-metric-icon admin-metric-green">
              <IndianRupee size={18} />
            </div>
            <p className="admin-metric-label">Verified Online GMV</p>
            <p className="admin-metric-value">{money.format(summary.verified_gmv_paise / 100)}</p>
            <p className="admin-metric-detail">{summary.succeeded_tx_count} succeeded transactions</p>
          </article>
          <article className="admin-metric-card">
            <div className="admin-metric-icon admin-metric-blue">
              <Building2 size={18} />
            </div>
            <p className="admin-metric-label">Total Settled Payouts</p>
            <p className="admin-metric-value">{money.format(summary.total_settled_paise / 100)}</p>
            <p className="admin-metric-detail">{settlements.length} settlement batches</p>
          </article>
          <article className="admin-metric-card">
            <div className="admin-metric-icon admin-metric-red">
              <RotateCw size={18} />
            </div>
            <p className="admin-metric-label">Completed Refunds</p>
            <p className="admin-metric-value">{money.format(summary.total_refunded_paise / 100)}</p>
            <p className="admin-metric-detail">{refunds.length} total refund tickets</p>
          </article>
          <article className="admin-metric-card">
            <div className="admin-metric-icon">
              <IndianRupee size={18} />
            </div>
            <p className="admin-metric-label">Default Commission</p>
            <p className="admin-metric-value">{(summary.default_commission_bps / 100).toFixed(1)}%</p>
            <p className="admin-metric-detail">Configurable in App Customize</p>
          </article>
        </section>
      )}

      <div className="admin-operation-tabs" role="tablist">
        <button type="button" role="tab" aria-selected={tab === 'settlements'} onClick={() => setTab('settlements')}>
          Partner Settlements ({settlements.length})
        </button>
        <button type="button" role="tab" aria-selected={tab === 'refunds'} onClick={() => setTab('refunds')}>
          Refund Queue ({refunds.length})
        </button>
      </div>

      {tab === 'settlements' && (
        <div className="admin-page-stack">
          <section className="admin-panel">
            <h3 className="admin-panel-title">Create Partner Settlement Batch</h3>
            <form onSubmit={createSettlement} className="admin-field-grid">
              <div className="admin-field">
                <label>Kitchen Partner</label>
                <select className="admin-select" value={provId} onChange={(e) => setProvId(e.target.value)}>
                  {providers.map((p) => (
                    <option key={p.id} value={p.id}>
                      {p.display_name}
                    </option>
                  ))}
                </select>
              </div>
              <div className="admin-field">
                <label>Gross Food Amount (₹)</label>
                <input type="number" className="admin-input" min={0} value={grossInr} onChange={(e) => setGrossInr(Number(e.target.value))} />
              </div>
              <div className="admin-field">
                <label>Period Start</label>
                <input type="date" className="admin-input" value={start} onChange={(e) => setStart(e.target.value)} />
              </div>
              <div className="admin-field">
                <label>Period End</label>
                <input type="date" className="admin-input" value={end} onChange={(e) => setEnd(e.target.value)} />
              </div>
              <div className="admin-field">
                <label>Commission Deduction (₹)</label>
                <input type="number" className="admin-input" min={0} value={commInr} onChange={(e) => setCommInr(Number(e.target.value))} />
              </div>
              <div style={{ display: 'flex', alignItems: 'flex-end' }}>
                <button type="submit" disabled={busy} className="admin-primary-button">
                  <Plus size={14} /> Create Batch
                </button>
              </div>
            </form>
          </section>

          <section className="admin-table-panel">
            <div className="admin-table-wrap">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Kitchen & Period</th>
                    <th>Gross</th>
                    <th>Commission</th>
                    <th>Net Payable</th>
                    <th>Status</th>
                    <th>Payout Ref / Action</th>
                  </tr>
                </thead>
                <tbody>
                  {settlements.map((s) => (
                    <tr key={s.id}>
                      <td>
                        <strong>{s.provider_name}</strong>
                        <small>
                          {s.period_start} &rarr; {s.period_end}
                        </small>
                      </td>
                      <td>{money.format(s.gross_food_paise / 100)}</td>
                      <td>{money.format(s.commission_paise / 100)}</td>
                      <td>
                        <strong>{money.format(s.net_payable_paise / 100)}</strong>
                      </td>
                      <td>
                        <span className={`admin-status admin-status-${s.status}`}>{s.status}</span>
                      </td>
                      <td>
                        {s.status === 'paid' ? (
                          <code>{s.gateway_payout_reference || 'Paid'}</code>
                        ) : (
                          <div style={{ display: 'flex', gap: 6 }}>
                            <input
                              className="admin-input"
                              style={{ minWidth: 120 }}
                              placeholder="UTR / Ref"
                              value={payoutRefs[s.id] || ''}
                              onChange={(e) => setPayoutRefs((prev) => ({ ...prev, [s.id]: e.target.value }))}
                            />
                            <button type="button" disabled={busy} onClick={() => void markSettlementPaid(s.id)} className="admin-primary-button">
                              <Check size={13} /> Mark Paid
                            </button>
                          </div>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </div>
      )}

      {tab === 'refunds' && (
        <section className="admin-table-panel">
          <div className="admin-table-wrap">
            <table className="admin-data-table">
              <thead>
                <tr>
                  <th>Refund ID</th>
                  <th>Amount</th>
                  <th>Reason</th>
                  <th>Status</th>
                  <th>Decision</th>
                </tr>
              </thead>
              <tbody>
                {refunds.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <code>{r.id}</code>
                      <small>TXN: {r.payment_transaction_id?.slice(0, 8)}…</small>
                    </td>
                    <td>
                      <strong>{money.format(Number(r.amount_paise || 0) / 100)}</strong>
                    </td>
                    <td>{r.reason_note || r.reason_code}</td>
                    <td>
                      <span className={`admin-status admin-status-${r.status}`}>{r.status}</span>
                    </td>
                    <td>
                      {r.status === 'requested' || r.status === 'pending' ? (
                        <div className="admin-actions-row">
                          <button type="button" disabled={busy} onClick={() => void decideRefund(r.id, 'approve')} className="admin-primary-button">
                            Approve
                          </button>
                          <button type="button" disabled={busy} onClick={() => void decideRefund(r.id, 'reject')} className="admin-danger-button">
                            Reject
                          </button>
                        </div>
                      ) : (
                        <small>{r.completed_at ? new Date(r.completed_at).toLocaleDateString('en-IN') : 'Closed'}</small>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  );
}
