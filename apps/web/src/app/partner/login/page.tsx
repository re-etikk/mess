'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { KeyRound, Mail } from 'lucide-react';

export default function PartnerLoginPage() {
  const router = useRouter();
  const [mode, setMode] = useState<'password' | 'otp'>('password');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [otp, setOtp] = useState('');
  const [devOtpHint, setDevOtpHint] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submitPassword(event: FormEvent) {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      const supabase = createClient();
      const { error: authError } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
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

  async function sendOtp(event: FormEvent) {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      const res = await fetch('/api/auth/otp/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ identifier: email.trim(), purpose: 'signin' }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) throw new Error(data.error || 'Could not send OTP.');
      setOtpSent(true);
      if (data.test_otp) setDevOtpHint(String(data.test_otp));
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Could not send OTP.');
    } finally {
      setBusy(false);
    }
  }

  async function verifyOtp(event: FormEvent) {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      const res = await fetch('/api/auth/otp/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          identifier: email.trim(),
          otp: otp.trim(),
          create_session: true,
          role: 'provider',
        }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) throw new Error(data.error || 'Invalid OTP.');
      router.replace('/provider/portal');
      router.refresh();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'OTP verification failed.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="mx-auto flex min-h-[78vh] max-w-md items-center px-5 py-12">
      <section className="w-full rounded-2xl border border-slate-200 bg-white p-7 shadow-sm">
        <p className="text-xs font-bold uppercase tracking-widest text-amber-700">Thali Partner</p>
        <h1 className="mt-2 text-2xl font-black text-slate-950">Sign in to your mess portal</h1>
        <p className="mt-1 text-sm text-slate-600">Manage menus, live queue, riders, QR scans & payouts from web or app.</p>

        <div className="mt-5 grid grid-cols-2 gap-2 rounded-xl bg-slate-100 p-1 text-xs font-bold">
          <button
            type="button"
            onClick={() => { setMode('password'); setError(''); }}
            className={`flex items-center justify-center gap-1.5 rounded-lg py-2 transition ${mode === 'password' ? 'bg-white text-slate-950 shadow-sm' : 'text-slate-600'}`}
          >
            <KeyRound size={14} /> Password
          </button>
          <button
            type="button"
            onClick={() => { setMode('otp'); setError(''); }}
            className={`flex items-center justify-center gap-1.5 rounded-lg py-2 transition ${mode === 'otp' ? 'bg-white text-slate-950 shadow-sm' : 'text-slate-600'}`}
          >
            <Mail size={14} /> Email OTP
          </button>
        </div>

        {mode === 'password' ? (
          <form onSubmit={submitPassword} className="mt-5 space-y-4">
            <label className="block text-sm font-semibold">
              Email
              <input
                type="email"
                autoComplete="username"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="mt-1 block min-h-11 w-full rounded-lg border border-slate-300 px-3"
              />
            </label>
            <label className="block text-sm font-semibold">
              Password
              <input
                type="password"
                autoComplete="current-password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="mt-1 block min-h-11 w-full rounded-lg border border-slate-300 px-3"
              />
            </label>
            {error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-800">{error}</p>}
            <button disabled={busy} className="min-h-11 w-full rounded-lg bg-slate-950 px-4 font-bold text-white disabled:opacity-60">
              {busy ? 'Verifying…' : 'Sign in'}
            </button>
            <div className="text-right text-xs">
              <Link href="/auth/forgot-password" className="font-semibold text-amber-800 hover:underline">
                Forgot password?
              </Link>
            </div>
          </form>
        ) : !otpSent ? (
          <form onSubmit={sendOtp} className="mt-5 space-y-4">
            <label className="block text-sm font-semibold">
              Registered Kitchen Email
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="mt-1 block min-h-11 w-full rounded-lg border border-slate-300 px-3"
                placeholder="owner@kitchen.com"
              />
            </label>
            {error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-800">{error}</p>}
            <button disabled={busy} className="min-h-11 w-full rounded-lg bg-slate-950 px-4 font-bold text-white disabled:opacity-60">
              {busy ? 'Sending code…' : 'Send 6-Digit Email OTP'}
            </button>
          </form>
        ) : (
          <form onSubmit={verifyOtp} className="mt-5 space-y-4">
            <p className="text-xs text-slate-600">
              Code sent to <strong>{email}</strong>
            </p>
            {devOtpHint && <p className="rounded bg-amber-50 p-2 text-xs text-amber-900">Dev OTP: {devOtpHint}</p>}
            <label className="block text-sm font-semibold">
              6-Digit Verification Code
              <input
                type="text"
                maxLength={6}
                required
                value={otp}
                onChange={(e) => setOtp(e.target.value.replace(/\D/g, ''))}
                className="mt-1 block min-h-11 w-full rounded-lg border border-slate-300 px-3 tracking-[0.4em] text-center font-bold"
                placeholder="123456"
              />
            </label>
            {error && <p role="alert" className="rounded-lg bg-red-50 p-3 text-sm text-red-800">{error}</p>}
            <button disabled={busy} className="min-h-11 w-full rounded-lg bg-slate-950 px-4 font-bold text-white disabled:opacity-60">
              {busy ? 'Verifying…' : 'Verify & Open Dashboard'}
            </button>
            <button type="button" onClick={() => setOtpSent(false)} className="w-full text-xs font-semibold text-slate-600 hover:underline">
              Change email or resend OTP
            </button>
          </form>
        )}

        <p className="mt-5 text-sm text-slate-600">
          New kitchen partner?{' '}
          <Link className="font-bold text-amber-800 underline" href="/provider/portal?register=1">
            Register your mess kitchen
          </Link>
        </p>
      </section>
    </main>
  );
}
