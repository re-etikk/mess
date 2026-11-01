import type { Metadata } from 'next';
import { notFound, redirect } from 'next/navigation';
import { requireAdmin } from '@/lib/supabase/admin';
import AdminShell from './AdminShell';
import './admin-shell.css';

export const metadata: Metadata = {
  title: 'Admin',
  robots: { index: false, follow: false },
};

export default async function AdminConsoleLayout({ children }: { children: React.ReactNode }) {
  const access = await requireAdmin();
  if (!access.ok && access.status === 401) redirect('/auth/login?next=%2Fadmin%2Fconsole');
  if (!access.ok && access.status === 403) notFound();
  if (!access.ok) {
    return <main className="mx-auto flex min-h-[60vh] max-w-2xl items-center px-5 py-16"><section className="w-full rounded-2xl border border-amber-200 bg-white p-6 shadow-sm"><p className="text-xs font-bold uppercase tracking-widest text-amber-800">Admin workspace</p><h1 className="mt-2 text-xl font-black text-slate-950">Admin access is temporarily unavailable</h1><p className="mt-2 text-sm leading-6 text-slate-600">The server could not verify admin access right now. Please try again later or contact the platform operator.</p></section></main>;
  }
  return <AdminShell userId={access.userId}>{children}</AdminShell>;
}
