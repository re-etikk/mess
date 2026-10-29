'use client';

import { FormEvent, useEffect, useState } from 'react';
import Link from 'next/link';
import {
  AlertCircle,
  ArrowLeft,
  Check,
  CheckCircle2,
  Clock3,
  RefreshCw,
  Save,
  ShieldCheck,
  Store,
  X,
} from 'lucide-react';

type BillingSettings = {
  free_trial_days: number;
  fee_per_90_successful_redemptions_inr: number;
  usage_billing_enabled: boolean;
  updated_at: string;
};

type ProviderAccount = {
  provider_id: string;
  provider_name: string;
  provider_status: string;
  trial_started_at: string | null;
  trial_ends_at: string | null;
  billing_exempt: boolean;
  exempt_reason: string | null;
  admin_note: string | null;
};

type ProviderApplication = {
  id: string;
  display_name: string;
  public_phone: string;
  description: string | null;
  address_line1: string;
  locality: string | null;
  city: string;
  state: string;
  pincode: string;
  created_at: string;
};

function dateInputValue(value: string | null) {
  return value ? new Date(value).toISOString().slice(0, 10) : '';
}

export default function AdminConsole() {
  const [settings, setSettings] = useState<BillingSettings | null>(null);
  const [providers, setProviders] = useState<ProviderAccount[]>([]);
  const [applications, setApplications] = useState<ProviderApplication[]>([]);
  const [reviewReasons, setReviewReasons] = useState<Record<string, string>>({});
  const [dates, setDates] = useState<Record<string, string>>({});
  const [exemptions, setExemptions] = useState<Record<string, boolean>>({});
  const [reasons, setReasons] = useState<Record<string, string>>({});
  const [notes, setNotes] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  async function load() {
    setLoading(true);
    setError('');
    try {
      const [billingResponse, applicationsResponse] = await Promise.all([
        fetch('/api/admin/billing', { cache: 'no-store' }),
        fetch('/api/admin/providers?all=true', { cache: 'no-store' }),
      ]);
      const [result, applicationResult] = await Promise.all([
        billingResponse.json().catch(() => ({})),
        applicationsResponse.json().catch(() => ({})),
      ]);

      if (applicationResult?.applications) {
        setApplications(applicationResult.applications);
      }
      if (result?.settings) {
        setSettings(result.settings);
      }
      if (result?.providers) {
        setProviders(result.providers);
        setDates(Object.fromEntries(result.providers.map((p: ProviderAccount) => [p.provider_id, dateInputValue(p.trial_ends_at)])));
        setExemptions(Object.fromEntries(result.providers.map((p: ProviderAccount) => [p.provider_id, p.billing_exempt])));
        setReasons(Object.fromEntries(result.providers.map((p: ProviderAccount) => [p.provider_id, p.exempt_reason ?? ''])));
        setNotes(Object.fromEntries(result.providers.map((p: ProviderAccount) => [p.provider_id, p.admin_note ?? ''])));
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unable to load live admin data.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  async function saveSettings(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!settings) return;
    setSaving(true);
    setError('');
    setMessage('');
    try {
      const response = await fetch('/api/admin/billing', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          free_trial_days: Number(settings.free_trial_days),
          fee_per_90_successful_redemptions_inr: Number(settings.fee_per_90_successful_redemptions_inr),
          usage_billing_enabled: settings.usage_billing_enabled,
        }),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Settings could not be saved.');
      setSettings(result.settings);
      setMessage('Billing policy saved successfully.');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Settings could not be saved.');
    } finally {
      setSaving(false);
    }
  }

  async function saveProvider(provider: ProviderAccount) {
    setSaving(true);
    setError('');
    setMessage('');
    try {
      const date = dates[provider.provider_id];
      const response = await fetch('/api/admin/billing', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider_id: provider.provider_id,
          trial_ends_at: date ? new Date(`${date}T23:59:59+05:30`).toISOString() : null,
          billing_exempt: exemptions[provider.provider_id] ?? false,
          exempt_reason: reasons[provider.provider_id]?.trim() || null,
          admin_note: notes[provider.provider_id]?.trim() || null,
        }),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Provider billing settings could not be saved.');
      setMessage(`Billing policy updated for ${provider.provider_name}.`);
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Provider billing settings could not be saved.');
    } finally {
      setSaving(false);
    }
  }

  async function reviewApplication(application: ProviderApplication, decision: 'approve' | 'reject') {
    const reason =
      (reviewReasons[application.id] || '').trim() ||
      (decision === 'approve' ? 'Verified kitchen address and operational readiness.' : 'Incomplete business information.');

    setSaving(true);
    setError('');
    setMessage('');
    try {
      const response = await fetch('/api/admin/providers', {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider_id: application.id, decision, reason }),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Provider review could not be saved.');
      setMessage(
        decision === 'approve'
          ? `✅ ${application.display_name} approved! Kitchen listing & plans are now live on Mobile Apps and Web Directory.`
          : `${application.display_name} application rejected.`
      );
      await load();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Provider review could not be saved.');
    } finally {
      setSaving(false);
    }
  }

  return (
    <main className="min-h-screen bg-[#f7f6f2] px-4 py-8 text-slate-900 sm:px-6 lg:px-10">
      <div className="mx-auto max-w-6xl">
        <Link
          href="/"
          className="inline-flex min-h-10 items-center gap-2 rounded-lg px-3 text-sm font-medium text-slate-600 hover:bg-white hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-amber-600 transition"
        >
          <ArrowLeft size={16} aria-hidden="true" /> Back to Thali
        </Link>

        <header className="mt-7 flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.18em] text-amber-700">Thali · Admin Operations</p>
            <h1 className="mt-2 text-3xl font-bold tracking-tight sm:text-4xl">Platform Operations & Verification</h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
              Review kitchen partner applications, manage billing policies, and inspect active providers across India.
            </p>
          </div>
          <button
            type="button"
            onClick={() => void load()}
            disabled={loading || saving}
            className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl border border-slate-300 bg-white px-4 text-sm font-semibold shadow-sm hover:bg-slate-50 disabled:opacity-60 transition"
          >
            <RefreshCw size={16} aria-hidden="true" className={loading ? 'animate-spin' : ''} />
            Refresh live data
          </button>
        </header>

        {error && (
          <div role="alert" className="mt-5 flex gap-3 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800">
            <AlertCircle className="shrink-0" size={18} aria-hidden="true" />
            {error}
          </div>
        )}
        {message && (
          <div role="status" className="mt-5 flex gap-3 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-900 font-medium">
            <CheckCircle2 className="shrink-0 text-emerald-700" size={18} aria-hidden="true" />
            {message}
          </div>
        )}

        {/* SECTION 1: MESS OWNER APPLICATIONS */}
        <section aria-labelledby="applications-heading" className="mt-7 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <div className="flex items-center justify-between gap-4">
            <div>
              <h2 id="applications-heading" className="text-lg font-bold flex items-center gap-2">
                <Store size={20} className="text-amber-700" />
                Mess Owner Applications
                {applications.length > 0 && (
                  <span className="ml-2 rounded-full bg-amber-100 px-2.5 py-0.5 text-xs font-bold text-amber-900">
                    {applications.length} awaiting review
                  </span>
                )}
              </h2>
              <p className="mt-1 text-sm text-slate-600">
                Review submitted business details. Clicking &quot;Approve&quot; publishes the kitchen to the Customer App and enables QR meal redemptions.
              </p>
            </div>
          </div>

          {loading ? (
            <p className="mt-5 text-sm text-slate-500">Loading submitted applications…</p>
          ) : applications.length === 0 ? (
            <div className="mt-5 rounded-xl border border-dashed border-slate-300 bg-slate-50 px-5 py-8 text-center">
              <p className="font-semibold text-slate-800">No applications awaiting review</p>
              <p className="mt-2 text-sm text-slate-600">
                When a mess owner registers on the onboarding portal, their application will appear here for one-click approval.
              </p>
            </div>
          ) : (
            <div className="mt-5 space-y-4">
              {applications.map((application) => (
                <article key={application.id} className="rounded-xl border border-amber-200 bg-amber-50/30 p-4 sm:p-5 transition hover:shadow-md">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div>
                      <h3 className="text-base font-bold text-slate-950">{application.display_name}</h3>
                      <p className="mt-1 text-xs text-slate-500">
                        Submitted {new Date(application.created_at).toLocaleDateString('en-IN')} · Phone: <strong>{application.public_phone}</strong>
                      </p>
                    </div>
                    <span className="rounded-full bg-amber-100 border border-amber-300 px-3 py-1 text-xs font-bold text-amber-900">
                      Needs review
                    </span>
                  </div>

                  <div className="mt-3 text-sm text-slate-700">
                    <p>
                      <strong>Location:</strong> {application.address_line1}
                      {application.locality ? `, ${application.locality}` : ''}, {application.city}, {application.state} {application.pincode}
                    </p>
                    {application.description && (
                      <p className="mt-1.5 text-slate-600 italic">
                        &ldquo;{application.description}&rdquo;
                      </p>
                    )}
                  </div>

                  <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-end border-t border-amber-200/60 pt-3">
                    <label className="flex-1 text-xs font-semibold text-slate-700">
                      Verification note
                      <input
                        value={reviewReasons[application.id] ?? ''}
                        placeholder="Verified kitchen address and operational readiness"
                        onChange={(e) => setReviewReasons({ ...reviewReasons, [application.id]: e.target.value })}
                        maxLength={500}
                        className="mt-1.5 min-h-11 w-full rounded-lg border border-slate-300 bg-white px-3 text-sm font-normal outline-none focus:border-amber-600 focus:ring-2 focus:ring-amber-100"
                      />
                    </label>
                    <div className="flex gap-2">
                      <button
                        type="button"
                        disabled={saving}
                        onClick={() => void reviewApplication(application, 'reject')}
                        className="inline-flex min-h-11 items-center justify-center gap-1.5 rounded-lg border border-red-200 bg-white px-4 text-sm font-semibold text-red-800 hover:bg-red-50 disabled:opacity-60 transition"
                      >
                        <X size={16} aria-hidden="true" /> Reject
                      </button>
                      <button
                        type="button"
                        disabled={saving}
                        onClick={() => void reviewApplication(application, 'approve')}
                        className="inline-flex min-h-11 items-center justify-center gap-1.5 rounded-lg bg-emerald-700 px-5 text-sm font-semibold text-white hover:bg-emerald-800 disabled:opacity-60 shadow-sm transition"
                      >
                        <Check size={16} aria-hidden="true" /> Approve & Activate Mess
                      </button>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

        {/* SECTION 2: ACTIVE KITCHEN PARTNERS */}
        <section aria-labelledby="providers-heading" className="mt-7 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <h2 id="providers-heading" className="text-lg font-bold">Active Kitchen Partners</h2>
          <p className="mt-1 text-sm text-slate-600">
            Active kitchens visible on the student customer app and capable of generating daily meal redemption QR tokens.
          </p>

          {loading ? (
            <p className="mt-6 text-sm text-slate-500">Loading kitchen records…</p>
          ) : providers.length === 0 ? (
            <div className="mt-5 rounded-xl border border-dashed border-slate-300 bg-slate-50 px-5 py-8 text-center">
              <p className="font-semibold text-slate-800">No active kitchens yet</p>
              <p className="mt-2 text-sm text-slate-600">Approve pending applications above to activate kitchens.</p>
            </div>
          ) : (
            <div className="mt-5 space-y-4">
              {providers.map((provider) => (
                <article key={provider.provider_id} className="rounded-xl border border-slate-200 p-4 sm:p-5">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div>
                      <h3 className="font-bold text-slate-950">{provider.provider_name}</h3>
                      <p className="mt-1 text-xs text-slate-500">
                        Status: <strong className="text-emerald-700 uppercase">{provider.provider_status}</strong> · Started{' '}
                        {provider.trial_started_at ? new Date(provider.trial_started_at).toLocaleDateString('en-IN') : 'Recently'}
                      </p>
                    </div>
                    <span className="rounded-full bg-emerald-50 border border-emerald-200 px-3 py-1 text-xs font-semibold text-emerald-800">
                      Active Partner
                    </span>
                  </div>

                  <div className="mt-4 grid gap-4 md:grid-cols-2">
                    <label className="text-xs font-semibold text-slate-700">
                      Trial ends
                      <input
                        type="date"
                        required
                        value={dates[provider.provider_id] ?? ''}
                        onChange={(e) => setDates({ ...dates, [provider.provider_id]: e.target.value })}
                        className="mt-2 min-h-11 w-full rounded-lg border border-slate-300 px-3 text-sm font-normal"
                      />
                    </label>
                    <label className="flex min-h-11 items-center gap-3 self-end rounded-lg border border-slate-200 px-3 text-sm">
                      <input
                        type="checkbox"
                        checked={exemptions[provider.provider_id] ?? false}
                        onChange={(e) => setExemptions({ ...exemptions, [provider.provider_id]: e.target.checked })}
                        className="h-4 w-4 accent-amber-700"
                      />
                      Exempt this provider from usage fees
                    </label>
                  </div>
                  <div className="mt-4 flex justify-end">
                    <button
                      type="button"
                      disabled={saving}
                      onClick={() => void saveProvider(provider)}
                      className="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-slate-300 px-4 text-sm font-semibold hover:bg-slate-50 disabled:opacity-60 transition"
                    >
                      <Save size={15} aria-hidden="true" /> Save policy
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

        {/* SECTION 3: BILLING POLICY CONTROLS */}
        <section aria-labelledby="policy-heading" className="mt-7 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <div className="flex items-start gap-3">
            <div className="rounded-xl bg-amber-100 p-2.5 text-amber-800">
              <Clock3 size={19} aria-hidden="true" />
            </div>
            <div>
              <h2 id="policy-heading" className="text-lg font-bold">Default Provider Monetization Policy</h2>
              <p className="mt-1 text-sm text-slate-600">Configures introductory trial period and platform usage fee (₹25 per 90 scans).</p>
            </div>
          </div>
          {loading ? (
            <p className="mt-6 text-sm text-slate-500">Loading policy…</p>
          ) : settings ? (
            <form onSubmit={saveSettings} className="mt-6 grid gap-5 md:grid-cols-3">
              <label className="text-sm font-semibold">
                Free period (days)
                <input
                  type="number"
                  min={0}
                  max={365}
                  required
                  value={settings.free_trial_days}
                  onChange={(e) => setSettings({ ...settings, free_trial_days: Number(e.target.value) })}
                  className="mt-2 min-h-11 w-full rounded-lg border border-slate-300 px-3 font-normal focus:border-amber-600 focus:outline-none focus:ring-2 focus:ring-amber-100"
                />
              </label>
              <label className="text-sm font-semibold">
                Fee per 90 successful redemptions (₹)
                <input
                  type="number"
                  min={0}
                  max={100000}
                  required
                  value={settings.fee_per_90_successful_redemptions_inr}
                  onChange={(e) => setSettings({ ...settings, fee_per_90_successful_redemptions_inr: Number(e.target.value) })}
                  className="mt-2 min-h-11 w-full rounded-lg border border-slate-300 px-3 font-normal focus:border-amber-600 focus:outline-none focus:ring-2 focus:ring-amber-100"
                />
              </label>
              <div className="flex flex-col justify-end gap-3">
                <label className="flex min-h-11 items-center gap-3 rounded-lg border border-slate-200 px-3 text-sm font-medium">
                  <input
                    type="checkbox"
                    checked={settings.usage_billing_enabled}
                    onChange={(e) => setSettings({ ...settings, usage_billing_enabled: e.target.checked })}
                    className="h-4 w-4 accent-amber-700"
                  />
                  Enable usage fee assessment
                </label>
                <button
                  type="submit"
                  disabled={saving}
                  className="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg bg-slate-900 px-4 text-sm font-semibold text-white hover:bg-slate-700 disabled:opacity-60 transition"
                >
                  <Save size={16} aria-hidden="true" />
                  {saving ? 'Saving…' : 'Save policy'}
                </button>
              </div>
            </form>
          ) : (
            <p className="mt-6 text-sm text-slate-600">No billing policy was returned.</p>
          )}
        </section>
      </div>
    </main>
  );
}
