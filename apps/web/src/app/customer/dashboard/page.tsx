import Link from 'next/link';

export default function CustomerDashboard() {
  return <main className="mx-auto max-w-4xl px-6 py-20"><h1 className="text-3xl font-bold text-slate-900">Your Thali account</h1><p className="mt-4 text-slate-600">Meal passes, history, and QR redemption will be available after the secure Supabase backend is connected.</p><p className="mt-3 text-sm text-amber-800">No plan or meal has been purchased.</p><Link className="mt-6 inline-block text-amber-800 underline" href="/explore">Browse provider status</Link></main>;
}
