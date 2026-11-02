import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'Understand how Thali collects, uses and protects your personal data on our meal marketplace platform.',
  alternates: { canonical: 'https://www.thali.store/privacy' },
};

export default function PrivacyPage() {
  return <main className="mx-auto max-w-4xl px-6 py-16 sm:py-20"><h1 className="text-3xl font-black text-slate-950">Thali Privacy Notice</h1><p className="mt-3 text-sm text-slate-500">Last updated: November 2, 2026</p><div className="mt-8 space-y-7 text-sm leading-7 text-slate-700">
    <section><h2 className="text-lg font-bold text-slate-950">Information used</h2><p>Thali uses account identifiers and profile details; mess partner business and serving information; customer plans, bookings, and meal redemption records; device or approximate location when you choose location-based discovery; support messages; and payment status or transaction references when payment services are enabled. QR scanning is used to submit a meal redemption for server verification.</p></section>
    <section><h2 className="text-lg font-bold text-slate-950">How it is used</h2><p>Information is used to authenticate accounts, show mess and menu information, manage subscriptions and redemptions, prevent duplicate or fraudulent activity, provide customer support, and maintain required financial and security records. Thali uses hosted infrastructure providers to operate the service and payment providers only when checkout is enabled.</p></section>
    <section><h2 className="text-lg font-bold text-slate-950">Account and data deletion</h2><p>Customers and mess partners can request deletion in the app’s account/profile settings or at <a className="font-semibold text-amber-800 underline" href="/account-deletion">thali.store/account-deletion</a>. The request disables access and applicable partner listings promptly. Personal profile and support data are deleted; the request is completed within 30 days. Payment, booking, redemption, settlement, fraud-prevention, and audit records may be retained in anonymized form when required for legal, financial, safety, or security purposes. Deletion does not mean freezing an account: the account identity is removed when the request completes.</p></section>
    <section><h2 className="text-lg font-bold text-slate-950">Contact</h2><p>For privacy or deletion questions, contact <a className="font-semibold text-amber-800 underline" href="mailto:support@thali.store">support@thali.store</a>. If a deletion request cannot complete automatically, include the request ID so support can resolve it.</p></section>
  </div></main>;
}
