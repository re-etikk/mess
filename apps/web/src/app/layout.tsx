import type { Metadata } from 'next';
import './globals.css';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import { APP_CONFIG } from '@/lib/config';

export const metadata: Metadata = {
  title: `${APP_CONFIG.brandName} — ${APP_CONFIG.tagline}`,
  description:
    `${APP_CONFIG.brandName} is preparing a local meal marketplace. Provider listings and checkout are not available yet.`,
  icons: {
    icon: '/brand/logo.png',
    apple: '/brand/logo.png',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="min-h-screen flex flex-col bg-[#FDFBF7] text-[#0F172A] antialiased">
        <Navbar />
        <main className="flex-1">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
