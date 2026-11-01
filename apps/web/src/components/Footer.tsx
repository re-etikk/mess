import Image from 'next/image';
import Link from 'next/link';
import { APP_CONFIG } from '@/lib/config';

export default function Footer() {
  return (
    <footer className="border-t border-slate-800 bg-slate-950 text-slate-300">
      <div className="mx-auto grid max-w-7xl gap-10 px-5 py-10 sm:px-8 md:grid-cols-[1.5fr_1fr_1fr] lg:px-10">
        <div>
          <Link href="/" className="inline-flex items-center gap-3 rounded-lg focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-orange-300" aria-label={`${APP_CONFIG.brandName} home`}>
            <Image src="/brand/logo.png" alt="" width={40} height={40} className="rounded-xl border border-slate-700 bg-white object-contain p-0.5" />
            <span><strong className="block text-lg font-black tracking-tight text-white">{APP_CONFIG.brandName}</strong><span className="text-xs text-orange-300">Partner workspace</span></span>
          </Link>
          <p className="mt-4 max-w-sm text-sm leading-6 text-slate-400">Tools for mess owners and administrators. Business records and activity shown in the portal come from the connected account.</p>
          <p className="mt-3 max-w-sm text-xs leading-5 text-slate-500">Customer ordering and meal passes continue through the Thali mobile app for now.</p>
        </div>
        <nav aria-label="Partner links">
          <h2 className="text-xs font-bold uppercase tracking-wider text-white">Partner</h2>
          <ul className="mt-3 space-y-2 text-sm text-slate-400">
            <li><Link href="/provider/portal" className="hover:text-orange-300">Partner workspace</Link></li>
            <li><Link href="/partner/login" className="hover:text-orange-300">Partner sign in</Link></li>
            <li><Link href="/contact" className="hover:text-orange-300">Contact support</Link></li>
          </ul>
        </nav>
        <nav aria-label="Policies">
          <h2 className="text-xs font-bold uppercase tracking-wider text-white">Policies</h2>
          <ul className="mt-3 space-y-2 text-sm text-slate-400">
            <li><Link href="/privacy" className="hover:text-orange-300">Privacy</Link></li>
            <li><Link href="/terms" className="hover:text-orange-300">Terms</Link></li>
            <li><Link href="/refund-policy" className="hover:text-orange-300">Refund information</Link></li>
          </ul>
        </nav>
      </div>
      <div className="border-t border-slate-800 px-5 py-4 text-center text-xs text-slate-500 sm:px-8">© {new Date().getFullYear()} {APP_CONFIG.brandName}. Partner tools require verified access.</div>
    </footer>
  );
}
