'use client';

import { useState } from 'react';
import Link from 'next/link';
import Image from 'next/image';
import { useRouter } from 'next/navigation';
import { APP_CONFIG } from '@/lib/config';
import { ArrowRight } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';

export default function RegisterPage() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [message, setMessage] = useState('');
  const [error, setError] = useState('');

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setMessage('');
    try {
      const supabase = createClient();
      const { data, error: authError } = await supabase.auth.signUp({
        email,
        password,
        options: { data: { full_name: name, phone } },
      });
      if (authError) throw authError;
      if (data.session) {
        router.replace('/customer/dashboard');
        router.refresh();
      } else {
        setMessage('Check your email to confirm your account before signing in.');
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Registration failed. Please try again.');
    }
  };

  return (
    <div className="min-h-[85vh] flex items-center justify-center p-4">
      <div className="max-w-md w-full bg-white rounded-xl border border-slate-200 p-8 shadow-sm space-y-6">
        <div className="text-center space-y-2">
          <div className="flex justify-center">
            <Image
              src="/brand/logo.png"
              alt={APP_CONFIG.brandName}
              width={112}
              height={56}
              className="h-14 w-auto object-contain rounded-md"
            />
          </div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Create your {APP_CONFIG.brandName} Account</h1>
          <p className="text-xs text-slate-500">Create a customer account to discover local meals.</p>
        </div>

        <form onSubmit={handleRegister} className="space-y-3.5 text-xs">
          <div className="space-y-1">
            <label className="font-semibold text-slate-700 block">Full Name / Business Name</label>
            <input
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Your name"
              className="w-full bg-slate-50 border border-slate-300 rounded-md px-3 py-2 text-slate-900 focus:outline-none focus:border-amber-600"
            />
          </div>

          <div className="space-y-1">
            <label className="font-semibold text-slate-700 block">Mobile Phone Number</label>
            <input
              type="tel"
              required
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              placeholder="+91 98765 43210"
              className="w-full bg-slate-50 border border-slate-300 rounded-md px-3 py-2 text-slate-900 focus:outline-none focus:border-amber-600"
            />
          </div>

          <div className="space-y-1">
            <label className="font-semibold text-slate-700 block">Email Address</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="name@example.com"
              className="w-full bg-slate-50 border border-slate-300 rounded-md px-3 py-2 text-slate-900 focus:outline-none focus:border-amber-600"
            />
          </div>

          <div className="space-y-1">
            <label className="font-semibold text-slate-700 block">Create Password</label>
            <input
              type="password"
              minLength={8}
              autoComplete="new-password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="At least 8 characters"
              className="w-full bg-slate-50 border border-slate-300 rounded-md px-3 py-2 text-slate-900 focus:outline-none focus:border-amber-600"
            />
          </div>

          {error && <p role="alert" className="rounded-md bg-red-50 p-3 text-red-700">{error}</p>}
          {message && <p role="status" className="rounded-md bg-green-50 p-3 text-green-800">{message}</p>}

          <button
            type="submit"
            className="w-full py-2.5 bg-slate-900 hover:bg-slate-800 text-white font-semibold text-xs rounded-md shadow-sm transition-colors flex items-center justify-center space-x-1.5"
          >
            <span>Complete Registration</span>
            <ArrowRight className="w-4 h-4" />
          </button>
        </form>

        <div className="pt-2 text-center text-xs text-slate-500">
          Already have an account?{' '}
          <Link href="/auth/login" className="text-amber-700 font-semibold hover:underline">
            Sign In
          </Link>
        </div>
      </div>
    </div>
  );
}
