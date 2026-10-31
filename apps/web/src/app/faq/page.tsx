import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Frequently Asked Questions',
  description: 'Get answers to common questions about Thali — how meal subscriptions work, how to join as a provider, and what to expect from our mess and tiffin marketplace.',
  alternates: { canonical: 'https://www.thali.store/faq' },
};

export default function FaqPage() {
  return <main className="mx-auto max-w-4xl px-6 py-20"><h1 className="text-3xl font-bold text-slate-900">Frequently asked questions</h1><section className="mt-8"><h2 className="font-semibold">Can I buy a meal or subscription now?</h2><p className="mt-2 text-slate-600">No. Checkout is disabled until a verified payment provider and trusted database are connected.</p></section><section className="mt-6"><h2 className="font-semibold">Is delivery available?</h2><p className="mt-2 text-slate-600">No. The current product is for customers visiting food providers.</p></section><section className="mt-6"><h2 className="font-semibold">Are provider listings live?</h2><p className="mt-2 text-slate-600">No. No provider listing is currently published.</p></section></main>;
}
