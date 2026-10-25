import Image from 'next/image';
import Link from 'next/link';
import { APP_CONFIG } from '@/lib/config';

export default function Footer() {
  return (
    <footer className="border-t border-slate-800 bg-slate-950 text-slate-300">
      <div className="mx-auto grid max-w-7xl gap-10 px-4 py-10 sm:px-6 md:grid-cols-[1.4fr_1fr_1fr] lg:px-8">
        <div>
          <Link href="/" className="inline-flex items-center gap-3 rounded-lg focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-amber-400" aria-label={`${APP_CONFIG.brandName} home`}>
            <Image src="/brand/logo.png" alt="" width={40} height={40} className="rounded-md border border-slate-700 bg-white object-contain p-0.5" />
            <span><strong className="block text-lg font-extrabold tracking-tight text-white">{APP_CONFIG.brandName}</strong><span className="text-xs text-amber-300">{APP_CONFIG.tagline}</span></span>
          </Link>
          <p className="mt-4 max-w-sm text-sm leading-6 text-slate-400">A dine-in meal marketplace in preparation. Provider listings and payments will become available after the backend and business operations are verified.</p>
        </div>
        <nav aria-label="Explore Thali">
          <h2 className="text-xs font-bold uppercase tracking-wider text-white">Explore</h2>
          <ul className="mt-3 space-y-2 text-sm text-slate-400">
            <li><Link href="/explore" className="rounded hover:text-amber-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-amber-400">Approved kitchens</Link></li>
            <li><Link href="/provider/portal" className="rounded hover:text-amber-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-amber-400">List a mess</Link></li>
            <li><Link href="/faq" className="rounded hover:text-amber-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-amber-400">FAQ</Link></li>
          </ul>
        </nav>
        <nav aria-label="Policies">
          <h2 className="text-xs font-bold uppercase tracking-wider text-white">Policies</h2>
          <ul className="mt-3 space-y-2 text-sm text-slate-400">
            <li><Link href="/privacy" className="rounded hover:text-amber-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-amber-400">Privacy</Link></li>
            <li><Link href="/terms" className="rounded hover:text-amber-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-amber-400">Terms</Link></li>
            <li><Link href="/refund-policy" className="rounded hover:text-amber-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-amber-400">Refund information</Link></li>
          </ul>
        </nav>
      </div>
      <div className="border-t border-slate-800 px-4 py-4 text-center text-xs text-slate-500 sm:px-6">
        © {new Date().getFullYear()} {APP_CONFIG.brandName}. Pre-launch; no payment or provider listing is represented as live until verified.
      </div>
    </footer>
  );
}
