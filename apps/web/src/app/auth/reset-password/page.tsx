'use client';

import { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import { ArrowRight, CheckCircle2, Lock } from 'lucide-react';
import { APP_CONFIG } from '@/lib/config';
import { createClient } from '@/lib/supabase/client';

export default function ResetPasswordPage() {
  const router = useRouter();
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const handleUpdate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (password.length < 8) {
      setError('Password must be at least 8 characters long.');
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const supabase = createClient();
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) throw updateError;
      setSuccess(true);
      setTimeout(() => {
        router.push('/customer/dashboard');
      }, 2000);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'Unable to update password. Recovery link may have expired.'
      );
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="min-h-[80vh] flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-xl border border-slate-200 p-8 shadow-sm space-y-6">
        <div className="text-center space-y-3">
          <div className="flex justify-center">
            <Image
              src="/brand/logo.png"
              alt={APP_CONFIG.brandName}
              width={112}
              height={56}
              className="h-14 w-auto object-contain rounded-md"
            />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Set New Password</h1>
            <p className="text-xs font-semibold text-amber-700">{APP_CONFIG.tagline}</p>
          </div>
          <p className="text-xs text-slate-500">
            Enter your new password below to secure your account.
          </p>
        </div>

        {success ? (
          <div role="status" className="space-y-4">
            <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-emerald-950 flex items-start gap-3">
              <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" />
              <div className="text-xs leading-5">
                <p className="font-bold">Password updated successfully!</p>
                <p className="mt-1">Redirecting you to your account dashboard…</p>
              </div>
            </div>
            <Link
              href="/customer/dashboard"
              className="w-full py-2.5 bg-slate-900 hover:bg-slate-800 text-white font-semibold text-xs rounded-md shadow-sm transition-colors flex items-center justify-center space-x-1.5"
            >
              <span>Go to Dashboard</span>
              <ArrowRight className="w-4 h-4" />
            </Link>
          </div>
        ) : (
          <form onSubmit={handleUpdate} className="space-y-4 text-xs">
            <div className="space-y-1">
              <label htmlFor="new-password" className="font-semibold text-slate-700 block">
                New Password
              </label>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
                <input
                  id="new-password"
                  type="password"
                  autoComplete="new-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="At least 8 characters"
                  required
                  className="w-full bg-slate-50 border border-slate-300 rounded-md pl-9 pr-3 py-2 text-slate-900 focus:outline-none focus:border-amber-600"
                />
              </div>
            </div>

            <div className="space-y-1">
              <label htmlFor="confirm-password" className="font-semibold text-slate-700 block">
                Confirm New Password
              </label>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
                <input
                  id="confirm-password"
                  type="password"
                  autoComplete="new-password"
                  value={confirmPassword}
                  onChange={(e) => setConfirmPassword(e.target.value)}
                  placeholder="Re-enter password"
                  required
                  className="w-full bg-slate-50 border border-slate-300 rounded-md pl-9 pr-3 py-2 text-slate-900 focus:outline-none focus:border-amber-600"
                />
              </div>
            </div>

            {error && (
              <p role="alert" className="rounded-md bg-red-50 p-3 text-red-700 text-xs">
                {error}
              </p>
            )}

            <button
              type="submit"
              disabled={loading}
              className="w-full py-2.5 bg-slate-900 hover:bg-slate-800 disabled:bg-slate-400 text-white font-semibold text-xs rounded-md shadow-sm transition-colors flex items-center justify-center space-x-1.5"
            >
              <span>{loading ? 'Saving...' : 'Update Password'}</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </form>
        )}
      </div>
    </main>
  );
}
