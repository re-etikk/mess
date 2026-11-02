'use client';

import { FormEvent, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export default function AccountDeletionPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [loading, setLoading] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); setError(''); setSuccess('');
    if (confirmation !== 'DELETE') { setError('Type DELETE exactly to confirm.'); return; }
    setLoading(true);
    const supabase = createClient();
    try {
      const { data, error: signInError } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (signInError || !data.session) throw new Error('Sign-in failed. Use the credentials for the Thali account you want to delete.');
      const response = await fetch('/api/account/deletion', { method: 'DELETE', headers: { Authorization: `Bearer ${data.session.access_token}`, 'x-account-deletion-confirmation': 'DELETE' } });
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(result.error || 'Deletion could not be completed.');
      setSuccess(result.message || 'Your account deletion is complete.');
      await supabase.auth.signOut();
      setPassword(''); setConfirmation('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Account deletion could not be completed.');
    } finally { setLoading(false); }
  }

  return <main className="min-h-[75vh] bg-stone-50 px-4 py-12 sm:py-20">
    <section className="mx-auto max-w-2xl rounded-2xl border border-stone-200 bg-white p-6 shadow-sm sm:p-10">
      <p className="text-xs font-bold uppercase tracking-[.18em] text-amber-800">Thali account & data</p>
      <h1 className="mt-2 text-3xl font-black text-slate-950">Request account deletion</h1>
      <p className="mt-3 text-sm leading-6 text-slate-600">Use this page if you no longer have the Thali app. Sign in to the customer or mess partner account you want to delete and confirm below.</p>
      <div className="mt-6 rounded-xl bg-amber-50 p-4 text-sm leading-6 text-amber-950"><strong>What happens:</strong> access is removed, active customer entitlements are closed, and an owner’s public mess listing is disabled. Personal profile data and support messages are deleted. Anonymized payment, booking, settlement, fraud-prevention, and audit records may be retained where needed by law or platform operations.</div>
      <form onSubmit={submit} className="mt-7 space-y-4">
        <label className="block text-sm font-semibold text-slate-800">Account email<input required type="email" autoComplete="username" value={email} onChange={(event) => setEmail(event.target.value)} className="mt-1.5 min-h-11 w-full rounded-lg border border-slate-300 px-3" /></label>
        <label className="block text-sm font-semibold text-slate-800">Account password<input required type="password" autoComplete="current-password" value={password} onChange={(event) => setPassword(event.target.value)} className="mt-1.5 min-h-11 w-full rounded-lg border border-slate-300 px-3" /></label>
        <label className="block text-sm font-semibold text-slate-800">Type DELETE to confirm<input required value={confirmation} onChange={(event) => setConfirmation(event.target.value)} className="mt-1.5 min-h-11 w-full rounded-lg border border-slate-300 px-3" /></label>
        {error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-800">{error}</p>}
        {success && <p role="status" className="rounded-lg bg-emerald-50 p-3 text-sm text-emerald-900">{success}</p>}
        <button type="submit" disabled={loading || Boolean(success)} className="min-h-11 w-full rounded-lg bg-red-700 px-4 font-bold text-white disabled:opacity-60">{loading ? 'Deleting account…' : 'Permanently delete my account'}</button>
      </form>
      <p className="mt-5 text-xs leading-5 text-slate-500">If the request reports an error, your account may be waiting for support. Keep the request ID shown in the error and contact <a className="font-semibold text-amber-800 underline" href="mailto:support@thali.store">support@thali.store</a>. Read the <a className="font-semibold text-amber-800 underline" href="/privacy">privacy policy</a> for data retention details.</p>
    </section>
  </main>;
}
