import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Frequently Asked Questions',
  description: 'Get answers to common questions about Thali — single meal orders, subscriptions, delivery, counter check-in, and partner onboarding.',
  alternates: { canonical: 'https://www.thali.store/faq' },
};

export default function FaqPage() {
  return (
    <main className="mx-auto max-w-4xl px-6 py-16">
      <h1 className="text-3xl font-black text-slate-950 tracking-tight">Frequently Asked Questions</h1>
      <section className="mt-8">
        <h2 className="font-bold text-slate-900">Can I order a single meal or a monthly pass?</h2>
        <p className="mt-2 text-slate-600">Yes. Choose single plates (`Breakfast`, `Lunch`, `Snacks`, `Dinner`) or subscribe to a kitchen&apos;s flexible meal-credit or fixed monthly pass via Cashfree online or Pay-at-Counter.</p>
      </section>
      <section className="mt-6">
        <h2 className="font-bold text-slate-900">Is tiffin delivery available?</h2>
        <p className="mt-2 text-slate-600">Delivery is available from kitchens that enable home delivery, alongside counter dine-in and takeaway pickup with QR check-in.</p>
      </section>
      <section className="mt-6">
        <h2 className="font-bold text-slate-900">How do kitchen partners manage operations?</h2>
        <p className="mt-2 text-slate-600">Verified mess owners can manage menus, slot prices, live preparation queues, riders, and settlements seamlessly from both the Thali Partner app and the Partner Web Portal (`/provider/portal`).</p>
      </section>
    </main>
  );
}
