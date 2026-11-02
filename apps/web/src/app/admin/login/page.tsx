'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { LockKeyhole, ShieldCheck } from 'lucide-react';

export default function AdminLoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setLoading(true);
    setError('');
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, role: 'admin' }),
      });
      const result = await response.json();
      if (!response.ok || !result.success) throw new Error(result.error || 'Admin sign-in could not be verified.');
      const next = new URLSearchParams(window.location.search).get('next');
      router.replace(next?.startsWith('/admin/') ? next : '/admin/console');
      router.refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Admin sign-in failed.');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="min-h-[80vh] bg-stone-50 px-4 py-16">
      <section className="mx-auto max-w-md rounded-2xl border border-stone-200 bg-white p-7 shadow-sm sm:p-9">
        <div className="mx-auto mb-5 grid h-12 w-12 place-items-center rounded-2xl bg-amber-100 text-amber-900"><ShieldCheck size={24} /></div>
        <p className="text-center text-xs font-bold uppercase tracking-[.2em] text-amber-800">Thali · Private workspace</p>
        <h1 className="mt-2 text-center text-2xl font-black text-slate-950">Administrator sign in</h1>
        <p className="mt-2 text-center text-sm leading-6 text-slate-600">Use an existing administrator account. This private portal does not support account registration.</p>
        <form onSubmit={handleSubmit} className="mt-7 space-y-4">
          <label className="block text-sm font-semibold text-slate-800">Email<input required type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} className="mt-1.5 min-h-11 w-full rounded-lg border border-slate-300 px-3" /></label>
          <label className="block text-sm font-semibold text-slate-800">Password<span className="relative mt-1.5 block"><LockKeyhole size={16} className="absolute left-3 top-3 text-slate-400" /><input required type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} className="min-h-11 w-full rounded-lg border border-slate-300 pl-9 pr-3" /></span></label>
          {error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-800">{error}</p>}
          <button type="submit" disabled={loading} className="min-h-11 w-full rounded-lg bg-slate-950 px-4 font-bold text-white disabled:opacity-60">{loading ? 'Verifying access…' : 'Sign in securely'}</button>
        </form>
      </section>
    </main>
  );
}
