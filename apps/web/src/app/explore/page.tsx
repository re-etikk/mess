import type { Metadata } from 'next';
import ExploreClient from './ExploreClient';

export const metadata: Metadata = {
  title: 'Explore Mess & Tiffin Providers',
  description: 'Browse verified mess and tiffin providers near you. Find affordable breakfast, lunch and dinner options with flexible meal subscriptions.',
  alternates: { canonical: 'https://www.thali.store/explore' },
  openGraph: {
    title: 'Explore Local Mess & Tiffin Providers | Thali',
    description: 'Find affordable mess and tiffin providers for daily meals near you.',
    url: 'https://www.thali.store/explore',
  },
};

export default function ExplorePage() {
  return <ExploreClient />;
}
