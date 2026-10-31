import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Provider Portal',
  robots: { index: false, follow: false },
};

export default function ProviderPortalLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
