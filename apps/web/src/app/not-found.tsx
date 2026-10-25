import Link from 'next/link';
import { APP_CONFIG } from '@/lib/config';
import { AlertCircle, Home, QrCode, LifeBuoy } from 'lucide-react';

export const metadata = {
  title: `Page Not Found | ${APP_CONFIG.brandName}`,
  description: 'The requested page could not be found on MESS.',
};

export default function NotFound() {
  return (
    <div className="min-h-[70vh] flex items-center justify-center px-4 py-16">
      <div className="max-w-md w-full text-center space-y-6 bg-white border border-slate-200 rounded-xl p-8 shadow-sm">
        <div className="w-14 h-14 mx-auto rounded-lg bg-amber-50 border border-amber-200 flex items-center justify-center text-amber-700">
          <AlertCircle className="w-7 h-7" />
        </div>

        <div className="space-y-2">
          <span className="text-xs font-bold text-amber-700 uppercase tracking-wider block">Error 404</span>
          <h1 className="text-2xl font-extrabold text-slate-900 tracking-tight">
            Page Not Found
          </h1>
          <p className="text-xs text-slate-600 leading-relaxed">
            The page or kitchen resource you requested does not exist, may have expired, or was moved.
          </p>
        </div>

        <div className="pt-2 space-y-2 text-xs">
          <Link
            href="/"
            className="w-full flex items-center justify-center space-x-2 bg-slate-900 hover:bg-slate-800 text-white font-semibold py-2.5 px-4 rounded-lg transition-colors"
          >
            <Home className="w-4 h-4" />
            <span>Return to Home & Explore Kitchens</span>
          </Link>

          <Link
            href="/customer/dashboard"
            className="w-full flex items-center justify-center space-x-2 bg-amber-500 hover:bg-amber-600 text-white font-semibold py-2.5 px-4 rounded-lg transition-colors"
          >
            <QrCode className="w-4 h-4" />
            <span>Open Customer Meal Pass</span>
          </Link>

          <Link
            href="/contact"
            className="w-full flex items-center justify-center space-x-2 border border-slate-300 hover:bg-slate-50 text-slate-700 font-semibold py-2.5 px-4 rounded-lg transition-colors"
          >
            <LifeBuoy className="w-4 h-4" />
            <span>Contact Helpdesk & Grievance</span>
          </Link>
        </div>
      </div>
    </div>
  );
}
