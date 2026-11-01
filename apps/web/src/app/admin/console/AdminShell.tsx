'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState } from 'react';
import {
  ChevronLeft,
  CircleHelp,
  CreditCard,
  ClipboardList,
  LayoutDashboard,
  Menu,
  ShieldCheck,
  Store,
  Users,
  X,
} from 'lucide-react';

const navItems = [
  { href: '/admin/console', label: 'Overview', icon: LayoutDashboard, exact: true },
  { href: '/admin/console/partners', label: 'Partners', icon: Store },
  { href: '/admin/console/customers', label: 'Customers', icon: Users },
  { href: '/admin/console/subscriptions', label: 'Subscriptions', icon: CreditCard },
  { href: '/admin/console/operations', label: 'Operations', icon: ClipboardList },
];

function titleForPath(path: string) {
  return navItems.find((item) => item.exact ? path === item.href : path.startsWith(item.href))?.label ?? 'Overview';
}

export default function AdminShell({ children, userId }: { children: React.ReactNode; userId: string }) {
  const pathname = usePathname() || '/admin/console';
  const router = useRouter();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [signingOut, setSigningOut] = useState(false);

  async function signOut() {
    setSigningOut(true);
    try {
      await fetch('/api/auth/logout', { method: 'POST' });
    } finally {
      router.replace('/');
      router.refresh();
    }
  }

  return (
    <div className={`admin-shell ${collapsed ? 'admin-shell-collapsed' : ''}`}>
      {mobileOpen && <button type="button" aria-label="Close admin navigation" className="admin-mobile-backdrop" onClick={() => setMobileOpen(false)} />}
      <aside className={`admin-sidebar ${mobileOpen ? 'admin-sidebar-open' : ''}`} aria-label="Admin navigation">
        <div className="admin-brand">
          <div className="admin-brand-mark">T</div>
          {!collapsed && <div><strong>THALI</strong><span>OPERATIONS</span></div>}
          <button type="button" className="admin-mobile-close" aria-label="Close admin navigation" onClick={() => setMobileOpen(false)}><X size={18} /></button>
        </div>
        {!collapsed && <div className="admin-workspace"><span className="admin-workspace-icon"><ShieldCheck size={16} /></span><div><strong>Private workspace</strong><small>Administrator access</small></div></div>}
        <p className="admin-nav-caption">PLATFORM</p>
        <nav className="admin-nav">
          {navItems.map(({ href, label, icon: Icon, exact }) => {
            const active = exact ? pathname === href : pathname.startsWith(href);
            return <Link key={href} href={href} title={collapsed ? label : undefined} aria-current={active ? 'page' : undefined} className={`admin-nav-link ${active ? 'admin-nav-link-active' : ''}`} onClick={() => setMobileOpen(false)}><Icon size={18} /><span>{label}</span></Link>;
          })}
        </nav>
        <div className="admin-sidebar-bottom">
          {!collapsed && <div className="admin-help"><CircleHelp size={17} /><span><strong>Need assistance?</strong><small>Contact platform support</small></span></div>}
          <div className="admin-profile"><span className="admin-avatar"><ShieldCheck size={15} aria-hidden="true" /></span>{!collapsed && <span className="admin-profile-copy"><strong>Administrator</strong><small title={userId}>{userId.slice(0, 8)}…</small></span>}<button type="button" onClick={() => void signOut()} disabled={signingOut} className="admin-signout" title="Sign out">{signingOut ? '…' : '↗'}</button></div>
        </div>
        <button type="button" onClick={() => setCollapsed((value) => !value)} className="admin-collapse" aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}><ChevronLeft size={17} /></button>
      </aside>

      <div className="admin-main">
        <header className="admin-topbar">
          <button type="button" className="admin-mobile-toggle" aria-label="Open admin navigation" onClick={() => setMobileOpen(true)}><Menu size={19} /></button>
          <div><p className="admin-topbar-kicker">THALI / ADMIN</p><h1>{titleForPath(pathname)}</h1></div>
          <span className="admin-role-pill"><ShieldCheck size={14} /> Administrator</span>
        </header>
        <div className="admin-content">{children}</div>
      </div>
    </div>
  );
}
