'use client';

declare global {
  interface Window {
    Cashfree?: (opts: { mode: 'sandbox' | 'production' }) => {
      checkout: (options: {
        paymentSessionId: string;
        redirectTarget?: '_self' | '_blank' | '_top' | '_modal';
        returnUrl?: string;
      }) => Promise<{ error?: { message?: string }; redirect?: boolean; paymentDetails?: unknown }>;
    };
  }
}

let sdkPromise: Promise<void> | null = null;

export function loadCashfreeJsSdk(): Promise<void> {
  if (typeof window === 'undefined') {
    return Promise.reject(new Error('Cashfree JS SDK requires a browser environment.'));
  }
  if (window.Cashfree) {
    return Promise.resolve();
  }
  if (sdkPromise) return sdkPromise;

  sdkPromise = new Promise<void>((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(
      'script[src="https://sdk.cashfree.com/js/v3/cashfree.js"]',
    );
    if (existing) {
      existing.addEventListener('load', () => resolve());
      existing.addEventListener('error', () => reject(new Error('Failed to load Cashfree Checkout SDK.')));
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://sdk.cashfree.com/js/v3/cashfree.js';
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => {
      sdkPromise = null;
      reject(new Error('Unable to load Cashfree Checkout SDK. Please check your connection.'));
    };
    document.head.appendChild(script);
  });

  return sdkPromise;
}

export async function launchCashfreeWebCheckout(opts: {
  paymentSessionId: string;
  environment: 'sandbox' | 'production';
  returnUrl?: string;
}) {
  await loadCashfreeJsSdk();
  if (!window.Cashfree) {
    throw new Error('Cashfree SDK initialized without Cashfree global.');
  }
  const cashfree = window.Cashfree({ mode: opts.environment });
  const result = await cashfree.checkout({
    paymentSessionId: opts.paymentSessionId,
    redirectTarget: '_self',
    ...(opts.returnUrl ? { returnUrl: opts.returnUrl } : {}),
  });
  if (result?.error) {
    throw new Error(result.error.message || 'Cashfree checkout could not be completed.');
  }
  return result;
}
