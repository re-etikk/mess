'use client';

import Link from 'next/link';
import Image from 'next/image';
import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { APP_CONFIG } from '@/lib/config';
import { ArrowRight, Menu, Store, X } from 'lucide-react';

export default function Navbar() {
  const [open, setOpen] = useState(false);
  const [providerName, setProviderName] = useState<string | null>(null);
  const [sessionChecked, setSessionChecked] = useState(false);
  const [signingOut, setSigningOut] = useState(false);
  const pathname = usePathname();
  const router = useRouter();

  useEffect(() => {
    let cancelled = false;
    setSessionChecked(false);
    fetch('/api/provider/session', { cache: 'no-store' })
      .then(async (response) => response.ok ? response.json() : null)
      .then((result) => {
        if (!cancelled) setProviderName(result?.provider?.name || null);
      })
      .catch(() => { if (!cancelled) setProviderName(null); })
      .finally(() => { if (!cancelled) setSessionChecked(true); });
    return () => { cancelled = true; };
  }, [pathname]);

  async function signOut() {
    setSigningOut(true);
    try {
      const response = await fetch('/api/auth/logout', { method: 'POST' });
      if (!response.ok) throw new Error('Sign out failed. Try again.');
      setProviderName(null);
      setOpen(false);
      router.push('/partner/login');
      router.refresh();
    } catch {
      setSigningOut(false);
    }
  }

  return (
    <header className="sticky top-0 z-50 border-b border-slate-200/80 bg-white/95 backdrop-blur">
      <div className="mx-auto flex h-[4.5rem] max-w-7xl items-center justify-between px-4 sm:px-8 lg:px-10">
        <Link href="/" aria-label={`${APP_CONFIG.brandName} partner home`} className="flex items-center gap-3 rounded-lg focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-orange-700">
          <Image src="/brand/logo.png" alt="" width={42} height={42} priority className="h-10 w-10 rounded-xl border border-orange-100 bg-white object-contain p-0.5" />
          <span><strong className="block text-base font-black tracking-tight text-slate-950">{APP_CONFIG.brandName}</strong><span className="block text-[10px] font-bold uppercase tracking-[0.15em] text-orange-800">For mess partners</span></span>
        </Link>

        <nav aria-label="Main navigation" className="hidden items-center gap-1 md:flex">
          <Link href="/#tools" className="rounded-lg px-3 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-50 hover:text-slate-950">Partner tools</Link>
          <Link href="/contact" className="rounded-lg px-3 py-2 text-sm font-semibold text-slate-600 hover:bg-slate-50 hover:text-slate-950">Support</Link>
          {sessionChecked && (providerName ? <>
            <span className="ml-2 max-w-40 truncate rounded-lg px-3 py-2 text-sm font-semibold text-slate-600" title={providerName}>{providerName}</span>
            <Link href="/provider/portal" className="inline-flex min-h-10 items-center justify-center gap-2 rounded-xl bg-orange-700 px-4 text-sm font-bold text-white shadow-sm transition hover:bg-orange-800">Dashboard <ArrowRight size={15} /></Link>
            <button type="button" disabled={signingOut} onClick={signOut} className="ml-1 min-h-10 rounded-xl border border-slate-300 px-4 text-sm font-bold text-slate-700 hover:bg-slate-50 disabled:opacity-60">{signingOut ? 'Signing out…' : 'Sign out'}</button>
          </> : <>
            <Link href="/partner/login" className="ml-2 inline-flex min-h-10 items-center justify-center gap-2 rounded-xl border border-slate-300 px-4 text-sm font-bold text-slate-800 transition hover:border-slate-400 hover:bg-slate-50">Sign in</Link>
            <Link href="/provider/portal" className="ml-1 inline-flex min-h-10 items-center justify-center gap-2 rounded-xl bg-orange-700 px-4 text-sm font-bold text-white shadow-sm transition hover:bg-orange-800">Partner workspace <ArrowRight size={15} /></Link>
          </>)}
        </nav>

        <button type="button" onClick={() => setOpen((value) => !value)} aria-label={open ? 'Close navigation menu' : 'Open navigation menu'} aria-expanded={open} className="inline-flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 text-slate-800 md:hidden">
          {open ? <X size={19} /> : <Menu size={19} />}
        </button>
      </div>
      {open && <nav aria-label="Mobile navigation" className="border-t border-slate-200 bg-white px-4 py-4 md:hidden">
        <div className="mx-auto grid max-w-7xl gap-2">
          <Link onClick={() => setOpen(false)} href="/#tools" className="rounded-lg px-3 py-3 text-sm font-semibold text-slate-700 hover:bg-slate-50">Partner tools</Link>
          <Link onClick={() => setOpen(false)} href="/contact" className="rounded-lg px-3 py-3 text-sm font-semibold text-slate-700 hover:bg-slate-50">Support</Link>
          <div className="mt-1 grid grid-cols-2 gap-2">
            {providerName ? <>
              <Link onClick={() => setOpen(false)} href="/provider/portal" className="flex min-h-11 items-center justify-center gap-1.5 rounded-xl bg-orange-700 px-3 text-sm font-bold text-white"><Store size={15} /> Dashboard</Link>
              <button type="button" disabled={!sessionChecked || signingOut} onClick={signOut} className="min-h-11 rounded-xl border border-slate-300 px-3 text-sm font-bold text-slate-800 disabled:opacity-60">{signingOut ? 'Signing out…' : 'Sign out'}</button>
            </> : sessionChecked ? <>
              <Link onClick={() => setOpen(false)} href="/partner/login" className="flex min-h-11 items-center justify-center rounded-xl border border-slate-300 px-3 text-sm font-bold text-slate-800">Sign in</Link>
              <Link onClick={() => setOpen(false)} href="/provider/portal" className="flex min-h-11 items-center justify-center gap-1.5 rounded-xl bg-orange-700 px-3 text-sm font-bold text-white"><Store size={15} /> Partner portal</Link>
            </> : <span className="col-span-2 min-h-11" aria-hidden="true" />}
          </div>
        </div>
      </nav>}
    </header>
  );
}
