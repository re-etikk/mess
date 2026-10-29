'use client';

import { Suspense, useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import QRCode from 'qrcode';
import { Printer, Share2, Copy, ArrowLeft, Store, ShieldCheck } from 'lucide-react';
import Link from 'next/link';

function CounterStandeeContent() {
  const searchParams = useSearchParams();
  const providerId = searchParams.get('provider_id') || 'prov-radhe-001';

  const [providerName, setProviderName] = useState('Mess Partner');
  const [providerAddress, setProviderAddress] = useState('Campus Area');
  const [copied, setCopied] = useState(false);
  const [qrDataUrl, setQrDataUrl] = useState<string>('');

  const joinUrl = `https://mess-beta.vercel.app/join/${providerId}`;

  useEffect(() => {
    QRCode.toDataURL(joinUrl, {
      width: 320,
      margin: 1,
      color: {
        dark: '#000000',
        light: '#ffffff',
      },
    })
      .then(setQrDataUrl)
      .catch(() => {});
  }, [joinUrl]);

  useEffect(() => {
    async function loadProvider() {
      try {
        const res = await fetch(`/api/provider/dashboard?provider_id=${providerId}`).then((r) => r.json());
        if (res?.provider) {
          setProviderName(res.provider.display_name || 'Mess Partner');
          setProviderAddress(res.provider.address || res.provider.city || 'Campus Location');
        }
      } catch {}
    }
    void loadProvider();
  }, [providerId]);

  return (
    <main className="min-h-screen bg-[#f7f6f2] p-4 sm:p-8 flex flex-col items-center justify-center">
      {/* NO-PRINT CONTROLS */}
      <div className="print:hidden w-full max-w-md mb-6 flex items-center justify-between">
        <Link
          href="/admin/console"
          className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-600 hover:text-slate-900"
        >
          <ArrowLeft size={15} /> Back
        </Link>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => {
              void navigator.clipboard.writeText(joinUrl);
              setCopied(true);
              setTimeout(() => setCopied(false), 2000);
            }}
            className="inline-flex items-center gap-1.5 rounded-lg border border-slate-300 bg-white px-3 py-1.5 text-xs font-semibold text-slate-700 hover:bg-slate-50 transition"
          >
            <Copy size={13} /> {copied ? 'Copied Link!' : 'Copy Link'}
          </button>
          <button
            type="button"
            onClick={() => window.print()}
            className="inline-flex items-center gap-1.5 rounded-lg bg-amber-600 px-3.5 py-1.5 text-xs font-bold text-white shadow-sm hover:bg-amber-700 transition"
          >
            <Printer size={14} /> Print Standee
          </button>
        </div>
      </div>

      {/* PRINTABLE STANDEE CARD */}
      <div className="w-full max-w-sm rounded-3xl border-4 border-slate-900 bg-white p-7 shadow-xl text-center print:border-2 print:shadow-none print:m-0 print:p-8">
        <div className="inline-flex items-center gap-1 rounded-full bg-emerald-50 border border-emerald-200 px-3 py-1 text-[11px] font-bold text-emerald-800 uppercase tracking-wider">
          <ShieldCheck size={14} /> Verified Meal Partner
        </div>

        <h1 className="mt-3 text-2xl font-black text-slate-950 uppercase tracking-tight">
          {providerName}
        </h1>
        <p className="mt-0.5 text-xs font-medium text-slate-600">{providerAddress}</p>

        {/* QR BOX */}
        <div className="mt-6 mx-auto w-56 h-56 rounded-2xl border-2 border-slate-200 bg-slate-50 p-3.5 flex items-center justify-center shadow-inner">
          {qrDataUrl ? (
            /* eslint-disable-next-line @next/next/no-img-element */
            <img src={qrDataUrl} alt="Standee Joining QR" className="w-[190px] h-[190px] object-contain rounded-lg" />
          ) : (
            <div className="w-[190px] h-[190px] bg-slate-100 animate-pulse rounded-lg flex items-center justify-center text-xs text-slate-400">
              Generating Standee QR...
            </div>
          )}
        </div>

        <div className="mt-5 rounded-2xl bg-amber-500/10 border border-amber-300 p-3 text-center">
          <p className="text-xs font-black uppercase tracking-wider text-amber-950">
            Scan To Subscribe &amp; Get Meal Pass
          </p>
          <p className="mt-0.5 text-[11px] text-amber-900">
            Works with any Mobile Camera, GPay, PhonePe or Paytm
          </p>
        </div>

        {/* 3 QUICK STEPS */}
        <div className="mt-5 grid grid-cols-3 gap-2 text-left border-t border-slate-100 pt-4 text-[10px] text-slate-600">
          <div>
            <span className="font-bold text-slate-900 block text-xs">1. Scan</span>
            Open camera &amp; scan this standee QR
          </div>
          <div>
            <span className="font-bold text-slate-900 block text-xs">2. Select</span>
            Pick your monthly or flexi meal plan
          </div>
          <div>
            <span className="font-bold text-slate-900 block text-xs">3. Eat</span>
            Instant digital meal pass on your phone
          </div>
        </div>

        <div className="mt-6 text-[10px] text-slate-400 font-mono">
          Powered by Thali · mess-beta.vercel.app
        </div>
      </div>
    </main>
  );
}

export default function CounterStandeePage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-[#f7f6f2] flex items-center justify-center p-8 text-sm text-slate-500 font-medium">
          Loading Counter Standee...
        </div>
      }
    >
      <CounterStandeeContent />
    </Suspense>
  );
}
