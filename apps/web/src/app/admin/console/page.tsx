'use client';

import { FormEvent, useEffect, useState } from 'react';
import Link from 'next/link';
import { AlertCircle, ArrowLeft, Check, CheckCircle2, Clock3, RefreshCw, Save, ShieldCheck, X } from 'lucide-react';

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
        fetch('/api/admin/providers', { cache: 'no-store' }),
      ]);
      const [result, applicationResult] = await Promise.all([billingResponse.json(), applicationsResponse.json()]);
      if (!billingResponse.ok) throw new Error(result.error || 'Unable to load live billing data.');
      if (!applicationsResponse.ok) throw new Error(applicationResult.error || 'Unable to load provider applications.');
      setSettings(result.settings);
      setProviders(result.providers);
      setApplications(applicationResult.applications);
      setDates(Object.fromEntries(result.providers.map((p: ProviderAccount) => [p.provider_id, dateInputValue(p.trial_ends_at)])));
      setExemptions(Object.fromEntries(result.providers.map((p: ProviderAccount) => [p.provider_id, p.billing_exempt])));
      setReasons(Object.fromEntries(result.providers.map((p: ProviderAccount) => [p.provider_id, p.exempt_reason ?? ''])));
      setNotes(Object.fromEntries(result.providers.map((p: ProviderAccount) => [p.provider_id, p.admin_note ?? ''])));
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Unable to load billing controls.');
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => { void load(); }, []);

  async function saveSettings(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!settings) return;
    setSaving(true);
    setError('');
    setMessage('');
    try {
      const response = await fetch('/api/admin/billing', {
        method: 'PATCH', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          free_trial_days: Number(settings.free_trial_days),
          fee_per_90_successful_redemptions_inr: Number(settings.fee_per_90_successful_redemptions_inr),
          usage_billing_enabled: settings.usage_billing_enabled,
        }),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Settings could not be saved.');
      setSettings(result.settings);
      setMessage('Billing policy saved. Existing trial end dates are unchanged.');
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
        method: 'PATCH', headers: { 'Content-Type': 'application/json' },
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
    const reason = reviewReasons[application.id]?.trim() ?? '';
    if (reason.length < 3) {
      setError('Enter an audit reason before approving or rejecting an application.');
      return;
    }
    setSaving(true);
    setError('');
    setMessage('');
    try {
      const response = await fetch('/api/admin/providers', {
        method: 'PATCH', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider_id: application.id, decision, reason }),
      });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Provider review could not be saved.');
      setMessage(decision === 'approve' ? `${application.display_name} approved; its trial has started.` : `${application.display_name} application rejected.`);
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
        <Link href="/" className="inline-flex min-h-10 items-center gap-2 rounded-lg px-3 text-sm font-medium text-slate-600 hover:bg-white hover:text-slate-950 focus-visible:outline focus-visible:outline-2 focus-visible:outline-amber-600">
          <ArrowLeft size={16} aria-hidden="true" /> Back to Thali
        </Link>

        <header className="mt-7 flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.18em] text-amber-700">Thali · Admin</p>
            <h1 className="mt-2 text-3xl font-bold tracking-tight sm:text-4xl">Provider billing</h1>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-600">Set the introductory free period and usage-fee policy. Only provider records from the connected database are listed.</p>
          </div>
          <button type="button" onClick={() => void load()} disabled={loading || saving} className="inline-flex min-h-11 items-center justify-center gap-2 rounded-xl border border-slate-300 bg-white px-4 text-sm font-semibold hover:bg-slate-50 disabled:opacity-60">
            <RefreshCw size={16} aria-hidden="true" /> Refresh live data
          </button>
        </header>

        <div className="mt-6 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm leading-6 text-amber-950">
          <div className="flex gap-3"><ShieldCheck className="mt-0.5 shrink-0" size={18} aria-hidden="true" /><p><strong>Collection is not enabled here.</strong> These controls configure the free period and fee policy only. Turning on post-trial fee assessment stores the policy but does not accrue or collect money until real redemption metering and the payment workflow are implemented and verified.</p></div>
        </div>

        {error && <div role="alert" className="mt-5 flex gap-3 rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800"><AlertCircle className="shrink-0" size={18} aria-hidden="true" />{error}</div>}
        {message && <div role="status" className="mt-5 flex gap-3 rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-sm text-emerald-900"><CheckCircle2 className="shrink-0" size={18} aria-hidden="true" />{message}</div>}

        <section aria-labelledby="applications-heading" className="mt-7 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <h2 id="applications-heading" className="text-lg font-bold">Mess owner applications</h2>
          <p className="mt-1 text-sm text-slate-600">Review submitted business details. Approval publishes the real provider record and starts its configured free trial.</p>
          {loading ? <p className="mt-5 text-sm text-slate-500">Loading submitted applications…</p> : applications.length === 0 ? (
            <div className="mt-5 rounded-xl border border-dashed border-slate-300 bg-slate-50 px-5 py-8 text-center"><p className="font-semibold text-slate-800">No applications awaiting review</p><p className="mt-2 text-sm text-slate-600">New submissions from mess owners will appear here. No sample businesses are shown.</p></div>
          ) : <div className="mt-5 space-y-4">
            {applications.map((application) => <article key={application.id} className="rounded-xl border border-slate-200 p-4 sm:p-5">
              <div className="flex flex-wrap items-start justify-between gap-2"><div><h3 className="font-semibold">{application.display_name}</h3><p className="mt-1 text-xs text-slate-500">Submitted {new Date(application.created_at).toLocaleDateString('en-IN')} · {application.public_phone}</p></div><span className="rounded-full bg-amber-50 px-3 py-1 text-xs font-semibold text-amber-900">Needs review</span></div>
              <p className="mt-3 text-sm text-slate-700">{application.address_line1}{application.locality ? `, ${application.locality}` : ''}, {application.city}, {application.state} {application.pincode}</p>
              {application.description && <p className="mt-2 text-sm leading-6 text-slate-600">{application.description}</p>}
              <div className="mt-4 flex flex-col gap-3 sm:flex-row sm:items-end">
                <label className="flex-1 text-xs font-semibold text-slate-700">Review reason (required for audit)<input value={reviewReasons[application.id] ?? ''} onChange={(e) => setReviewReasons({ ...reviewReasons, [application.id]: e.target.value })} maxLength={500} className="mt-2 min-h-11 w-full rounded-lg border border-slate-300 px-3 text-sm font-normal" /></label>
                <div className="flex gap-2"><button type="button" disabled={saving} onClick={() => void reviewApplication(application, 'reject')} className="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg border border-red-200 px-4 text-sm font-semibold text-red-800 hover:bg-red-50 disabled:opacity-60"><X size={16} aria-hidden="true" /> Reject</button><button type="button" disabled={saving} onClick={() => void reviewApplication(application, 'approve')} className="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg bg-emerald-700 px-4 text-sm font-semibold text-white hover:bg-emerald-800 disabled:opacity-60"><Check size={16} aria-hidden="true" /> Approve & start trial</button></div>
              </div>
            </article>)}
          </div>}
        </section>

        <section aria-labelledby="policy-heading" className="mt-7 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <div className="flex items-start gap-3"><div className="rounded-xl bg-amber-100 p-2.5 text-amber-800"><Clock3 size={19} aria-hidden="true" /></div><div><h2 id="policy-heading" className="text-lg font-bold">Default provider policy</h2><p className="mt-1 text-sm text-slate-600">Applies when a provider is approved. Changing it will not rewrite existing trials.</p></div></div>
          {loading ? <p className="mt-6 text-sm text-slate-500">Loading policy from the database…</p> : settings ? (
            <form onSubmit={saveSettings} className="mt-6 grid gap-5 md:grid-cols-3">
              <label className="text-sm font-semibold">Free period (days)<input type="number" min={0} max={365} required value={settings.free_trial_days} onChange={(e) => setSettings({ ...settings, free_trial_days: Number(e.target.value) })} className="mt-2 min-h-11 w-full rounded-lg border border-slate-300 px-3 font-normal focus:border-amber-600 focus:outline-none focus:ring-2 focus:ring-amber-100" /></label>
              <label className="text-sm font-semibold">Fee per 90 successful redemptions (₹)<input type="number" min={0} max={100000} required value={settings.fee_per_90_successful_redemptions_inr} onChange={(e) => setSettings({ ...settings, fee_per_90_successful_redemptions_inr: Number(e.target.value) })} className="mt-2 min-h-11 w-full rounded-lg border border-slate-300 px-3 font-normal focus:border-amber-600 focus:outline-none focus:ring-2 focus:ring-amber-100" /></label>
              <div className="flex flex-col justify-end gap-3">
                <label className="flex min-h-11 items-center gap-3 rounded-lg border border-slate-200 px-3 text-sm font-medium"><input type="checkbox" checked={settings.usage_billing_enabled} onChange={(e) => setSettings({ ...settings, usage_billing_enabled: e.target.checked })} className="h-4 w-4 accent-amber-700" /> Enable post-trial fee assessment</label>
                <button type="submit" disabled={saving} className="inline-flex min-h-11 items-center justify-center gap-2 rounded-lg bg-slate-900 px-4 text-sm font-semibold text-white hover:bg-slate-700 disabled:opacity-60"><Save size={16} aria-hidden="true" />{saving ? 'Saving…' : 'Save policy'}</button>
              </div>
            </form>
          ) : <p className="mt-6 text-sm text-slate-600">No billing policy was returned.</p>}
        </section>

        <section aria-labelledby="providers-heading" className="mt-7 rounded-2xl border border-slate-200 bg-white p-5 shadow-sm sm:p-7">
          <h2 id="providers-heading" className="text-lg font-bold">Provider trial accounts</h2>
          <p className="mt-1 text-sm text-slate-600">Extend a provider’s trial or record an exemption with an audit reason.</p>
          {loading ? <p className="mt-6 text-sm text-slate-500">Loading provider records…</p> : providers.length === 0 ? (
            <div className="mt-5 rounded-xl border border-dashed border-slate-300 bg-slate-50 px-5 py-10 text-center"><p className="font-semibold text-slate-800">No provider billing accounts yet</p><p className="mt-2 text-sm text-slate-600">Approved mess owners will appear here when real provider records exist in Supabase. No sample businesses are shown.</p></div>
          ) : (
            <div className="mt-5 space-y-4">
              {providers.map((provider) => <article key={provider.provider_id} className="rounded-xl border border-slate-200 p-4 sm:p-5">
                <div className="flex flex-wrap items-center justify-between gap-2"><div><h3 className="font-semibold">{provider.provider_name}</h3><p className="mt-1 text-xs text-slate-500">{provider.provider_status} · Trial started {provider.trial_started_at ? new Date(provider.trial_started_at).toLocaleDateString('en-IN') : 'not recorded'}</p></div><span className="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-700">{provider.billing_exempt ? 'Exempt' : provider.trial_ends_at && new Date(provider.trial_ends_at) > new Date() ? 'Free trial' : 'Post-trial'}</span></div>
                <div className="mt-4 grid gap-4 md:grid-cols-2">
                  <label className="text-xs font-semibold text-slate-700">Trial ends<input type="date" required value={dates[provider.provider_id] ?? ''} onChange={(e) => setDates({ ...dates, [provider.provider_id]: e.target.value })} className="mt-2 min-h-11 w-full rounded-lg border border-slate-300 px-3 text-sm font-normal" /></label>
                  <label className="flex min-h-11 items-center gap-3 self-end rounded-lg border border-slate-200 px-3 text-sm"><input type="checkbox" checked={exemptions[provider.provider_id] ?? false} onChange={(e) => setExemptions({ ...exemptions, [provider.provider_id]: e.target.checked })} className="h-4 w-4 accent-amber-700" /> Exempt this provider from usage fees</label>
                  {exemptions[provider.provider_id] && <label className="text-xs font-semibold text-slate-700">Reason (required)<input value={reasons[provider.provider_id] ?? ''} onChange={(e) => setReasons({ ...reasons, [provider.provider_id]: e.target.value })} maxLength={300} className="mt-2 min-h-11 w-full rounded-lg border border-slate-300 px-3 text-sm font-normal" /></label>}
                  <label className="text-xs font-semibold text-slate-700">Internal admin note<textarea value={notes[provider.provider_id] ?? ''} onChange={(e) => setNotes({ ...notes, [provider.provider_id]: e.target.value })} maxLength={500} rows={2} className="mt-2 w-full rounded-lg border border-slate-300 px-3 py-2 text-sm font-normal" /></label>
                </div>
                <div className="mt-4 flex justify-end"><button type="button" disabled={saving} onClick={() => void saveProvider(provider)} className="inline-flex min-h-10 items-center justify-center gap-2 rounded-lg border border-slate-300 px-4 text-sm font-semibold hover:bg-slate-50 disabled:opacity-60"><Save size={15} aria-hidden="true" /> Save provider policy</button></div>
              </article>)}
            </div>
          )}
        </section>

        <p className="mt-6 text-xs leading-5 text-slate-500">Admin changes require an authenticated user with an active server-verified <code>admin</code> role. Changes are recorded in the audit log. The system does not infer or fabricate provider identity or usage.</p>
      </div>
    </main>
  );
}
