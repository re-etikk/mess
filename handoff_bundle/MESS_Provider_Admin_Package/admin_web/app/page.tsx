'use client';

import { useMemo, useState } from 'react';
import type { ComponentType, ReactNode } from 'react';
import {
  Activity, ArrowDownRight, ArrowUpRight, BadgeCheck, Bell, Building2,
  Check, ChevronDown, ChevronRight, CircleHelp, ClipboardList, Download,
  Eye, FileCheck2, Filter, LayoutDashboard, LifeBuoy, LockKeyhole, Menu,
  MoreHorizontal, Search, Settings2, ShieldCheck, SlidersHorizontal, Users, Utensils,
  Wallet, X, XCircle, ScrollText, UserCog, CircleDollarSign, CheckCircle2,
} from 'lucide-react';

type Provider = { id: string; name: string; owner: string; kind: string; location: string; submitted: string; status: 'Pending review' | 'Approved' | 'Needs changes' | 'Suspended'; docs: string };
type Section = 'Overview' | 'Provider applications' | 'Providers' | 'Customers' | 'Plans & menus' | 'Redemptions' | 'Payments & settlements' | 'Offers' | 'Support queue' | 'Team & roles' | 'Audit log' | 'System health';

const initialProviders: Provider[] = [
  { id: 'APP-1024', name: 'Radhe Mess', owner: 'A. Sharma', kind: 'Student mess', location: 'Sector 62, Noida', submitted: 'Today, 10:42', status: 'Pending review', docs: '2 of 3 checked' },
  { id: 'APP-1023', name: 'Ghar Ka Tiffin', owner: 'P. Verma', kind: 'Home tiffin service', location: 'Knowledge Park, Greater Noida', submitted: 'Yesterday', status: 'Pending review', docs: '3 of 3 uploaded' },
  { id: 'APP-1021', name: 'Campus Canteen', owner: 'S. Khan', kind: 'College canteen', location: 'Sector 63, Noida', submitted: '22 Oct', status: 'Needs changes', docs: 'Address proof missing' },
  { id: 'PRV-0081', name: 'Shree Mess', owner: 'M. Gupta', kind: 'Student mess', location: 'Sector 61, Noida', submitted: 'Approved 18 Oct', status: 'Approved', docs: 'Verified' },
];

const navItems: { label: Section; icon: ComponentType<{ size?: number }> }[] = [
  { label: 'Overview', icon: LayoutDashboard },
  { label: 'Provider applications', icon: FileCheck2 },
  { label: 'Providers', icon: Building2 },
  { label: 'Customers', icon: Users },
  { label: 'Plans & menus', icon: Utensils },
  { label: 'Redemptions', icon: ClipboardList },
  { label: 'Payments & settlements', icon: Wallet },
  { label: 'Offers', icon: CircleDollarSign },
  { label: 'Support queue', icon: LifeBuoy },
  { label: 'Team & roles', icon: UserCog },
  { label: 'Audit log', icon: ScrollText },
  { label: 'System health', icon: Activity },
];

export default function AdminPage() {
  const [section, setSection] = useState<Section>('Overview');
  const [providers, setProviders] = useState<Provider[]>(initialProviders);
  const [search, setSearch] = useState('');
  const [filter, setFilter] = useState('All');
  const [toast, setToast] = useState('');
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [previewSession, setPreviewSession] = useState(false);
  const [selectedProvider, setSelectedProvider] = useState<Provider | null>(null);
  const [pendingAction, setPendingAction] = useState<{ provider: Provider; action: 'approve' | 'changes' | 'suspend' } | null>(null);
  const [auditEvents, setAuditEvents] = useState<string[]>(['Admin opened overview', 'Provider APP-1023 submitted documents', 'Settlement reconciliation job completed (demo)']);

  const showToast = (message: string) => { setToast(message); window.setTimeout(() => setToast(''), 3000); };
  const visibleProviders = useMemo(() => providers.filter((p) => {
    const query = search.toLowerCase();
    const matchesQuery = `${p.name} ${p.owner} ${p.location} ${p.id}`.toLowerCase().includes(query);
    const matchesFilter = filter === 'All' || p.status === filter;
    return matchesQuery && matchesFilter;
  }), [providers, search, filter]);

  const resolveProviderAction = () => {
    if (!pendingAction) return;
    const { provider, action } = pendingAction;
    const nextStatus: Provider['status'] = action === 'approve' ? 'Approved' : action === 'changes' ? 'Needs changes' : 'Suspended';
    setProviders((list) => list.map((p) => p.id === provider.id ? { ...p, status: nextStatus } : p));
    const event = `${action.toUpperCase()} provider ${provider.id} (${provider.name})`; setAuditEvents((items) => [event, ...items]);
    showToast(`${provider.name}: ${nextStatus}. Demo state updated locally.`);
    setPendingAction(null); setSelectedProvider(null);
  };

  if (!previewSession) return <AdminLogin onPreview={() => setPreviewSession(true)} />;

  return (
    <div className="app-shell">
      <aside className={`sidebar ${sidebarOpen ? 'sidebar-open' : ''}`}>
        <div className="brand-row"><div className="brand-mark"><img src="/favicon.png" alt="MESS" /></div><div><strong>MESS</strong><span>OPERATIONS</span></div><button className="icon-button sidebar-close" aria-label="Close menu" onClick={() => setSidebarOpen(false)}><X size={18} /></button></div>
        <div className="workspace"><div className="workspace-icon"><ShieldCheck size={17} /></div><div><strong>Platform control</strong><small>Restricted workspace</small></div><ChevronDown size={15} /></div>
        <nav className="sidebar-nav" aria-label="Admin sections">
          <p className="nav-label">WORKSPACE</p>
          {navItems.slice(0, 9).map(({ label, icon: Icon }) => <button key={label} className={`nav-item ${section === label ? 'active' : ''}`} onClick={() => { setSection(label); setSidebarOpen(false); setSelectedProvider(null); }}><Icon size={17} /><span>{label}</span>{label === 'Provider applications' && <span className="nav-count">2</span>}</button>)}
          <p className="nav-label nav-label-gap">ADMINISTRATION</p>
          {navItems.slice(9).map(({ label, icon: Icon }) => <button key={label} className={`nav-item ${section === label ? 'active' : ''}`} onClick={() => { setSection(label); setSidebarOpen(false); setSelectedProvider(null); }}><Icon size={17} /><span>{label}</span></button>)}
        </nav>
        <div className="sidebar-bottom"><div className="help-card"><CircleHelp size={17} /><div><strong>Need a hand?</strong><small>View operations guide</small></div><ChevronRight size={15} /></div><div className="admin-user"><div className="avatar">AD</div><div className="user-copy"><strong>Admin workspace</strong><small>Demo role · Super Admin UI</small></div><MoreHorizontal size={18} /></div></div>
      </aside>
      {sidebarOpen && <button className="mobile-overlay" aria-label="Close navigation" onClick={() => setSidebarOpen(false)} />}

      <main className="main-area">
        <header className="topbar">
          <div className="topbar-left"><button className="icon-button menu-toggle" aria-label="Open navigation" onClick={() => setSidebarOpen(true)}><Menu size={20} /></button><div><div className="breadcrumbs">MESS <span>/</span> Operations</div><div className="topbar-title">{section}</div></div></div>
          <div className="topbar-actions"><div className="global-search"><Search size={17} /><input value={search} onChange={(e) => setSearch(e.target.value)} placeholder="Search records" aria-label="Search records" /><kbd>⌘ K</kbd></div><button className="icon-button top-notice" aria-label="Notifications" onClick={() => showToast('You are up to date in this demo workspace.')}><Bell size={18} /><i /></button><div className="top-avatar">AD</div></div>
        </header>

        <div className="page-content">
          <div className="demo-notice"><span className="demo-dot" /> DEMO WORKSPACE <span className="notice-separator">•</span> All displayed records are local sample data. No live customer or payment data is connected.</div>
          {selectedProvider ? <ProviderDetail provider={selectedProvider} onBack={() => setSelectedProvider(null)} onAction={(action) => setPendingAction({ provider: selectedProvider, action })} /> : renderSection()}
        </div>
      </main>

      {toast && <div className="toast"><CheckCircle2 size={18} />{toast}</div>}
      {pendingAction && <div className="modal-backdrop" role="presentation"><div className="confirm-modal" role="dialog" aria-modal="true" aria-labelledby="confirm-title"><div className="modal-icon"><ShieldCheck size={22} /></div><h2 id="confirm-title">Confirm provider action</h2><p>{pendingAction.action === 'approve' ? `Approve ${pendingAction.provider.name}? In production, verify documents and owner authorization before approval.` : pendingAction.action === 'changes' ? `Return ${pendingAction.provider.name}'s application for correction?` : `Suspend ${pendingAction.provider.name}? This should require a reason and audit entry in production.`}</p><div className="modal-actions"><button className="button button-secondary" onClick={() => setPendingAction(null)}>Cancel</button><button className="button button-primary" onClick={resolveProviderAction}>Confirm demo action</button></div></div></div>}
    </div>
  );

  function renderSection() {
    switch (section) {
      case 'Overview': return <Overview onNavigate={setSection} providers={providers} auditEvents={auditEvents} />;
      case 'Provider applications': return <ProviderTable title="Provider applications" subtitle="Review onboarding, location and required business documents before approval." providers={visibleProviders} onSelect={setSelectedProvider} onAction={(provider, action) => setPendingAction({ provider, action })} filter={filter} setFilter={setFilter} />;
      case 'Providers': return <ProviderTable title="All providers" subtitle="Review operational status and open a provider record." providers={visibleProviders.filter((p) => p.status !== 'Pending review')} onSelect={setSelectedProvider} onAction={(provider, action) => setPendingAction({ provider, action })} filter={filter} setFilter={setFilter} />;
      case 'Customers': return <GenericRecords title="Customers" subtitle="Customer support and account status. Restrict personal data to authorized staff." icon="users" rows={[['CUS-2041','Student account','Active','25 Oct'],['CUS-2037','Student account','Active','24 Oct'],['CUS-2022','Student account','Support review','22 Oct']]} onToast={showToast} />;
      case 'Plans & menus': return <GenericRecords title="Plans & menus" subtitle="Review published plan models, pricing snapshots and menu rule validation." icon="menu" rows={[['PLN-103','Fixed-period plan','Published','12 providers'],['PLN-104','Meal-tracker plan','Published','9 providers'],['MENU-092','Lunch menu overrides','Needs review','3 items']]} onToast={showToast} />;
      case 'Redemptions': return <GenericRecords title="Meal redemptions" subtitle="Inspect server-confirmed attendance and investigate duplicate or invalid scans." icon="redemption" rows={[['RDM-8401','Lunch · Provider QR','Confirmed','12:24 PM'],['RDM-8400','Lunch · Duplicate attempt','Rejected','12:20 PM'],['RDM-8398','Breakfast · Provider QR','Confirmed','8:42 AM']]} onToast={showToast} />;
      case 'Payments & settlements': return <GenericRecords title="Payments & settlements" subtitle="Reconcile gateway-confirmed transactions, refunds, platform fees and provider payouts." icon="payments" rows={[['PAY-2081','Subscription payment','Gateway confirmed','₹2,800'],['PAY-2078','Daily meal purchase','Gateway confirmed','₹90'],['SET-0041','Provider payout batch','Needs reconciliation','Pending']]} onToast={showToast} />;
      case 'Offers': return <GenericRecords title="Offers & promotions" subtitle="Check eligible plans, date windows, stacking and per-customer redemption limits." icon="offers" rows={[['OFF-014','WELCOME5','Draft','5%'],['OFF-011','LONGTERM','Published','Provider-approved'],['OFF-008','FESTIVE','Expired','Closed']]} onToast={showToast} />;
      case 'Support queue': return <GenericRecords title="Support queue" subtitle="Route customer, provider and payment issues with service-level priority." icon="support" rows={[['TKT-514','Payment reconciliation','High','Open'],['TKT-512','Incorrect meal slot','Normal','Investigating'],['TKT-505','Business address correction','Normal','Waiting']]} onToast={showToast} />;
      case 'Team & roles': return <TeamRoles onToast={showToast} />;
      case 'Audit log': return <AuditLog events={auditEvents} />;
      case 'System health': return <SystemHealth onToast={showToast} />;
    }
  }
}

function AdminLogin({ onPreview }: { onPreview: () => void }) {
  return <main className="admin-login-page"><div className="admin-login-card"><div className="login-brand"><div className="brand-mark"><img src="/favicon.png" alt="MESS" /></div><div><strong>MESS</strong><span>OPERATIONS CONSOLE</span></div></div><div className="eyebrow login-eyebrow">RESTRICTED WORKSPACE</div><h1>Sign in to operations</h1><p>Only authorized MESS team members should access provider verification, customer support and financial operations.</p><label className="login-label">Work email</label><input className="login-input" type="email" placeholder="name@company.com" autoComplete="username" aria-label="Work email"/><label className="login-label">Password</label><input className="login-input" type="password" placeholder="Enter your password" autoComplete="current-password" aria-label="Password"/><button className="button button-primary login-disabled" disabled><LockKeyhole size={16}/> Live sign-in not configured</button><button className="button button-secondary login-preview" onClick={onPreview}>Open demo console <ChevronRight size={15}/></button><div className="login-security"><ShieldCheck size={17}/><span>Production must use authenticated sessions, MFA, server-side role checks and audit logging. Demo access is local only.</span></div><small className="login-legal">MESS internal operations · Do not use sample records for decisions.</small></div></main>;
}

function Overview({ onNavigate, providers, auditEvents }: { onNavigate: (section: Section) => void; providers: Provider[]; auditEvents: string[] }) {
  return <>
    <div className="page-heading"><div><div className="eyebrow">{new Intl.DateTimeFormat('en-IN', { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric', timeZone: 'Asia/Kolkata' }).format(new Date()).toUpperCase()}</div><h1>Operations overview</h1><p>Review provider onboarding, meal operations and financial exceptions from one place.</p></div><button className="button button-secondary" onClick={() => onNavigate('Audit log')}><ScrollText size={16} /> View audit log</button></div>
    <div className="kpi-grid"><Kpi icon={<Building2 size={18}/>} label="Active providers" value="—" change="Data source not connected" tone="neutral" /><Kpi icon={<Users size={18}/>} label="Registered customers" value="—" change="Data source not connected" tone="neutral" /><Kpi icon={<ClipboardList size={18}/>} label="Redemptions today" value="—" change="Server data not connected" tone="neutral" /><Kpi icon={<Wallet size={18}/>} label="Gross transaction value" value="—" change="Ledger not connected" tone="neutral" /></div>
    <div className="overview-grid">
      <section className="panel panel-large"><div className="panel-heading"><div><h2>Needs attention</h2><p>Queues that require an authorized team member</p></div><button className="text-link" onClick={() => onNavigate('Provider applications')}>Open queue <ChevronRight size={15}/></button></div>
        <div className="attention-row"><div className="attention-icon amber"><FileCheck2 size={18}/></div><div className="attention-copy"><strong>Provider applications</strong><span>Sample queue state · live provider API not connected</span></div><button className="small-button" onClick={() => onNavigate('Provider applications')}>Review</button></div>
        <div className="attention-row"><div className="attention-icon red"><CircleDollarSign size={18}/></div><div className="attention-copy"><strong>Settlement reconciliation</strong><span>Example exception state · live settlement API not connected</span></div><button className="small-button" onClick={() => onNavigate('Payments & settlements')}>Open</button></div>
        <div className="attention-row"><div className="attention-icon blue"><LifeBuoy size={18}/></div><div className="attention-copy"><strong>Support tickets</strong><span>Example ticket state · live support API not connected</span></div><button className="small-button" onClick={() => onNavigate('Support queue')}>Open</button></div>
      </section>
      <section className="panel"><div className="panel-heading"><div><h2>Platform activity</h2><p>Recent audit entries</p></div><Activity size={18} className="muted-icon"/></div><div className="timeline">{auditEvents.slice(0, 4).map((event, index) => <div className="timeline-row" key={`${event}-${index}`}><span className={`timeline-point point-${index % 3}`} /><div><strong>{event}</strong><small>{index === 0 ? 'Just now' : `${index * 9} min ago`} · Demo audit</small></div></div>)}</div><button className="button button-secondary full-width" onClick={() => onNavigate('Audit log')}>View all events</button></section>
    </div>
    <div className="section-strip"><div><h2>Provider onboarding</h2><p>Review applications before business listings and plans are published.</p></div><button className="button button-primary" onClick={() => onNavigate('Provider applications')}>Review applications <ChevronRight size={16}/></button></div>
  </>;
}

function Kpi({ icon, label, value, change, tone }: { icon: ReactNode; label: string; value: string; change: string; tone: 'positive' | 'negative' | 'neutral' }) {
  return <div className="kpi-card"><div className="kpi-top"><span className="kpi-icon">{icon}</span><MoreHorizontal size={18} className="muted-icon" /></div><div className="kpi-label">{label}</div><div className="kpi-value">{value}</div><div className={`kpi-foot ${tone}`}>{tone === 'positive' ? <ArrowUpRight size={14}/> : tone === 'negative' ? <ArrowDownRight size={14}/> : <Activity size={13}/>} {change}</div></div>;
}

function ProviderTable({ title, subtitle, providers, onSelect, onAction, filter, setFilter }: { title: string; subtitle: string; providers: Provider[]; onSelect: (provider: Provider) => void; onAction: (provider: Provider, action: 'approve' | 'changes' | 'suspend') => void; filter: string; setFilter: (filter: string) => void }) {
  return <><div className="page-heading"><div><div className="eyebrow">DIRECTORY & VERIFICATION</div><h1>{title}</h1><p>{subtitle}</p></div><button className="button button-secondary" onClick={() => window.alert('Connect this action to an authorized server-side export endpoint.')}><Download size={16}/> Export</button></div>
    <div className="panel table-panel"><div className="table-toolbar"><div className="toolbar-title"><strong>{providers.length} sample records</strong><span>Fixtures only · connect provider API for live records</span></div><div className="toolbar-controls"><label className="filter-control"><Filter size={15}/><select value={filter} onChange={(e) => setFilter(e.target.value)} aria-label="Filter providers"><option>All</option><option>Pending review</option><option>Approved</option><option>Needs changes</option><option>Suspended</option></select><ChevronDown size={14}/></label><button className="icon-button control-filter" aria-label="Advanced filters" onClick={() => window.alert('Advanced filtering can be connected to server-backed filters.')}><SlidersHorizontal size={17}/></button></div></div>
      <div className="table-wrap"><table><thead><tr><th>Provider</th><th>Business type</th><th>Location</th><th>Documents</th><th>Status</th><th>Actions</th></tr></thead><tbody>{providers.map((provider) => <tr key={provider.id}><td data-label="Provider"><button className="provider-cell" onClick={() => onSelect(provider)}><span className="provider-avatar"><Building2 size={16}/></span><span><strong>{provider.name}</strong><small>{provider.id} · {provider.owner}</small></span></button></td><td data-label="Business type">{provider.kind}</td><td data-label="Location">{provider.location}</td><td data-label="Documents"><span className="doc-state"><FileCheck2 size={14}/>{provider.docs}</span></td><td data-label="Status"><StatusBadge status={provider.status}/></td><td data-label="Actions"><div className="row-actions"><button className="icon-button" aria-label={`View ${provider.name}`} onClick={() => onSelect(provider)}><Eye size={16}/></button><button className="icon-button" aria-label={`More actions ${provider.name}`} onClick={() => onAction(provider, provider.status === 'Approved' ? 'suspend' : 'approve')}><MoreHorizontal size={17}/></button></div></td></tr>)}</tbody></table>{providers.length === 0 && <div className="empty-state"><Search size={25}/><strong>No matching providers</strong><span>Change the search term or status filter.</span></div>}</div>
      <div className="table-footer"><span>Local demo records only</span><span>Permissions and filtering must be enforced by the backend in production.</span></div>
    </div></>;
}

function StatusBadge({ status }: { status: Provider['status'] }) { const className = status === 'Approved' ? 'status-green' : status === 'Pending review' ? 'status-amber' : status === 'Needs changes' ? 'status-blue' : 'status-red'; return <span className={`status-badge ${className}`}><span />{status}</span>; }

function ProviderDetail({ provider, onBack, onAction }: { provider: Provider; onBack: () => void; onAction: (action: 'approve' | 'changes' | 'suspend') => void }) {
  return <><button className="back-link" onClick={onBack}>← Back to providers</button><div className="page-heading"><div><div className="eyebrow">PROVIDER RECORD · {provider.id}</div><h1>{provider.name}</h1><p>{provider.kind} · {provider.location}</p></div><StatusBadge status={provider.status}/></div><div className="detail-grid"><section className="panel"><div className="panel-heading"><div><h2>Business profile</h2><p>Information submitted by the owner</p></div><Building2 size={19} className="muted-icon"/></div><DetailLine label="Business name" value={provider.name}/><DetailLine label="Owner / contact" value={provider.owner}/><DetailLine label="Business type" value={provider.kind}/><DetailLine label="Location" value={provider.location}/><DetailLine label="Application ID" value={provider.id}/><DetailLine label="Submitted" value={provider.submitted}/><DetailLine label="Documents" value={provider.docs}/><div className="detail-warning"><LockKeyhole size={17}/><span>Production approval must use verified documents, server-authorized actions and an immutable audit record.</span></div></section><section className="panel"><div className="panel-heading"><div><h2>Review checklist</h2><p>Require staff confirmation</p></div><BadgeCheck size={19} className="muted-icon"/></div>{['Owner identity confirmed','Address and location checked','Applicable food-business licence reviewed','Meal slots and plan rules reviewed','Provider commission terms accepted'].map((item) => <label key={item} className="check-row"><input type="checkbox"/><span>{item}</span></label>)}<div className="divider-line"/><div className="detail-actions"><button className="button button-secondary" onClick={() => onAction('changes')}><XCircle size={16}/> Request changes</button><button className="button button-primary" onClick={() => onAction(provider.status === 'Approved' ? 'suspend' : 'approve')}><Check size={16}/>{provider.status === 'Approved' ? 'Suspend provider' : 'Approve provider'}</button></div><p className="tiny-note">This is a local UI simulation. Real actions need role checks and server-side validation.</p></section></div></>;
}
function DetailLine({ label, value }: { label: string; value: string }) { return <div className="detail-line"><span>{label}</span><strong>{value}</strong></div>; }

function GenericRecords({ title, subtitle, rows, onToast }: { title: string; subtitle: string; icon: string; rows: string[][]; onToast: (message: string) => void }) {
  const [tab, setTab] = useState('All');
  return <><div className="page-heading"><div><div className="eyebrow">PLATFORM OPERATIONS</div><h1>{title}</h1><p>{subtitle}</p></div><button className="button button-secondary" onClick={() => onToast('Export is disabled until a server-backed report endpoint is configured.')}><Download size={16}/> Export</button></div><div className="panel table-panel"><div className="table-toolbar"><div className="toolbar-title"><strong>{rows.length} demo records</strong><span>Use search above or choose a view</span></div><div className="tab-group">{['All','Needs review','Recent'].map((item) => <button className={tab === item ? 'tab-active' : ''} key={item} onClick={() => setTab(item)}>{item}</button>)}</div></div><div className="generic-records">{(tab === 'Needs review' ? rows.filter((r) => r.some((v) => /pending|review|needs|open/i.test(v))) : tab === 'Recent' ? rows.slice(0, 2) : rows).map((row, i) => <div className="generic-row" key={`${row[0]}-${i}`}><div className="record-icon"><ClipboardList size={18}/></div><div className="record-primary"><strong>{row[1]}</strong><small>{row[0]} · Sample data</small></div><div className="record-state"><strong>{row[2]}</strong><small>{row[3]}</small></div><button className="icon-button" aria-label={`Open ${row[0]}`} onClick={() => onToast(`${row[0]} selected. Connect this record to the backend for full detail and authorized actions.`)}><ChevronRight size={18}/></button></div>)}</div>{rows.length === 0 && <div className="empty-state">No records</div>}<div className="table-footer"><span>Sample records only</span><span>Never use client-side-only authorization for admin data.</span></div></div></>;
}

function TeamRoles({ onToast }: { onToast: (message: string) => void }) {
  const people = [['Platform owner','Super Admin','Full operational control'],['Operations lead','Operations','Provider review and service issues'],['Finance reviewer','Finance','Payments, refunds and settlements'],['Customer support','Support','Tickets and limited customer details'],['Developer','Read-only / Technical','Masked logs, deployment health and feature status']];
  return <><div className="page-heading"><div><div className="eyebrow">ACCESS CONTROL</div><h1>Team & roles</h1><p>Apply least-privilege permissions. All privileged actions must be enforced server-side.</p></div><button className="button button-primary" onClick={() => onToast('Invite flow requires verified team identity and server-side role assignment.')}>+ Invite team member</button></div><div className="security-callout"><ShieldCheck size={21}/><div><strong>Role permissions are not just UI settings</strong><span>Use server-side access checks, MFA for privileged roles, session revocation and audit logs. Never trust editable profile metadata.</span></div></div><div className="panel role-table">{people.map(([name, role, scope]) => <div className="role-row" key={name}><div className="avatar">{name.split(' ').map((s) => s[0]).slice(0, 2).join('')}</div><div className="role-person"><strong>{name}</strong><small>{scope}</small></div><span className="role-pill">{role}</span><button className="icon-button" onClick={() => onToast(`Edit access for ${name}: implement approval and audit on the server.`)} aria-label={`Edit ${name}`}><Settings2 size={17}/></button></div>)}</div></>;
}
function AuditLog({ events }: { events: string[] }) { return <><div className="page-heading"><div><div className="eyebrow">TRACEABILITY</div><h1>Audit log</h1><p>Record every sensitive approval, role change, payment adjustment and provider action.</p></div><span className="status-badge status-green"><span/> Logging preview</span></div><div className="panel"><div className="panel-heading"><div><h2>Recent events</h2><p>Local demonstration events, not a production audit source</p></div><ScrollText size={18} className="muted-icon"/></div>{events.map((event, i) => <div className="audit-row" key={`${event}-${i}`}><span className="audit-marker"><Activity size={15}/></span><div><strong>{event}</strong><small>{new Date().toLocaleString()} · current demo session</small></div><span className="audit-tag">Recorded locally</span></div>)}</div></>; }
function SystemHealth({ onToast }: { onToast: (message: string) => void }) { const services = [['API / application server','Not connected','pending'],['Supabase database','Not connected','pending'],['Authentication provider','Not connected','pending'],['Payment webhooks','Not connected','pending'],['Daily QR issuance','Demo-only','warn'],['Error monitoring','Not connected','pending']]; return <><div className="page-heading"><div><div className="eyebrow">DEVELOPER OPERATIONS</div><h1>System health</h1><p>Connect real service health checks before using this panel for incident response.</p></div><button className="button button-secondary" onClick={() => onToast('Health checks cannot run until service endpoints are configured.')}>Refresh status</button></div><div className="service-grid">{services.map(([name, status, kind]) => <div className="service-card" key={name}><div className={`service-status ${kind}`}><span/></div><div><strong>{name}</strong><small>{status}</small></div><ChevronRight size={16} className="muted-icon"/></div>)}</div><div className="security-callout"><LockKeyhole size={20}/><div><strong>Do not expose secrets in the browser</strong><span>Keep service-role keys, payment secrets and database admin credentials in secured server-side configuration only.</span></div></div></>; }
