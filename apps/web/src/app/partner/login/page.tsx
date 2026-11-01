'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

export default function PartnerLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      const supabase = createClient();
      const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
      if (authError) throw authError;
      const response = await fetch('/api/provider/session', { cache: 'no-store' });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || 'Could not verify partner access.');
      router.replace('/provider/portal');
      router.refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Sign in failed. Check your details and try again.');
    } finally {
      setBusy(false);
    }
  }

  return <main className="mx-auto flex min-h-[75vh] max-w-md items-center px-5 py-12">
    <section className="w-full rounded-2xl border border-slate-200 bg-white p-7 shadow-sm">
      <p className="text-xs font-bold uppercase tracking-widest text-amber-700">Thali Partner</p>
      <h1 className="mt-2 text-2xl font-black text-slate-950">Sign in to your mess portal</h1>
      <p className="mt-2 text-sm text-slate-600">Use the email and password for your Thali account.</p>
      <form onSubmit={submit} className="mt-6 space-y-4">
        <label className="block text-sm font-semibold">Email<input type="email" autoComplete="username" required value={email} onChange={(e) => setEmail(e.target.value)} className="mt-1 block min-h-11 w-full rounded-lg border border-slate-300 px-3" /></label>
        <label className="block text-sm font-semibold">Password<input type="password" autoComplete="current-password" required value={password} onChange={(e) => setPassword(e.target.value)} className="mt-1 block min-h-11 w-full rounded-lg border border-slate-300 px-3" /></label>
        {error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-800">{error}</p>}
        <button disabled={busy} className="min-h-11 w-full rounded-lg bg-slate-950 px-4 font-bold text-white disabled:opacity-60">{busy ? 'Verifying…' : 'Sign in'}</button>
      </form>
      <p className="mt-5 text-sm text-slate-600">New to Thali? <Link className="font-bold text-amber-800 underline" href="/auth/register">Create an account</Link>, then submit your mess application.</p>
    </section>
  </main>;
}
