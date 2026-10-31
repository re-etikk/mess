import type { Metadata } from 'next';
import './globals.css';
import Navbar from '@/components/Navbar';
import Footer from '@/components/Footer';
import { APP_CONFIG } from '@/lib/config';

const SITE_URL = 'https://www.thali.store';

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: `Thali — Your Meals. Your Choice.`,
    template: `%s | Thali`,
  },
  description: 'Thali connects students and professionals with local mess and tiffin providers for affordable daily meals. Find breakfast, lunch and dinner near you.',
  keywords: ['thali', 'mess', 'tiffin', 'daily meals', 'student food', 'local food', 'meal subscription'],
  authors: [{ name: 'Thali' }],
  creator: 'Thali',
  publisher: 'Thali',
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  openGraph: {
    type: 'website',
    locale: 'en_IN',
    url: SITE_URL,
    siteName: 'Thali',
    title: 'Thali — Your Meals. Your Choice.',
    description: 'Find local mess and tiffin providers for affordable daily breakfast, lunch and dinner near you.',
    images: [
      {
        url: '/brand/logo.png',
        width: 512,
        height: 512,
        alt: 'Thali — Local Meal Marketplace',
      },
    ],
  },
  twitter: {
    card: 'summary',
    title: 'Thali — Your Meals. Your Choice.',
    description: 'Find local mess and tiffin providers for affordable daily meals.',
    images: ['/brand/logo.png'],
  },
  icons: {
    icon: [
      { url: '/favicon.ico' },
      { url: '/favicon.png', type: 'image/png' },
    ],
    apple: '/apple-touch-icon.png',
  },
  alternates: {
    canonical: SITE_URL,
  },
};

const jsonLd = {
  '@context': 'https://schema.org',
  '@graph': [
    {
      '@type': 'WebSite',
      '@id': `${SITE_URL}/#website`,
      url: SITE_URL,
      name: 'Thali',
      description: 'Local meal marketplace connecting students and professionals with mess and tiffin providers.',
      inLanguage: 'en-IN',
    },
    {
      '@type': 'Organization',
      '@id': `${SITE_URL}/#organization`,
      name: 'Thali',
      url: SITE_URL,
      logo: {
        '@type': 'ImageObject',
        url: `${SITE_URL}/brand/logo.png`,
        width: 512,
        height: 512,
      },
      sameAs: [],
    },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <head>
        <script
          id="json-ld"
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      </head>
      <body className="min-h-screen flex flex-col bg-[#FDFBF7] text-[#0F172A] antialiased">
        <Navbar />
        <main className="flex-1">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
