import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'Understand how Thali collects, uses and protects your personal data on our meal marketplace platform.',
  alternates: { canonical: 'https://www.thali.store/privacy' },
};

export default function PrivacyPage() {
  return <main className="mx-auto max-w-4xl px-6 py-20"><h1 className="text-3xl font-bold text-slate-900">Privacy notice</h1><p className="mt-4 text-slate-600">Thali is not open for customer or provider use. A complete privacy notice describing the final data flows, retention, processors, and contact details must be published before launch.</p><p className="mt-3 text-slate-600">Do not submit personal, payment, licence, or business documents through this prototype.</p></main>;
}
