'use client';

import { Suspense, useEffect, useState } from 'react';
import Link from 'next/link';
import { useSearchParams } from 'next/navigation';
import { AlertCircle, CheckCircle2, Loader2, ShieldCheck } from 'lucide-react';

function CashfreeReturnContent() {
  const params = useSearchParams();
  const orderId = params.get('order_id') || '';
  const [status, setStatus] = useState<'verifying' | 'paid' | 'failed'>('verifying');
  const [message, setMessage] = useState('Verifying your payment securely with Cashfree...');
  const [details, setDetails] = useState<any>(null);

  useEffect(() => {
    if (!orderId) {
      setStatus('failed');
      setMessage('Missing payment order reference. Please check your dashboard or retry payment.');
      return;
    }

    let cancelled = false;

    async function verify() {
      try {
        const res = await fetch('/api/payments/cashfree/verify', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ order_id: orderId }),
        });
        const data = await res.json().catch(() => ({}));
        if (cancelled) return;

        if (res.ok && data.success) {
          setStatus('paid');
          setDetails(data);
          setMessage('Payment confirmed and your meal pass is now active!');
        } else {
          setStatus('failed');
          setMessage(data.error || 'Payment could not be confirmed.');
        }
      } catch {
        if (!cancelled) {
          setStatus('failed');
          setMessage('Network error while verifying your payment. Please refresh in a moment.');
        }
      }
    }

    void verify();
    return () => {
      cancelled = true;
    };
  }, [orderId]);

  return (
    <main className="min-h-screen bg-[#fcf8ef] flex items-center justify-center px-4 py-12">
      <div className="w-full max-w-md rounded-3xl border border-amber-950/10 bg-white p-7 text-center shadow-lg space-y-5">
        {status === 'verifying' && (
          <>
            <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-amber-50 text-amber-700">
              <Loader2 size={32} className="animate-spin" />
            </div>
            <h1 className="text-xl font-black text-slate-900">Confirming Payment</h1>
            <p className="text-xs text-slate-600 leading-5">{message}</p>
          </>
        )}

        {status === 'paid' && (
          <>
            <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-emerald-50 text-emerald-600">
              <CheckCircle2 size={36} />
            </div>
            <div>
              <span className="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-3 py-1 text-[11px] font-bold text-emerald-800">
                <ShieldCheck size={13} /> Cashfree Verified
              </span>
              <h1 className="mt-3 text-2xl font-black text-slate-900">Payment Successful!</h1>
              <p className="mt-2 text-xs text-slate-600 leading-5">{message}</p>
            </div>
            <div className="rounded-2xl border border-emerald-200 bg-emerald-50/50 p-4 text-left text-xs space-y-2">
              <div className="flex justify-between">
                <span className="text-slate-600">Order ID</span>
                <span className="font-mono font-bold text-slate-900">{orderId}</span>
              </div>
              {details?.amount_inr != null && (
                <div className="flex justify-between">
                  <span className="text-slate-600">Amount Paid</span>
                  <span className="font-black text-emerald-800">₹{details.amount_inr}</span>
                </div>
              )}
              {details?.cf_payment_id && (
                <div className="flex justify-between">
                  <span className="text-slate-600">Payment Ref</span>
                  <span className="font-mono text-slate-800">{details.cf_payment_id}</span>
                </div>
              )}
            </div>
            <div className="flex flex-col gap-2.5 pt-2">
              <Link
                href="/customer/dashboard"
                className="inline-flex min-h-11 items-center justify-center rounded-xl bg-orange-600 text-sm font-bold text-white hover:bg-orange-700"
              >
                Go to My Meal Passes
              </Link>
              <Link
                href="/explore"
                className="text-xs font-bold text-slate-500 hover:text-slate-800"
              >
                Explore Messes
              </Link>
            </div>
          </>
        )}

        {status === 'failed' && (
          <>
            <div className="mx-auto grid h-16 w-16 place-items-center rounded-2xl bg-red-50 text-red-600">
              <AlertCircle size={36} />
            </div>
            <h1 className="text-xl font-black text-slate-900">Payment Not Completed</h1>
            <p className="text-xs text-slate-600 leading-5">{message}</p>
            {orderId && (
              <p className="text-[11px] font-mono text-slate-500">Order: {orderId}</p>
            )}
            <div className="flex flex-col gap-2.5 pt-2">
              <Link
                href="/explore"
                className="inline-flex min-h-11 items-center justify-center rounded-xl bg-slate-900 text-sm font-bold text-white hover:bg-slate-800"
              >
                Try Again / Browse Messes
              </Link>
              <Link
                href="/customer/dashboard"
                className="text-xs font-bold text-slate-500 hover:text-slate-800"
              >
                Back to Dashboard
              </Link>
            </div>
          </>
        )}
      </div>
    </main>
  );
}

export default function CashfreeReturnPage() {
  return (
    <Suspense
      fallback={
        <main className="min-h-screen bg-[#fcf8ef] flex items-center justify-center">
          <Loader2 size={32} className="animate-spin text-amber-700" />
        </main>
      }
    >
      <CashfreeReturnContent />
    </Suspense>
  );
}
