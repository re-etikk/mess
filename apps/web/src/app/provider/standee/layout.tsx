import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Counter Standee',
  robots: { index: false, follow: false },
};

export default function StandeeLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
