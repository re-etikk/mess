'use client';

import { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { ArrowLeft, ArrowRight, CheckCircle2, Mail } from 'lucide-react';
import { APP_CONFIG } from '@/lib/config';
import { createClient } from '@/lib/supabase/client';

export default function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  const handleReset = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    setSuccess(false);

    try {
      const supabase = createClient();
      const origin = typeof window !== 'undefined' ? window.location.origin : 'https://www.thali.store';
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email.trim(), {
        redirectTo: `${origin}/auth/reset-password`,
      });

      if (resetError) throw resetError;
      setSuccess(true);
    } catch (err) {
      setError(
        err instanceof Error
          ? err.message
          : 'Unable to send recovery email. Please check your address or contact support@thali.store.'
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
            <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Reset Password</h1>
            <p className="text-xs font-semibold text-amber-700">{APP_CONFIG.tagline}</p>
          </div>
          <p className="text-xs text-slate-500">
            Enter your registered email address and we will send you a password reset link.
          </p>
        </div>

        {success ? (
          <div role="status" className="space-y-4">
            <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-4 text-emerald-950 flex items-start gap-3">
              <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" />
              <div className="text-xs leading-5">
                <p className="font-bold">Recovery email sent!</p>
                <p className="mt-1">
                  We sent a secure password reset link to <strong>{email}</strong>. Please check your inbox and spam folder.
                </p>
              </div>
            </div>
            <Link
              href="/auth/login"
              className="w-full py-2.5 bg-slate-900 hover:bg-slate-800 text-white font-semibold text-xs rounded-md shadow-sm transition-colors flex items-center justify-center space-x-1.5"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>Back to Sign In</span>
            </Link>
          </div>
        ) : (
          <form onSubmit={handleReset} className="space-y-4 text-xs">
            <div className="space-y-1">
              <label htmlFor="recovery-email" className="font-semibold text-slate-700 block">
                Email Address
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
                <input
                  id="recovery-email"
                  type="email"
                  autoComplete="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="name@example.com"
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
              <span>{loading ? 'Sending link...' : 'Send Recovery Link'}</span>
              <ArrowRight className="w-4 h-4" />
            </button>

            <div className="text-center pt-2">
              <Link
                href="/auth/login"
                className="text-xs font-semibold text-amber-700 hover:text-amber-800 underline underline-offset-2"
              >
                Remember your password? Sign In
              </Link>
            </div>
          </form>
        )}
      </div>
    </main>
  );
}
