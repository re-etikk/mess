import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'About Us',
  description: 'Learn about Thali — a daily meal marketplace connecting students and professionals with local mess and tiffin providers.',
  alternates: { canonical: 'https://www.thali.store/about' },
};

export default function AboutPage() {
  return (
    <main className="mx-auto max-w-4xl px-6 py-16 space-y-4">
      <h1 className="text-3xl font-black text-slate-950 tracking-tight">About Thali</h1>
      <p className="text-slate-600 leading-7">
        Thali connects students and working professionals with verified neighborhood mess and home-style tiffin kitchens for single plates, flexi meal-credit passes, and monthly subscriptions.
      </p>
      <p className="text-slate-600 leading-7">
        Customers can dine in, pick up at the counter with instant QR verification, or order tiffin delivery directly from delivery-enabled kitchens — while partners manage live queues, AI prep forecasts, and payouts from both mobile and web.
      </p>
    </main>
  );
}
