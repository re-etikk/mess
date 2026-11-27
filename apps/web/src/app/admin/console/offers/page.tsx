'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import {
  AlertTriangle,
  Bell,
  CheckCircle2,
  Megaphone,
  Plus,
  RotateCw,
  Tag,
  Trash2,
} from 'lucide-react';

export default function AdminOffersPage() {
  const [tab, setTab] = useState<'promos' | 'banners' | 'broadcast'>('promos');
  const [promos, setPromos] = useState<any[]>([]);
  const [announcements, setAnnouncements] = useState<any[]>([]);
  const [providers, setProviders] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  // Promo form
  const [pCode, setPCode] = useState('');
  const [pTitle, setPTitle] = useState('');
  const [pDesc, setPDesc] = useState('');
  const [pProvider, setPProvider] = useState('');
  const [pType, setPType] = useState<'flat' | 'percent'>('flat');
  const [pAmount, setPAmount] = useState(50);
  const [pMaxCap, setPMaxCap] = useState('');
  const [pMinOrder, setPMinOrder] = useState(199);
  const [pLimit, setPLimit] = useState('');
  const [pPlans, setPPlans] = useState(true);
  const [pDaily, setPDaily] = useState(true);
  const [pFirstOrder, setPFirstOrder] = useState(false);
  const [pShowInApp, setPShowInApp] = useState(true);
  const [pValidUntil, setPValidUntil] = useState('');

  // Banner form
  const [bTitle, setBTitle] = useState('');
  const [bBody, setBBody] = useState('');
  const [bBadge, setBBadge] = useState('OFFER');
  const [bAudience, setBAudience] = useState<'all' | 'customer' | 'provider'>('customer');
  const [bPromo, setBPromo] = useState('');
  const [bFeatured, setBFeatured] = useState(true);

  // Broadcast form
  const [nAudience, setNAudience] = useState<'all_customers' | 'all_partners' | 'single_customer' | 'single_provider'>('all_customers');
  const [nTargetId, setNTargetId] = useState('');
  const [nTitle, setNTitle] = useState('');
  const [nMsg, setNMsg] = useState('');
  const [nType, setNType] = useState<'offer' | 'system' | 'menu_update'>('offer');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/admin/offers', { cache: 'no-store' });
      const data = await res.json();
      if (!res.ok || !data.success) throw new Error(data.error || 'Could not load offers.');
      setPromos(data.promos ?? []);
      setAnnouncements(data.announcements ?? []);
      setProviders(data.providers ?? []);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to load offers.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function createPromo(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/offers', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resource: 'promo',
          code: pCode.trim().toUpperCase(),
          title: pTitle.trim(),
          description: pDesc.trim() || undefined,
          provider_id: pProvider || null,
          discount_type: pType,
          flat_discount_inr: pType === 'flat' ? Number(pAmount) : 0,
          discount_percent: pType === 'percent' ? Number(pAmount) : 0,
          max_discount_inr: pType === 'percent' && pMaxCap ? Number(pMaxCap) : null,
          min_order_inr: Number(pMinOrder || 0),
          applicable_to_plans: pPlans,
          applicable_to_daily: pDaily,
          first_order_only: pFirstOrder,
          show_in_app: pShowInApp,
          usage_limit: pLimit ? Number(pLimit) : null,
          valid_until: pValidUntil ? new Date(`${pValidUntil}T23:59:59+05:30`).toISOString() : null,
          is_active: true,
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Promo creation failed.');
      setPCode('');
      setPTitle('');
      setPDesc('');
      setNotice(json.message);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Promo save failed.');
    } finally {
      setSaving(false);
    }
  }

  async function togglePromo(promo: any) {
    setSaving(true);
    try {
      await fetch('/api/admin/offers', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resource: 'promo',
          id: promo.id,
          code: promo.code,
          title: promo.title,
          description: promo.description || '',
          provider_id: promo.provider_id || null,
          discount_type: promo.discount_percent ? 'percent' : 'flat',
          flat_discount_inr: promo.flat_discount_paise ? Math.round(promo.flat_discount_paise / 100) : 0,
          discount_percent: promo.discount_percent || 0,
          max_discount_inr: promo.max_discount_paise ? Math.round(promo.max_discount_paise / 100) : null,
          min_order_inr: Math.round(Number(promo.min_order_paise || 0) / 100),
          applicable_to_plans: promo.applicable_to_plans !== false,
          applicable_to_daily: promo.applicable_to_daily !== false,
          first_order_only: promo.first_order_only === true,
          show_in_app: promo.show_in_app !== false,
          is_active: !promo.is_active,
        }),
      });
      await load();
    } finally {
      setSaving(false);
    }
  }

  async function removeItem(resource: 'promo' | 'announcement', id: string) {
    setSaving(true);
    try {
      await fetch(`/api/admin/offers?resource=${resource}&id=${encodeURIComponent(id)}`, { method: 'DELETE' });
      await load();
    } finally {
      setSaving(false);
    }
  }

  async function createBanner(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/offers', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resource: 'announcement',
          title: bTitle.trim(),
          body: bBody.trim(),
          badge_text: bBadge.trim() || 'OFFER',
          target_audience: bAudience,
          promo_code: bPromo.trim() ? bPromo.trim().toUpperCase() : null,
          is_featured: bFeatured,
          is_active: true,
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Banner creation failed.');
      setBTitle('');
      setBBody('');
      setBPromo('');
      setNotice('Banner published to live apps.');
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Banner save failed.');
    } finally {
      setSaving(false);
    }
  }

  async function sendBroadcast(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/offers', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resource: 'broadcast',
          audience: nAudience,
          target_id: nTargetId.trim() || undefined,
          title: nTitle.trim(),
          message: nMsg.trim(),
          notification_type: nType,
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Broadcast failed.');
      setNTitle('');
      setNMsg('');
      setNotice(json.message);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Broadcast failed.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="admin-page-stack">
      <header className="admin-page-heading">
        <div>
          <h2>Offers, Promo Codes & Banners</h2>
          <p>Launch platform-wide or kitchen-specific discounts, schedule Home screen promo banners, and push in-app notifications.</p>
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

      <div className="admin-operation-tabs" role="tablist">
        <button type="button" role="tab" aria-selected={tab === 'promos'} onClick={() => setTab('promos')}>
          Promo Codes ({promos.length})
        </button>
        <button type="button" role="tab" aria-selected={tab === 'banners'} onClick={() => setTab('banners')}>
          Home Banners ({announcements.length})
        </button>
        <button type="button" role="tab" aria-selected={tab === 'broadcast'} onClick={() => setTab('broadcast')}>
          Push / In-App Broadcast
        </button>
      </div>

      {tab === 'promos' && (
        <div className="admin-page-stack">
          <section className="admin-panel">
            <h3 className="admin-panel-title">Create New Promo Code</h3>
            <form onSubmit={createPromo} className="admin-page-stack">
              <div className="admin-field-grid">
                <div className="admin-field">
                  <label>Promo Code (e.g. THALI100)</label>
                  <input className="admin-input" required value={pCode} onChange={(e) => setPCode(e.target.value)} placeholder="FESTIVE50" />
                </div>
                <div className="admin-field">
                  <label>Offer Headline</label>
                  <input className="admin-input" required value={pTitle} onChange={(e) => setPTitle(e.target.value)} placeholder="Flat ₹50 Off on Weekly Passes" />
                </div>
                <div className="admin-field">
                  <label>Discount Type</label>
                  <select className="admin-select" value={pType} onChange={(e) => setPType(e.target.value as any)}>
                    <option value="flat">Flat Amount Off (₹)</option>
                    <option value="percent">Percentage Off (%)</option>
                  </select>
                </div>
                <div className="admin-field">
                  <label>{pType === 'flat' ? 'Discount Amount (₹)' : 'Discount Percent (%)'}</label>
                  <input type="number" className="admin-input" min={1} max={pType === 'percent' ? 90 : 5000} value={pAmount} onChange={(e) => setPAmount(Number(e.target.value))} />
                </div>
                {pType === 'percent' && (
                  <div className="admin-field">
                    <label>Max Discount Cap (₹, optional)</label>
                    <input type="number" className="admin-input" value={pMaxCap} onChange={(e) => setPMaxCap(e.target.value)} placeholder="150" />
                  </div>
                )}
                <div className="admin-field">
                  <label>Minimum Order Value (₹)</label>
                  <input type="number" className="admin-input" min={0} value={pMinOrder} onChange={(e) => setPMinOrder(Number(e.target.value))} />
                </div>
                <div className="admin-field">
                  <label>Kitchen Scope</label>
                  <select className="admin-select" value={pProvider} onChange={(e) => setPProvider(e.target.value)}>
                    <option value="">Platform-Wide (All Kitchens)</option>
                    {providers.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.display_name} ({p.city || 'India'})
                      </option>
                    ))}
                  </select>
                </div>
                <div className="admin-field">
                  <label>Total Usage Cap (optional)</label>
                  <input type="number" className="admin-input" value={pLimit} onChange={(e) => setPLimit(e.target.value)} placeholder="Unlimited" />
                </div>
                <div className="admin-field">
                  <label>Valid Until (optional)</label>
                  <input type="date" className="admin-input" value={pValidUntil} onChange={(e) => setPValidUntil(e.target.value)} />
                </div>
                <div className="admin-field">
                  <label>Description</label>
                  <input className="admin-input" value={pDesc} onChange={(e) => setPDesc(e.target.value)} placeholder="Valid on orders ₹199+" />
                </div>
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 16, fontSize: 13 }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <input type="checkbox" checked={pPlans} onChange={(e) => setPPlans(e.target.checked)} /> Valid on Subscription Plans
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <input type="checkbox" checked={pDaily} onChange={(e) => setPDaily(e.target.checked)} /> Valid on Single Meal Orders
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <input type="checkbox" checked={pFirstOrder} onChange={(e) => setPFirstOrder(e.target.checked)} /> First Order Only
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                  <input type="checkbox" checked={pShowInApp} onChange={(e) => setPShowInApp(e.target.checked)} /> Show Tappable Chip in Checkout
                </label>
              </div>
              <div>
                <button type="submit" disabled={saving} className="admin-primary-button">
                  <Plus size={14} /> Create Promo Code
                </button>
              </div>
            </form>
          </section>

          <section className="admin-table-panel">
            <div className="admin-table-wrap">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Code</th>
                    <th>Discount</th>
                    <th>Rules</th>
                    <th>Usage</th>
                    <th>Status</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {promos.map((pr) => (
                    <tr key={pr.id}>
                      <td>
                        <strong>{pr.code}</strong>
                        <small>{pr.title}</small>
                      </td>
                      <td>
                        {pr.flat_discount_paise
                          ? `₹${Math.round(pr.flat_discount_paise / 100)} Flat`
                          : `${pr.discount_percent || 0}% Off${pr.max_discount_paise ? ` (cap ₹${Math.round(pr.max_discount_paise / 100)})` : ''}`}
                        <small>Min ₹{Math.round(Number(pr.min_order_paise || 0) / 100)}</small>
                      </td>
                      <td>
                        <small>
                          {pr.provider_id ? 'Single Kitchen' : 'All Kitchens'} · {pr.first_order_only ? '1st Order' : 'All Users'}
                        </small>
                      </td>
                      <td>
                        {pr.times_used || 0} / {pr.usage_limit ?? '∞'}
                      </td>
                      <td>
                        <span className={`admin-status ${pr.is_active ? 'admin-status-active' : 'admin-status-expired'}`}>
                          {pr.is_active ? 'Active' : 'Paused'}
                        </span>
                      </td>
                      <td>
                        <div className="admin-actions-row">
                          <button type="button" onClick={() => void togglePromo(pr)} className="admin-secondary-button">
                            {pr.is_active ? 'Pause' : 'Enable'}
                          </button>
                          <button type="button" onClick={() => void removeItem('promo', pr.id)} className="admin-danger-button">
                            <Trash2 size={13} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </div>
      )}

      {tab === 'banners' && (
        <div className="admin-page-stack">
          <section className="admin-panel">
            <h3 className="admin-panel-title">Publish Home Promo Banner / Announcement</h3>
            <form onSubmit={createBanner} className="admin-page-stack">
              <div className="admin-field-grid">
                <div className="admin-field">
                  <label>Banner Headline</label>
                  <input className="admin-input" required value={bTitle} onChange={(e) => setBTitle(e.target.value)} placeholder="Save ₹50 on Your First Monthly Tiffin" />
                </div>
                <div className="admin-field">
                  <label>Badge Tag</label>
                  <input className="admin-input" value={bBadge} onChange={(e) => setBBadge(e.target.value)} placeholder="FESTIVAL OFFER" />
                </div>
                <div className="admin-field">
                  <label>Target Audience</label>
                  <select className="admin-select" value={bAudience} onChange={(e) => setBAudience(e.target.value as any)}>
                    <option value="customer">Customer App & Web</option>
                    <option value="provider">Partner App & Web</option>
                    <option value="all">Both Apps</option>
                  </select>
                </div>
                <div className="admin-field">
                  <label>Promo Code Attached (optional)</label>
                  <input className="admin-input" value={bPromo} onChange={(e) => setBPromo(e.target.value)} placeholder="THALI50" />
                </div>
              </div>
              <div className="admin-field">
                <label>Subtitle / Copy</label>
                <input className="admin-input" required value={bBody} onChange={(e) => setBBody(e.target.value)} placeholder="Use code THALI50 at checkout on orders ₹500+." />
              </div>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
                <input type="checkbox" checked={bFeatured} onChange={(e) => setBFeatured(e.target.checked)} /> Feature prominently at top of Home
              </label>
              <div>
                <button type="submit" disabled={saving} className="admin-primary-button">
                  <Megaphone size={14} /> Publish Banner
                </button>
              </div>
            </form>
          </section>

          <section className="admin-table-panel">
            <div className="admin-table-wrap">
              <table className="admin-data-table">
                <thead>
                  <tr>
                    <th>Banner</th>
                    <th>Audience</th>
                    <th>Promo</th>
                    <th>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {announcements.map((a) => (
                    <tr key={a.id}>
                      <td>
                        <strong>{a.title}</strong>
                        <small>{a.body}</small>
                      </td>
                      <td>
                        <span className="admin-status admin-status-active">{a.target_audience || 'all'}</span>
                      </td>
                      <td>{a.promo_code || '—'}</td>
                      <td>
                        <button type="button" onClick={() => void removeItem('announcement', a.id)} className="admin-danger-button">
                          <Trash2 size={13} /> Delete
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        </div>
      )}

      {tab === 'broadcast' && (
        <section className="admin-panel" style={{ maxWidth: 680 }}>
          <h3 className="admin-panel-title">Send Targeted In-App Notification</h3>
          <form onSubmit={sendBroadcast} className="admin-page-stack">
            <div className="admin-field-grid">
              <div className="admin-field">
                <label>Audience</label>
                <select className="admin-select" value={nAudience} onChange={(e) => setNAudience(e.target.value as any)}>
                  <option value="all_customers">All Active Customers</option>
                  <option value="all_partners">All Active Kitchen Partners</option>
                  <option value="single_customer">Specific Customer UUID</option>
                  <option value="single_provider">Specific Kitchen UUID</option>
                </select>
              </div>
              <div className="admin-field">
                <label>Notification Category</label>
                <select className="admin-select" value={nType} onChange={(e) => setNType(e.target.value as any)}>
                  <option value="offer">Offer / Deal</option>
                  <option value="system">Platform Update</option>
                  <option value="menu_update">Menu Highlight</option>
                </select>
              </div>
            </div>
            {(nAudience === 'single_customer' || nAudience === 'single_provider') && (
              <div className="admin-field">
                <label>Target User / Kitchen UUID</label>
                <input className="admin-input" required value={nTargetId} onChange={(e) => setNTargetId(e.target.value)} />
              </div>
            )}
            <div className="admin-field">
              <label>Notification Title</label>
              <input className="admin-input" required value={nTitle} onChange={(e) => setNTitle(e.target.value)} placeholder="Weekend Special: ₹50 Off Lunch!" />
            </div>
            <div className="admin-field">
              <label>Message Body</label>
              <textarea className="admin-textarea" required value={nMsg} onChange={(e) => setNMsg(e.target.value)} />
            </div>
            <div>
              <button type="submit" disabled={saving} className="admin-primary-button">
                <Bell size={14} /> Dispatch Broadcast
              </button>
            </div>
          </form>
        </section>
      )}
    </div>
  );
}
