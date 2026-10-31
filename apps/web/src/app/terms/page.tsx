import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Terms of Service',
  description: 'Read Thali\'s terms of service governing use of our meal marketplace platform for customers and mess providers.',
  alternates: { canonical: 'https://www.thali.store/terms' },
};

export default function TermsPage() {
  return <main className="mx-auto max-w-4xl px-6 py-20"><h1 className="text-3xl font-bold text-slate-900">Terms of service</h1><p className="mt-4 text-slate-600">Thali has not launched for commercial use. Final terms will be published after review and before any purchases or provider agreements are enabled.</p><p className="mt-3 text-slate-600">No provider fee, subscription, refund, or payment terms are currently being offered through this site.</p></main>;
}
