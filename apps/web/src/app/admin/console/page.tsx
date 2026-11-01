'use client';

import Link from 'next/link';
import { useCallback, useEffect, useState } from 'react';
import type { LucideIcon } from 'lucide-react';
import {
  Activity,
  AlertTriangle,
  ArrowRight,
  Building2,
  CheckCircle2,
  ClipboardList,
  CreditCard,
  RotateCw,
  Store,
  Users,
} from 'lucide-react';

type Overview = {
  success: true;
  as_of: string;
  timezone: string;
  providers: { total: number; active: number; pending: number };
  customers: { total: number };
  subscriptions: { total: number; active: number; expired: number };
  orders: { total: number; open: number };
  redemptions: { total: number; today: number };
  payments: { total: number; succeeded: number; failed: number; pending: number };
  refunds: { pending: number };
  settlements: { pending: number };
};

const numberFormat = new Intl.NumberFormat('en-IN');

function Metric({ label, value, detail, icon: Icon, href, tone = 'orange' }: {
  label: string; value: number; detail: string; icon: LucideIcon; href?: string; tone?: 'orange' | 'green' | 'blue' | 'red';
}) {
  const content = <article className="admin-metric-card">
    <div className={`admin-metric-icon admin-metric-${tone}`}><Icon size={18} /></div>
    <p className="admin-metric-label">{label}</p>
    <p className="admin-metric-value">{numberFormat.format(value)}</p>
    <p className="admin-metric-detail">{detail}</p>
    {href && <span className="admin-metric-link">View records <ArrowRight size={13} /></span>}
  </article>;
  return href ? <Link href={href} className="admin-metric-anchor">{content}</Link> : content;
}

export default function AdminOverviewPage() {
  const [data, setData] = useState<Overview | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const response = await fetch('/api/admin/metrics', { cache: 'no-store' });
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(result.error || 'Overview data is unavailable.');
      setData(result);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Overview data is unavailable.');
      setData(null);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  return <div className="admin-page-stack">
    <header className="admin-page-heading">
      <div><p className="admin-eyebrow">REAL-TIME PLATFORM RECORDS</p><h2>Overview</h2><p>Operational counts from the shared Thali database. Financial amounts are kept separate and are not estimated here.</p></div>
      <button type="button" onClick={() => void load()} disabled={loading} className="admin-secondary-button"><RotateCw size={15} className={loading ? 'animate-spin' : ''} /> Refresh</button>
    </header>

    {error && <div role="alert" className="admin-error"><AlertTriangle size={18} /><div><strong>Could not load the live overview.</strong><p>{error}</p><button type="button" onClick={() => void load()}>Retry</button></div></div>}

    {loading && !data ? <div className="admin-metric-grid" aria-label="Loading overview"><div className="admin-loading-panel" /><div className="admin-loading-panel" /><div className="admin-loading-panel" /><div className="admin-loading-panel" /><div className="admin-loading-panel" /><div className="admin-loading-panel" /></div> : null}

    {data && <>
      <div className="admin-overview-meta"><span><Activity size={14} /> Counts as of {new Date(data.as_of).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short', timeZone: data.timezone })} · {data.timezone}</span><span>Refresh to fetch current records</span></div>
      <section aria-label="Platform metrics" className="admin-metric-grid">
        <Metric label="Mess partners" value={data.providers.total} detail={`${numberFormat.format(data.providers.active)} active`} icon={Store} href="/admin/console/partners" />
        <Metric label="Pending approvals" value={data.providers.pending} detail="Applications awaiting review" icon={Building2} href="/admin/console/partners" tone="blue" />
        <Metric label="Customers" value={data.customers.total} detail="Current customer roles" icon={Users} href="/admin/console/customers" tone="green" />
        <Metric label="Active subscriptions" value={data.subscriptions.active} detail={`${numberFormat.format(data.subscriptions.expired)} expired`} icon={CreditCard} href="/admin/console/subscriptions" />
        <Metric label="Open bookings" value={data.orders.open} detail={`${numberFormat.format(data.orders.total)} total bookings`} icon={ClipboardList} tone="blue" />
        <Metric label="Redemptions today" value={data.redemptions.today} detail={`${numberFormat.format(data.redemptions.total)} persisted redemptions`} icon={CheckCircle2} tone="green" />
        <Metric label="Successful payments" value={data.payments.succeeded} detail={`${numberFormat.format(data.payments.total)} transactions total`} icon={CreditCard} tone="green" />
        <Metric label="Failed payments" value={data.payments.failed} detail={`${numberFormat.format(data.payments.pending)} created or pending`} icon={AlertTriangle} tone="red" />
        <Metric label="Pending refunds" value={data.refunds.pending} detail="Requested or pending state" icon={RotateCw} tone="blue" />
        <Metric label="Pending settlements" value={data.settlements.pending} detail="Draft, pending, or processing" icon={Building2} tone="blue" />
      </section>
      <section className="admin-info-panel">
        <div className="admin-info-icon"><AlertTriangle size={18} /></div>
        <div><h3>Financial overview is intentionally limited</h3><p>This page shows transaction and settlement counts only. GMV, platform commission, refunds, and partner net payable need verified ledger definitions and bounded aggregate queries before being reported as money totals.</p></div>
      </section>
      <section className="admin-quick-links">
        <div><p className="admin-eyebrow">WORK QUEUES</p><h3>Continue platform operations</h3></div>
        <Link href="/admin/console/partners">Review partner applications <ArrowRight size={15} /></Link>
        <Link href="/admin/console/customers">Open customer directory <ArrowRight size={15} /></Link>
        <Link href="/admin/console/subscriptions">Inspect subscriptions <ArrowRight size={15} /></Link>
      </section>
    </>}
  </div>;
}
