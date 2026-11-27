'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useState } from 'react';
import type { LucideIcon } from 'lucide-react';
import {
  ChevronLeft,
  CircleHelp,
  ClipboardList,
  CreditCard,
  Headset,
  IndianRupee,
  LayoutDashboard,
  Menu,
  ShieldCheck,
  SlidersHorizontal,
  Store,
  Tag,
  Users,
  X,
} from 'lucide-react';
import type { AdminSubRole } from '@/lib/admin-rbac';

interface NavEntry {
  href: string;
  label: string;
  icon: LucideIcon;
  exact?: boolean;
  allowedRoles?: AdminSubRole[];
}

const navItems: NavEntry[] = [
  { href: '/admin/console', label: 'Overview', icon: LayoutDashboard, exact: true },
  {
    href: '/admin/console/support',
    label: 'Support Desk',
    icon: Headset,
    allowedRoles: ['super_admin', 'operations', 'finance', 'support'],
  },
  { href: '/admin/console/partners', label: 'Partners', icon: Store },
  { href: '/admin/console/customers', label: 'Customers', icon: Users },
  { href: '/admin/console/subscriptions', label: 'Subscriptions', icon: CreditCard },
  {
    href: '/admin/console/offers',
    label: 'Offers & Banners',
    icon: Tag,
    allowedRoles: ['super_admin', 'operations', 'support'],
  },
  {
    href: '/admin/console/customize',
    label: 'App Customize',
    icon: SlidersHorizontal,
    allowedRoles: ['super_admin', 'operations'],
  },
  {
    href: '/admin/console/finance',
    label: 'Finance & Payouts',
    icon: IndianRupee,
    allowedRoles: ['super_admin', 'finance'],
  },
  { href: '/admin/console/operations', label: 'Ops & Access', icon: ClipboardList },
];

const ROLE_LABELS: Record<AdminSubRole, string> = {
  super_admin: 'Super Admin',
  operations: 'Operations',
  finance: 'Finance',
  support: 'Support Desk',
  developer_readonly: 'Read-Only',
};

function titleForPath(path: string) {
  return navItems.find((item) => (item.exact ? path === item.href : path.startsWith(item.href)))?.label ?? 'Overview';
}

export default function AdminShell({
  children,
  userId,
  adminRole = 'super_admin',
}: {
  children: React.ReactNode;
  userId: string;
  adminRole?: AdminSubRole;
}) {
  const pathname = usePathname() || '/admin/console';
  const router = useRouter();
  const [collapsed, setCollapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [signingOut, setSigningOut] = useState(false);

  const visibleNav = navItems.filter((item) => !item.allowedRoles || item.allowedRoles.includes(adminRole));

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
      {mobileOpen && (
        <button
          type="button"
          aria-label="Close admin navigation"
          className="admin-mobile-backdrop"
          onClick={() => setMobileOpen(false)}
        />
      )}
      <aside className={`admin-sidebar ${mobileOpen ? 'admin-sidebar-open' : ''}`} aria-label="Admin navigation">
        <div className="admin-brand">
          <div className="admin-brand-mark">T</div>
          {!collapsed && (
            <div>
              <strong>THALI</strong>
              <span>COMMAND CENTER</span>
            </div>
          )}
          <button
            type="button"
            className="admin-mobile-close"
            aria-label="Close admin navigation"
            onClick={() => setMobileOpen(false)}
          >
            <X size={18} />
          </button>
        </div>

        {!collapsed && (
          <div className="admin-workspace">
            <span className="admin-workspace-icon">
              <ShieldCheck size={16} />
            </span>
            <div>
              <strong>Admin Workspace</strong>
              <small>{ROLE_LABELS[adminRole] || 'Administrator'}</small>
            </div>
          </div>
        )}

        <p className="admin-nav-caption">MODULES</p>
        <nav className="admin-nav">
          {visibleNav.map(({ href, label, icon: Icon, exact }) => {
            const active = exact ? pathname === href : pathname.startsWith(href);
            return (
              <Link
                key={href}
                href={href}
                title={collapsed ? label : undefined}
                aria-current={active ? 'page' : undefined}
                className={`admin-nav-link ${active ? 'admin-nav-link-active' : ''}`}
                onClick={() => setMobileOpen(false)}
              >
                <Icon size={17} />
                {!collapsed && <span>{label}</span>}
              </Link>
            );
          })}
        </nav>

        <div className="admin-sidebar-bottom">
          {!collapsed && (
            <Link href="/admin/console/support" className="admin-help" onClick={() => setMobileOpen(false)}>
              <CircleHelp size={17} />
              <span>
                <strong>Support Desk</strong>
                <small>Resolve customer & partner tickets</small>
              </span>
            </Link>
          )}
          <div className="admin-profile">
            <span className="admin-avatar">
              <ShieldCheck size={15} aria-hidden="true" />
            </span>
            {!collapsed && (
              <span className="admin-profile-copy">
                <strong>{ROLE_LABELS[adminRole]}</strong>
                <small title={userId}>{userId.slice(0, 8)}…</small>
              </span>
            )}
            <button
              type="button"
              onClick={() => void signOut()}
              disabled={signingOut}
              className="admin-signout"
              title="Sign out"
              aria-label="Sign out"
            >
              {signingOut ? '…' : '↗'}
            </button>
          </div>
        </div>

        <button
          type="button"
          onClick={() => setCollapsed((value) => !value)}
          className="admin-collapse"
          aria-label={collapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          <ChevronLeft size={17} />
        </button>
      </aside>

      <div className="admin-main">
        <header className="admin-topbar">
          <button
            type="button"
            className="admin-mobile-toggle"
            aria-label="Open admin navigation"
            onClick={() => setMobileOpen(true)}
          >
            <Menu size={19} />
          </button>
          <div>
            <h1>{titleForPath(pathname)}</h1>
          </div>
          <span className="admin-role-pill">
            <ShieldCheck size={14} /> {ROLE_LABELS[adminRole]}
          </span>
        </header>
        <div className="admin-content">{children}</div>
      </div>
    </div>
  );
}
