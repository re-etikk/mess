import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Refund Policy',
  description: 'Review Thali\'s refund policy for meal subscriptions and daily meal purchases on our marketplace.',
  alternates: { canonical: 'https://www.thali.store/refund-policy' },
};

export default function RefundPolicyPage() {
  return <main className="mx-auto max-w-4xl px-6 py-20"><h1 className="text-3xl font-bold text-slate-900">Refund policy</h1><p className="mt-4 text-slate-600">Checkout is disabled and Thali is not accepting payments. Refund terms will be published and reviewed before paid services are enabled.</p></main>;
}
