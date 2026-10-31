import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'My Dashboard',
  robots: { index: false, follow: false },
};

export default function CustomerDashboardLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
