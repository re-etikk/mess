import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About Us',
  description: 'Learn about Thali — a meal marketplace being built to connect students and professionals with local mess and tiffin providers for affordable daily meals.',
  alternates: { canonical: 'https://www.thali.store/about' },
};

export default function AboutPage() {
  return <main className="mx-auto max-w-4xl px-6 py-20"><h1 className="text-3xl font-bold text-slate-900">About Thali</h1><p className="mt-4 text-slate-600">Thali is being built to help people find everyday meals at local food providers. The marketplace has not launched and has no onboarded businesses yet.</p><p className="mt-3 text-slate-600">The first release is designed for customers to visit providers. Delivery is not offered.</p></main>;
}
