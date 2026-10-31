import type { Metadata } from 'next';

export async function generateMetadata({ params }: { params: { id: string } }): Promise<Metadata> {
  return {
    title: 'Join Mess — Meal Subscription',
    description: 'Subscribe to a meal plan at a local mess or tiffin provider through Thali.',
    alternates: { canonical: `https://www.thali.store/join/${params.id}` },
  };
}

export default function JoinLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
