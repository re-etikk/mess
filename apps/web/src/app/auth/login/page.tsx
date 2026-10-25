'use client';

import { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import { APP_CONFIG } from '@/lib/config';
import { ArrowRight, Lock, Mail } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const supabase = createClient();
      const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
      if (authError) throw authError;
      router.replace('/customer/dashboard');
      router.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sign in failed. Check your details and try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[80vh] flex items-center justify-center p-4">
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
            <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Sign In to {APP_CONFIG.brandName}</h1>
            <p className="text-xs font-semibold text-amber-700">{APP_CONFIG.tagline}</p>
          </div>
            <p className="text-xs text-slate-500">Sign in to access your Thali account</p>
        </div>

        <form onSubmit={handleLogin} className="space-y-4 text-xs">
          <div className="space-y-1">
            <label className="font-semibold text-slate-700 block">Email Address</label>
            <div className="relative">
              <Mail className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
              <input
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="w-full bg-slate-50 border border-slate-300 rounded-md pl-9 pr-3 py-2 text-slate-900 focus:outline-none focus:border-amber-600"
              />
            </div>
          </div>

          <div className="space-y-1">
            <div className="flex justify-between">
              <label className="font-semibold text-slate-700 block">Password</label>
              <span className="text-slate-400">Contact support for account recovery</span>
            </div>
            <div className="relative">
              <Lock className="w-4 h-4 text-slate-400 absolute left-3 top-2.5" />
              <input
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                className="w-full bg-slate-50 border border-slate-300 rounded-md pl-9 pr-3 py-2 text-slate-900 focus:outline-none focus:border-amber-600"
              />
            </div>
          </div>

          {error && <p role="alert" className="rounded-md bg-red-50 p-3 text-red-700">{error}</p>}

          <button
            type="submit"
            disabled={loading}
            className="w-full py-2.5 bg-slate-900 hover:bg-slate-800 disabled:bg-slate-400 text-white font-semibold text-xs rounded-md shadow-sm transition-colors flex items-center justify-center space-x-1.5"
          >
            <span>{loading ? 'Authenticating...' : 'Sign In Securely'}</span>
            <ArrowRight className="w-4 h-4" />
          </button>
        </form>

        <div className="pt-2 text-center text-xs text-slate-500">
          New to {APP_CONFIG.brandName}?{' '}
          <Link href="/auth/register" className="text-amber-700 font-semibold hover:underline">
            Create an Account
          </Link>
        </div>
      </div>
    </div>
  );
}
