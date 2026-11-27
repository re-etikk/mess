'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import {
  AlertTriangle,
  Check,
  CheckCircle2,
  RotateCw,
  Save,
  Search,
  ShieldAlert,
  Sparkles,
  Store,
  X,
} from 'lucide-react';

type BillingSettings = {
  free_trial_days: number;
  fee_per_90_successful_redemptions_inr: number;
  usage_billing_enabled: boolean;
  updated_at: string;
};

type BillingAccount = {
  provider_id: string;
  provider_name: string;
  provider_status: string;
  trial_started_at: string | null;
  trial_ends_at: string | null;
  billing_exempt: boolean;
  exempt_reason: string | null;
  admin_note: string | null;
};

type ProviderRow = {
  id: string;
  display_name: string;
  public_phone: string | null;
  public_email: string | null;
  description: string | null;
  address_line1: string | null;
  locality: string | null;
  city: string | null;
  state: string | null;
  pincode: string | null;
  status: string;
  is_accepting_orders?: boolean;
  is_featured?: boolean;
  featured_rank?: number;
  is_verified_badge?: boolean;
  commission_bps_override?: number | null;
  suspension_reason?: string | null;
  created_at: string;
};

function dateInputValue(value: string | null) {
  return value ? new Date(value).toISOString().slice(0, 10) : '';
}

export default function AdminPartnersPage() {
  const [tab, setTab] = useState<'pending' | 'directory' | 'policy'>('pending');
  const [applications, setApplications] = useState<ProviderRow[]>([]);
  const [directory, setDirectory] = useState<ProviderRow[]>([]);
  const [billingMap, setBillingMap] = useState<Record<string, BillingAccount>>({});
  const [settings, setSettings] = useState<BillingSettings | null>(null);
  const [statusFilter, setStatusFilter] = useState('all');
  const [query, setQuery] = useState('');
  const [appliedQ, setAppliedQ] = useState('');
  const [reviewReasons, setReviewReasons] = useState<Record<string, string>>({});

  const [drawerProv, setDrawerProv] = useState<ProviderRow | null>(null);
  const [dFeatured, setDFeatured] = useState(false);
  const [dRank, setDRank] = useState(100);
  const [dVerified, setDVerified] = useState(false);
  const [dAccepting, setDAccepting] = useState(true);
  const [dCommBps, setDCommBps] = useState('');
  const [dModReason, setDModReason] = useState('');
  const [dTrialEnd, setDTrialEnd] = useState('');
  const [dExempt, setDExempt] = useState(false);
  const [dExemptReason, setDExemptReason] = useState('');
  const [dAdminNote, setDAdminNote] = useState('');

  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const p = new URLSearchParams({ all: 'true', page_size: '50', status: statusFilter });
      if (appliedQ) p.set('q', appliedQ);
      const [provRes, bilRes] = await Promise.all([
        fetch(`/api/admin/providers?${p}`, { cache: 'no-store' }),
        fetch('/api/admin/billing?page=1&page_size=50', { cache: 'no-store' }),
      ]);
      const [provData, bilData] = await Promise.all([provRes.json(), bilRes.json()]);
      if (!provRes.ok || !provData.success) throw new Error(provData.error || 'Could not load kitchens.');
      setApplications(provData.applications ?? []);
      setDirectory(provData.active_providers ?? []);
      if (bilRes.ok && bilData.settings) setSettings(bilData.settings);
      if (bilRes.ok && Array.isArray(bilData.providers)) {
        const map: Record<string, BillingAccount> = {};
        for (const acc of bilData.providers) map[acc.provider_id] = acc;
        setBillingMap(map);
      }
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to load partner data.');
    } finally {
      setLoading(false);
    }
  }, [statusFilter, appliedQ]);

  useEffect(() => {
    void load();
  }, [load]);

  function openDrawer(p: ProviderRow) {
    setDrawerProv(p);
    setDFeatured(p.is_featured === true);
    setDRank(Number(p.featured_rank ?? 100));
    setDVerified(p.is_verified_badge === true);
    setDAccepting(p.is_accepting_orders !== false);
    setDCommBps(p.commission_bps_override != null ? String(p.commission_bps_override) : '');
    setDModReason('');
    const bil = billingMap[p.id];
    setDTrialEnd(dateInputValue(bil?.trial_ends_at || null));
    setDExempt(bil?.billing_exempt === true);
    setDExemptReason(bil?.exempt_reason || '');
    setDAdminNote(bil?.admin_note || '');
  }

  async function decideApplication(app: ProviderRow, decision: 'approve' | 'reject') {
    const reason = (reviewReasons[app.id] || '').trim();
    if (reason.length < 3) {
      setError(`Enter a clear reason (at least 3 characters) to ${decision} ${app.display_name}.`);
      return;
    }
    setSaving(true);
    setError('');
    setMessage('');
    try {
      const res = await fetch('/api/admin/providers', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider_id: app.id, decision, reason }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Decision failed.');
      setMessage(`${app.display_name} ${decision}d cleanly.`);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Decision failed.');
    } finally {
      setSaving(false);
    }
  }

  async function saveDrawerControls(e: FormEvent) {
    e.preventDefault();
    if (!drawerProv) return;
    setSaving(true);
    setError('');
    setMessage('');
    try {
      const res = await fetch('/api/admin/providers', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: drawerProv.id,
          action: 'update_controls',
          is_featured: dFeatured,
          featured_rank: Number(dRank) || 100,
          is_verified_badge: dVerified,
          is_accepting_orders: dAccepting,
          commission_bps_override: dCommBps.trim() ? Number(dCommBps) : null,
          reason: dModReason.trim() || 'Updated kitchen ranking/commission controls',
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Controls update failed.');

      if (billingMap[drawerProv.id]) {
        if (dExempt && dExemptReason.trim().length < 3) {
          throw new Error('Billing exemption requires a reason of at least 3 characters.');
        }
        const bilRes = await fetch('/api/admin/billing', {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            provider_id: drawerProv.id,
            trial_ends_at: dTrialEnd ? new Date(`${dTrialEnd}T23:59:59+05:30`).toISOString() : undefined,
            billing_exempt: dExempt,
            exempt_reason: dExemptReason.trim() || null,
            admin_note: dAdminNote.trim() || null,
          }),
        });
        const bilJson = await bilRes.json();
        if (!bilRes.ok) throw new Error(bilJson.error || 'Billing settings save failed.');
      }

      setMessage(`Controls & billing saved for ${drawerProv.display_name}.`);
      setDrawerProv(null);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed.');
    } finally {
      setSaving(false);
    }
  }

  async function toggleSuspension(action: 'suspend' | 'reactivate') {
    if (!drawerProv) return;
    if (dModReason.trim().length < 3) {
      setError('Enter a reason (min 3 chars) before suspending or reactivating a kitchen.');
      return;
    }
    setSaving(true);
    setError('');
    setMessage('');
    try {
      const res = await fetch('/api/admin/providers', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: drawerProv.id,
          action,
          reason: dModReason.trim(),
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Action failed.');
      setMessage(json.message);
      setDrawerProv(null);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Action failed.');
    } finally {
      setSaving(false);
    }
  }

  async function saveGlobalPolicy(e: FormEvent) {
    e.preventDefault();
    if (!settings) return;
    setSaving(true);
    setError('');
    setMessage('');
    try {
      const res = await fetch('/api/admin/billing', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          free_trial_days: Number(settings.free_trial_days),
          fee_per_90_successful_redemptions_inr: Number(settings.fee_per_90_successful_redemptions_inr),
          usage_billing_enabled: settings.usage_billing_enabled,
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Policy update failed.');
      setSettings(json.settings);
      setMessage('Default usage billing policy saved.');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Policy update failed.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="admin-page-stack">
      <header className="admin-page-heading">
        <div>
          <h2>Partner Kitchens & Onboarding</h2>
          <p>Review applications, spotlight top kitchens, set per-kitchen commission overrides, manage trials, or suspend non-compliant kitchens.</p>
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
      {message && (
        <div className="admin-notice-success">
          <CheckCircle2 size={17} />
          <span>{message}</span>
        </div>
      )}

      <div className="admin-operation-tabs" role="tablist">
        <button type="button" role="tab" aria-selected={tab === 'pending'} onClick={() => setTab('pending')}>
          Onboarding Queue ({applications.length})
        </button>
        <button type="button" role="tab" aria-selected={tab === 'directory'} onClick={() => setTab('directory')}>
          Kitchens Directory ({directory.length})
        </button>
        <button type="button" role="tab" aria-selected={tab === 'policy'} onClick={() => setTab('policy')}>
          Global Usage Billing Policy
        </button>
      </div>

      {tab === 'pending' && (
        <section className="admin-page-stack">
          {applications.length === 0 ? (
            <div className="admin-panel admin-empty">
              <Store size={24} />
              <h3>No pending partner applications</h3>
              <p>New kitchen signups awaiting verification will appear here.</p>
            </div>
          ) : (
            applications.map((app) => (
              <article key={app.id} className="admin-panel" style={{ display: 'grid', gap: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12 }}>
                  <div>
                    <h3 style={{ margin: 0, fontSize: 16, fontWeight: 850 }}>{app.display_name}</h3>
                    <p style={{ margin: '4px 0 0', fontSize: 12, color: '#5a646d' }}>
                      {app.address_line1}, {app.locality}, {app.city}, {app.state} - {app.pincode}
                    </p>
                    <p style={{ margin: '3px 0 0', fontSize: 12, color: '#425059' }}>
                      Phone: <strong>{app.public_phone || 'Not provided'}</strong> · Email:{' '}
                      <strong>{app.public_email || 'Not provided'}</strong>
                    </p>
                  </div>
                  <span className="admin-status admin-status-pending_review">Pending Review</span>
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, alignItems: 'center' }}>
                  <input
                    className="admin-input"
                    style={{ flex: 1, minWidth: 220 }}
                    placeholder="Verification / rejection reason (required)"
                    value={reviewReasons[app.id] || ''}
                    onChange={(e) => setReviewReasons((prev) => ({ ...prev, [app.id]: e.target.value }))}
                  />
                  <button type="button" disabled={saving} onClick={() => void decideApplication(app, 'approve')} className="admin-primary-button">
                    <Check size={14} /> Approve Kitchen
                  </button>
                  <button type="button" disabled={saving} onClick={() => void decideApplication(app, 'reject')} className="admin-danger-button">
                    <X size={14} /> Reject
                  </button>
                </div>
              </article>
            ))
          )}
        </section>
      )}

      {tab === 'directory' && (
        <section className="admin-table-panel">
          <form
            onSubmit={(e) => {
              e.preventDefault();
              setAppliedQ(query.trim());
            }}
            className="admin-table-toolbar"
          >
            <label className="admin-search">
              <Search size={15} />
              <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search kitchen name, locality, city..." />
            </label>
            <select className="admin-select" style={{ width: 'auto' }} value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
              <option value="all">All Non-Pending</option>
              <option value="active">Active</option>
              <option value="suspended">Suspended</option>
              <option value="rejected">Rejected</option>
            </select>
            <button type="submit" className="admin-primary-button">
              Filter
            </button>
            <span className="admin-record-count">{directory.length} kitchens</span>
          </form>

          {directory.length === 0 ? (
            <div className="admin-empty">
              <Store size={22} />
              <h3>No kitchens found</h3>
              <p>Try adjusting search or status filters.</p>
            </div>
          ) : (
            <div className="admin-table-wrap">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Kitchen</th>
                    <th>Contact</th>
                    <th>Status</th>
                    <th>Spotlight & Badges</th>
                    <th>Commission / Trial</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {directory.map((p) => {
                    const bil = billingMap[p.id];
                    return (
                      <tr key={p.id}>
                        <td>
                          <strong>{p.display_name}</strong>
                          <small>
                            {p.locality || p.city || 'India'} · {p.city || ''}
                          </small>
                        </td>
                        <td>
                          <strong>{p.public_phone || '—'}</strong>
                          <small>{p.public_email || '—'}</small>
                        </td>
                        <td>
                          <span className={`admin-status admin-status-${p.status}`}>{p.status}</span>
                          {p.is_accepting_orders === false && <small>Closed Today</small>}
                        </td>
                        <td>
                          {p.is_featured ? (
                            <span className="admin-status admin-status-active">Featured #{p.featured_rank ?? 100}</span>
                          ) : (
                            <small>Standard</small>
                          )}
                          {p.is_verified_badge && <small>Verified Badge</small>}
                        </td>
                        <td>
                          <strong>{p.commission_bps_override != null ? `${(p.commission_bps_override / 100).toFixed(1)}%` : 'Global Default'}</strong>
                          <small>{bil?.billing_exempt ? 'Billing Exempt' : bil?.trial_ends_at ? `Trial -> ${dateInputValue(bil.trial_ends_at)}` : '—'}</small>
                        </td>
                        <td>
                          <button type="button" onClick={() => openDrawer(p)} className="admin-secondary-button">
                            Manage
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </section>
      )}

      {tab === 'policy' && settings && (
        <section className="admin-panel">
          <h3 className="admin-panel-title">Platform Usage Billing Policy</h3>
          <form onSubmit={saveGlobalPolicy} className="admin-page-stack" style={{ maxWidth: 640 }}>
            <div className="admin-field-grid">
              <div className="admin-field">
                <label>Default Free Trial (Days)</label>
                <input
                  type="number"
                  className="admin-input"
                  value={settings.free_trial_days}
                  onChange={(e) => setSettings({ ...settings, free_trial_days: Number(e.target.value) })}
                />
              </div>
              <div className="admin-field">
                <label>Fee per 90 Verified Check-Ins (₹)</label>
                <input
                  type="number"
                  className="admin-input"
                  value={settings.fee_per_90_successful_redemptions_inr}
                  onChange={(e) => setSettings({ ...settings, fee_per_90_successful_redemptions_inr: Number(e.target.value) })}
                />
              </div>
            </div>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
              <input
                type="checkbox"
                checked={settings.usage_billing_enabled}
                onChange={(e) => setSettings({ ...settings, usage_billing_enabled: e.target.checked })}
              />
              Enable automatic usage billing invoices after free trial
            </label>
            <div>
              <button type="submit" disabled={saving} className="admin-primary-button">
                <Save size={14} /> Save Global Billing Policy
              </button>
            </div>
          </form>
        </section>
      )}

      {drawerProv && (
        <div className="admin-drawer-backdrop" onClick={() => setDrawerProv(null)}>
          <div className="admin-drawer" onClick={(e) => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <div>
                <h3 style={{ margin: 0, fontSize: 18, fontWeight: 850 }}>{drawerProv.display_name}</h3>
                <p style={{ margin: '4px 0 0', fontSize: 12, color: '#5a646d' }}>{drawerProv.city} · Status: {drawerProv.status}</p>
              </div>
              <button type="button" onClick={() => setDrawerProv(null)} className="admin-secondary-button">
                <X size={15} />
              </button>
            </div>

            <form onSubmit={saveDrawerControls} className="admin-page-stack">
              <div className="admin-panel" style={{ padding: 14, display: 'grid', gap: 10 }}>
                <strong style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 13 }}>
                  <Sparkles size={15} /> Discovery & Commission Controls
                </strong>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
                  <input type="checkbox" checked={dFeatured} onChange={(e) => setDFeatured(e.target.checked)} />
                  Spotlight as Featured Kitchen on Customer Home
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
                  <input type="checkbox" checked={dVerified} onChange={(e) => setDVerified(e.target.checked)} />
                  Show Verified Hygiene & FSSAI Badge
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
                  <input type="checkbox" checked={dAccepting} onChange={(e) => setDAccepting(e.target.checked)} />
                  Kitchen Currently Open Accepting Orders
                </label>
                <div className="admin-field-grid">
                  <div className="admin-field">
                    <label>Spotlight Rank (1 = top)</label>
                    <input type="number" className="admin-input" min={1} max={999} value={dRank} onChange={(e) => setDRank(Number(e.target.value))} />
                  </div>
                  <div className="admin-field">
                    <label>Commission Override (BPS, 100 = 1%)</label>
                    <input
                      type="number"
                      className="admin-input"
                      min={0}
                      max={5000}
                      placeholder="Blank = Global default"
                      value={dCommBps}
                      onChange={(e) => setDCommBps(e.target.value)}
                    />
                  </div>
                </div>
              </div>

              {billingMap[drawerProv.id] && (
                <div className="admin-panel" style={{ padding: 14, display: 'grid', gap: 10 }}>
                  <strong style={{ fontSize: 13 }}>Usage Billing & Trial</strong>
                  <div className="admin-field">
                    <label>Free Trial Ends On</label>
                    <input type="date" className="admin-input" value={dTrialEnd} onChange={(e) => setDTrialEnd(e.target.value)} />
                  </div>
                  <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
                    <input type="checkbox" checked={dExempt} onChange={(e) => setDExempt(e.target.checked)} />
                    Exempt this partner from usage fees
                  </label>
                  <div className="admin-field">
                    <label>Exemption Reason (Required if exempt)</label>
                    <input className="admin-input" value={dExemptReason} onChange={(e) => setDExemptReason(e.target.value)} placeholder="Launch partner agreement..." />
                  </div>
                  <div className="admin-field">
                    <label>Internal Admin Note</label>
                    <textarea className="admin-textarea" value={dAdminNote} onChange={(e) => setDAdminNote(e.target.value)} />
                  </div>
                </div>
              )}

              <div className="admin-field">
                <label>Audit Reason (Required for Suspend / Reactivate)</label>
                <input className="admin-input" value={dModReason} onChange={(e) => setDModReason(e.target.value)} placeholder="State reason for audit log..." />
              </div>

              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                <button type="submit" disabled={saving} className="admin-primary-button">
                  <Save size={14} /> Save Controls
                </button>
                {drawerProv.status === 'active' ? (
                  <button type="button" disabled={saving} onClick={() => void toggleSuspension('suspend')} className="admin-danger-button">
                    <ShieldAlert size={14} /> Suspend Kitchen
                  </button>
                ) : (
                  <button type="button" disabled={saving} onClick={() => void toggleSuspension('reactivate')} className="admin-secondary-button">
                    <Check size={14} /> Reactivate Kitchen
                  </button>
                )}
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
