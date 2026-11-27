import type { Metadata } from 'next';
import ContactFormClient from './ContactFormClient';

export const metadata: Metadata = {
  title: 'Contact Us',
  description: 'Get in touch with the Thali team for support, provider onboarding enquiries, or general questions about our meal marketplace.',
  alternates: { canonical: 'https://www.thali.store/contact' },
};

export default function ContactPage() {
  return (
    <main className="mx-auto max-w-3xl px-6 py-16">
      <h1 className="text-3xl font-black text-slate-950 tracking-tight">Contact Thali Support</h1>
      <p className="mt-3 text-slate-600 text-sm leading-6">
        Need help with a meal subscription, single order, payment verification, or partner kitchen setup? Submit a ticket below and our operations desk will reply cleanly.
      </p>
      <ContactFormClient />
    </main>
  );
}
