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
  Headset,
  IndianRupee,
  RotateCw,
  SlidersHorizontal,
  Store,
  Tag,
  Users,
} from 'lucide-react';

type Overview = {
  success: true;
  admin_role: string;
  as_of: string;
  timezone: string;
  providers: { total: number; active: number; pending: number; suspended: number };
  customers: { total: number };
  subscriptions: { total: number; active: number; expired: number };
  orders: { total: number; open: number };
  redemptions: { total: number; today: number };
  payments: { total: number; succeeded: number; failed: number; pending: number; verified_gmv_inr: number };
  refunds: { pending: number };
  settlements: { pending: number };
  support: { open: number; urgent: number };
  offers: { active_promos: number; active_announcements: number };
};

const numberFormat = new Intl.NumberFormat('en-IN');

function Metric({
  label,
  value,
  detail,
  icon: Icon,
  href,
  tone = 'orange',
}: {
  label: string;
  value: string;
  detail: string;
  icon: LucideIcon;
  href?: string;
  tone?: 'orange' | 'green' | 'blue' | 'red';
}) {
  const content = (
    <article className="admin-metric-card">
      <div className={`admin-metric-icon admin-metric-${tone}`}>
        <Icon size={18} />
      </div>
      <p className="admin-metric-label">{label}</p>
      <p className="admin-metric-value">{value}</p>
      <p className="admin-metric-detail">{detail}</p>
    </article>
  );
  return href ? (
    <Link href={href} className="admin-metric-anchor">
      {content}
    </Link>
  ) : (
    content
  );
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

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <div className="admin-page-stack">
      <header className="admin-page-heading">
        <div>
          <h2>Platform Overview</h2>
          <p>Live operational metrics, ticket alerts, verified payments, and marketplace shortcuts.</p>
        </div>
        <button type="button" onClick={() => void load()} disabled={loading} className="admin-secondary-button">
          <RotateCw size={15} className={loading ? 'animate-spin' : ''} /> Refresh
        </button>
      </header>

      {error && (
        <div role="alert" className="admin-error">
          <AlertTriangle size={18} />
          <div>
            <strong>Could not load the live overview.</strong>
            <p>{error}</p>
            <button type="button" onClick={() => void load()}>
              Retry
            </button>
          </div>
        </div>
      )}

      {loading && !data ? (
        <div className="admin-metric-grid" aria-label="Loading overview">
          {Array.from({ length: 8 }, (_, idx) => (
            <div key={idx} className="admin-loading-panel" />
          ))}
        </div>
      ) : null}

      {data && (
        <>
          <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: 8, fontSize: 12, color: '#6b7280' }}>
            <span style={{ display: 'inline-flex', alignItems: 'center', gap: 6 }}>
              <Activity size={14} /> Updated{' '}
              {new Date(data.as_of).toLocaleString('en-IN', {
                dateStyle: 'medium',
                timeStyle: 'short',
                timeZone: data.timezone,
              })}
            </span>
            <span>Access Level: {data.admin_role.replace('_', ' ')}</span>
          </div>

          <section aria-label="Platform metrics" className="admin-metric-grid">
            <Metric
              label="Verified Cashfree GMV"
              value={`₹${numberFormat.format(data.payments.verified_gmv_inr || 0)}`}
              detail={`${numberFormat.format(data.payments.succeeded)} paid · ${numberFormat.format(data.payments.failed)} failed`}
              icon={IndianRupee}
              href="/admin/console/finance"
              tone="green"
            />
            <Metric
              label="Open Support Tickets"
              value={numberFormat.format(data.support.open)}
              detail={`${numberFormat.format(data.support.urgent)} high/urgent awaiting reply`}
              icon={Headset}
              href="/admin/console/support"
              tone={data.support.urgent > 0 ? 'red' : 'blue'}
            />
            <Metric
              label="Mess Partners"
              value={numberFormat.format(data.providers.active)}
              detail={`${numberFormat.format(data.providers.pending)} pending KYC · ${numberFormat.format(data.providers.suspended)} suspended`}
              icon={Store}
              href="/admin/console/partners"
            />
            <Metric
              label="Customers"
              value={numberFormat.format(data.customers.total)}
              detail="Registered customer profiles"
              icon={Users}
              href="/admin/console/customers"
              tone="green"
            />
            <Metric
              label="Active Subscriptions"
              value={numberFormat.format(data.subscriptions.active)}
              detail={`${numberFormat.format(data.subscriptions.total)} total · ${numberFormat.format(data.subscriptions.expired)} expired`}
              icon={CreditCard}
              href="/admin/console/subscriptions"
            />
            <Metric
              label="Meals Redeemed Today"
              value={numberFormat.format(data.redemptions.today)}
              detail={`${numberFormat.format(data.redemptions.total)} total historical scans`}
              icon={CheckCircle2}
              href="/admin/console/operations"
              tone="green"
            />
            <Metric
              label="Active Promos & Banners"
              value={numberFormat.format(data.offers.active_promos)}
              detail={`${numberFormat.format(data.offers.active_announcements)} live customer banners`}
              icon={Tag}
              href="/admin/console/offers"
              tone="blue"
            />
            <Metric
              label="Pending Settlements & Refunds"
              value={numberFormat.format(data.settlements.pending + data.refunds.pending)}
              detail={`${numberFormat.format(data.settlements.pending)} payouts · ${numberFormat.format(data.refunds.pending)} refunds`}
              icon={Building2}
              href="/admin/console/finance"
              tone="blue"
            />
          </section>

          <section className="admin-panel">
            <h3 className="admin-panel-title">Priority Operations</h3>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
              <Link href="/admin/console/support" className="admin-primary-button" style={{ textDecoration: 'none' }}>
                <Headset size={15} /> Open Support Desk ({data.support.open})
              </Link>
              <Link href="/admin/console/partners" className="admin-secondary-button" style={{ textDecoration: 'none' }}>
                <Store size={15} /> Review Kitchen Approvals ({data.providers.pending})
              </Link>
              <Link href="/admin/console/offers" className="admin-secondary-button" style={{ textDecoration: 'none' }}>
                <Tag size={15} /> Manage Offers & Banners
              </Link>
              <Link href="/admin/console/customize" className="admin-secondary-button" style={{ textDecoration: 'none' }}>
                <SlidersHorizontal size={15} /> Customize App & Fees
              </Link>
              <Link href="/admin/console/finance" className="admin-secondary-button" style={{ textDecoration: 'none' }}>
                <ClipboardList size={15} /> Settlements & Refunds <ArrowRight size={14} />
              </Link>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
