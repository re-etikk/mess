'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import {
  AlertTriangle,
  CheckCircle2,
  Plus,
  RotateCw,
  Save,
  SlidersHorizontal,
  X,
} from 'lucide-react';
import type { PlatformAppConfig } from '@/lib/app-config';

export default function AdminCustomizePage() {
  const [cfg, setCfg] = useState<PlatformAppConfig | null>(null);
  const [newCity, setNewCity] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');

  const load = useCallback(async () => {
    setLoading(true);
    setError('');
    try {
      const res = await fetch('/api/admin/customize', { cache: 'no-store' });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Could not load app customization.');
      setCfg(json.config);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to load configuration.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function save(e: FormEvent) {
    e.preventDefault();
    if (!cfg) return;
    setSaving(true);
    setError('');
    setNotice('');
    try {
      const res = await fetch('/api/admin/customize', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(cfg),
      });
      const json = await res.json();
      if (!res.ok || !json.success) throw new Error(json.error || 'Save failed.');
      setCfg(json.config);
      setNotice('Live app customization & marketplace settings updated across web and mobile.');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save configuration.');
    } finally {
      setSaving(false);
    }
  }

  function addCity() {
    const clean = newCity.trim();
    if (!clean || !cfg) return;
    if (!cfg.active_cities.includes(clean)) {
      setCfg({ ...cfg, active_cities: [...cfg.active_cities, clean] });
    }
    setNewCity('');
  }

  return (
    <div className="admin-page-stack">
      <header className="admin-page-heading">
        <div>
          <h2>App Customization & Platform Controls</h2>
          <p>Remotely control Customer & Partner app hero messaging, active cities, fees, feature flags, approval workflow, and maintenance mode.</p>
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

      {cfg && (
        <form onSubmit={save} className="admin-page-stack">
          <section className="admin-panel">
            <h3 className="admin-panel-title">Customer Home & Merchandising Copy</h3>
            <div className="admin-field-grid">
              <div className="admin-field">
                <label>Hero Headline</label>
                <input className="admin-input" value={cfg.hero_title} onChange={(e) => setCfg({ ...cfg, hero_title: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Hero Badge Label</label>
                <input className="admin-input" value={cfg.hero_badge} onChange={(e) => setCfg({ ...cfg, hero_badge: e.target.value })} />
              </div>
            </div>
            <div className="admin-field" style={{ marginTop: 12 }}>
              <label>Hero Subtitle</label>
              <input className="admin-input" value={cfg.hero_subtitle} onChange={(e) => setCfg({ ...cfg, hero_subtitle: e.target.value })} />
            </div>
          </section>

          <section className="admin-panel">
            <h3 className="admin-panel-title">Active Operating Cities</h3>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
              {cfg.active_cities.map((c) => (
                <span key={c} className="admin-status admin-status-active" style={{ gap: 6, paddingRight: 6 }}>
                  {c}
                  <button
                    type="button"
                    onClick={() => setCfg({ ...cfg, active_cities: cfg.active_cities.filter((x) => x !== c) })}
                    style={{ border: 0, background: 'transparent', cursor: 'pointer', padding: 0, color: 'inherit' }}
                    aria-label={`Remove ${c}`}
                  >
                    <X size={12} />
                  </button>
                </span>
              ))}
            </div>
            <div style={{ display: 'flex', gap: 8, maxWidth: 360 }}>
              <input className="admin-input" value={newCity} onChange={(e) => setNewCity(e.target.value)} placeholder="Add city (e.g. Jaipur)" />
              <button type="button" onClick={addCity} className="admin-secondary-button">
                <Plus size={14} /> Add
              </button>
            </div>
          </section>

          <section className="admin-panel">
            <h3 className="admin-panel-title">Marketplace Fees & Commission Rules</h3>
            <div className="admin-field-grid">
              <div className="admin-field">
                <label>Customer Platform Fee (₹)</label>
                <input
                  type="number"
                  className="admin-input"
                  min={0}
                  max={500}
                  value={Math.round(cfg.platform_fee_paise / 100)}
                  onChange={(e) => setCfg({ ...cfg, platform_fee_paise: Math.max(0, Number(e.target.value) * 100) })}
                />
              </div>
              <div className="admin-field">
                <label>Default Delivery Fee (₹)</label>
                <input
                  type="number"
                  className="admin-input"
                  min={0}
                  max={500}
                  value={Math.round(cfg.default_delivery_fee_paise / 100)}
                  onChange={(e) => setCfg({ ...cfg, default_delivery_fee_paise: Math.max(0, Number(e.target.value) * 100) })}
                />
              </div>
              <div className="admin-field">
                <label>Free Delivery Above Order (₹, 0 = none)</label>
                <input
                  type="number"
                  className="admin-input"
                  min={0}
                  max={5000}
                  value={Math.round(cfg.free_delivery_above_paise / 100)}
                  onChange={(e) => setCfg({ ...cfg, free_delivery_above_paise: Math.max(0, Number(e.target.value) * 100) })}
                />
              </div>
              <div className="admin-field">
                <label>Default Partner Commission (BPS, 1000 = 10%)</label>
                <input
                  type="number"
                  className="admin-input"
                  min={0}
                  max={5000}
                  value={cfg.default_commission_bps}
                  onChange={(e) => setCfg({ ...cfg, default_commission_bps: Math.max(0, Number(e.target.value)) })}
                />
              </div>
            </div>
          </section>

          <section className="admin-panel">
            <h3 className="admin-panel-title">Feature Flags, Onboarding & Maintenance</h3>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 10, fontSize: 13, marginBottom: 14 }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <input
                  type="checkbox"
                  checked={cfg.require_provider_approval}
                  onChange={(e) => setCfg({ ...cfg, require_provider_approval: e.target.checked })}
                />
                Require Admin Review Before Kitchen Goes Live
              </label>
              {(
                [
                  ['single_meal_orders', 'Single-Meal Orders Enabled'],
                  ['cash_at_counter', 'Pay Cash at Counter Enabled'],
                  ['cashfree_online', 'Cashfree Online Payments'],
                  ['ai_features', 'AI Forecast & Menu Scanner'],
                  ['self_delivery', 'Kitchen Self-Delivery'],
                  ['snacks_slot', 'Evening Snacks Slot'],
                  ['banners_enabled', 'Customer Home Offer Banners'],
                ] as const
              ).map(([key, label]) => (
                <label key={key} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <input
                    type="checkbox"
                    checked={cfg.feature_flags[key]}
                    onChange={(e) =>
                      setCfg({ ...cfg, feature_flags: { ...cfg.feature_flags, [key]: e.target.checked } })
                    }
                  />
                  {label}
                </label>
              ))}
            </div>

            <div className="admin-field-grid">
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
                <input type="checkbox" checked={cfg.customer_maintenance} onChange={(e) => setCfg({ ...cfg, customer_maintenance: e.target.checked })} />
                Customer App Maintenance Banner / Lock
              </label>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
                <input type="checkbox" checked={cfg.partner_maintenance} onChange={(e) => setCfg({ ...cfg, partner_maintenance: e.target.checked })} />
                Partner App & Web Maintenance Banner / Lock
              </label>
              <div className="admin-field">
                <label>Min Customer App Version</label>
                <input className="admin-input" value={cfg.min_customer_version} onChange={(e) => setCfg({ ...cfg, min_customer_version: e.target.value })} />
              </div>
              <div className="admin-field">
                <label>Min Partner App Version</label>
                <input className="admin-input" value={cfg.min_partner_version} onChange={(e) => setCfg({ ...cfg, min_partner_version: e.target.value })} />
              </div>
            </div>
            <div className="admin-field" style={{ marginTop: 12 }}>
              <label>Maintenance Message</label>
              <input className="admin-input" value={cfg.maintenance_message} onChange={(e) => setCfg({ ...cfg, maintenance_message: e.target.value })} />
            </div>
          </section>

          <div>
            <button type="submit" disabled={saving} className="admin-primary-button">
              <Save size={15} /> Save All App Customizations
            </button>
          </div>
        </form>
      )}
    </div>
  );
}
