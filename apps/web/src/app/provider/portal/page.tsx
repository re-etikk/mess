'use client';

import { Suspense, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter, useSearchParams } from 'next/navigation';
import {
  Bell,
  ChefHat,
  CreditCard,
  LayoutDashboard,
  LifeBuoy,
  LogOut,
  ShieldCheck,
  Store,
  Truck,
  Users,
  UtensilsCrossed,
  Wallet,
} from 'lucide-react';
import PartnerOnboardingWizard from '@/components/provider-portal/PartnerOnboardingWizard';
import PartnerOverviewAndQueueTab from '@/components/provider-portal/PartnerOverviewAndQueueTab';
import PartnerMenuAndTimingsTab from '@/components/provider-portal/PartnerMenuAndTimingsTab';
import PartnerPlansAndQrTab from '@/components/provider-portal/PartnerPlansAndQrTab';
import PartnerApprovalsAndSubscribersTab from '@/components/provider-portal/PartnerApprovalsAndSubscribersTab';
import PartnerRidersAndFinanceTab from '@/components/provider-portal/PartnerRidersAndFinanceTab';
import PartnerProfileReviewsChatSupportTab from '@/components/provider-portal/PartnerProfileReviewsChatSupportTab';
import {
  CounterOrderItem,
  DeliveryRider,
  KitchenForecast,
  KitchenQueueItem,
  MealSlotConfig,
  MenuDish,
  PartnerMetrics,
  PartnerNotification,
  PartnerSession,
  PartnerTab,
  PendingApprovalItem,
  ProviderProfileDetails,
  SettlementRow,
  SubscriberItem,
  SubscriptionPlanItem,
} from '@/components/provider-portal/types';

function todayIstIso() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Kolkata' }).format(new Date());
}

function PartnerPortalInner() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const wantsRegister = searchParams.get('register') === '1';

  const [checkingAuth, setCheckingAuth] = useState(true);
  const [authenticated, setAuthenticated] = useState(false);
  const [userEmail, setUserEmail] = useState('');
  const [isAdmin, setIsAdmin] = useState(false);
  const [session, setSession] = useState<PartnerSession | null>(null);

  const [tab, setTab] = useState<PartnerTab>('overview');
  const [notice, setNotice] = useState('');
  const [noticeIsError, setNoticeIsError] = useState(false);

  const [isOpenToday, setIsOpenToday] = useState(true);
  const [togglingStatus, setTogglingStatus] = useState(false);

  const [metrics, setMetrics] = useState<PartnerMetrics | null>(null);
  const [forecast, setForecast] = useState<KitchenForecast | null>(null);
  const [recentRedemptions, setRecentRedemptions] = useState<any[]>([]);
  const [queueDate, setQueueDate] = useState(todayIstIso);
  const [queueSlot, setQueueSlot] = useState('LUNCH');
  const [queueItems, setQueueItems] = useState<KitchenQueueItem[]>([]);

  const [dishes, setDishes] = useState<MenuDish[]>([]);
  const [mealSlots, setMealSlots] = useState<MealSlotConfig[]>([]);
  const [operatingHours, setOperatingHours] = useState<any[]>([]);
  const [plans, setPlans] = useState<SubscriptionPlanItem[]>([]);
  const [pendingApprovals, setPendingApprovals] = useState<PendingApprovalItem[]>([]);
  const [subscribers, setSubscribers] = useState<SubscriberItem[]>([]);
  const [counterOrders, setCounterOrders] = useState<CounterOrderItem[]>([]);
  const [riders, setRiders] = useState<DeliveryRider[]>([]);
  const [settlements, setSettlements] = useState<SettlementRow[]>([]);
  const [paymentSettings, setPaymentSettings] = useState({
    upi_id: '',
    upi_name: '',
    upi_qr_url: '',
    account_number: '',
    ifsc_code: '',
    bank_name: '',
    branch_name: '',
    account_holder_name: '',
  });
  const [profile, setProfile] = useState<ProviderProfileDetails | null>(null);

  const [notifications, setNotifications] = useState<PartnerNotification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [showNotifs, setShowNotifs] = useState(false);

  const notify = useCallback((msg: string, isError = false) => {
    setNotice(msg);
    setNoticeIsError(isError);
  }, []);

  const loadAllPortalData = useCallback(
    async (providerId: string, qDate = queueDate, qSlot = queueSlot) => {
      const [
        dashRes,
        forecastRes,
        queueRes,
        menuRes,
        timingsRes,
        plansRes,
        pendingRes,
        subsRes,
        ordersRes,
        ridersRes,
        settleRes,
        paySetRes,
        profRes,
        notifRes,
      ] = await Promise.all([
        fetch(`/api/provider/dashboard?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/ai/kitchen-forecast?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/kitchen-queue?provider_id=${providerId}&date=${qDate}&slot=${qSlot}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/menu?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/timings?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/plans?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/subscriptions/pending?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/subscriptions?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/orders?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/delivery/riders?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/settlements?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/payment-settings?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/profile?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
        fetch(`/api/provider/notifications?provider_id=${providerId}`, { cache: 'no-store' }).then((r) => r.json()).catch(() => ({})),
      ]);

      if (dashRes?.success) {
        setIsOpenToday(dashRes.is_open_today !== false);
        setMetrics(dashRes.metrics || null);
        setRecentRedemptions(dashRes.today_redemptions || []);
      }
      if (forecastRes?.success) {
        setForecast(forecastRes);
      }
      if (queueRes?.success) {
        setQueueItems(queueRes.queue || []);
      }

      const loadedDishes: MenuDish[] = [];
      for (const m of menuRes?.menus || []) {
        const slotUpper = String(m.slot || 'LUNCH').toUpperCase();
        for (const item of m.items || []) {
          loadedDishes.push({
            id: item.id,
            name: item.name,
            is_add_on: Boolean(item.is_add_on),
            item_kind: item.item_kind || (item.is_add_on ? 'addon' : 'included'),
            price_paise: Number(item.price_paise || 0),
            price_inr: Math.round(Number(item.price_paise || 0) / 100),
            active: item.active !== false,
            day_of_week: item.day_of_week || 'Daily',
            slot: slotUpper,
            dietary_type: item.dietary_type || 'vegetarian',
            description: item.description,
          });
        }
      }
      setDishes(loadedDishes);
      setMealSlots(timingsRes?.slots || []);
      setOperatingHours(timingsRes?.operating_hours || []);

      setPlans(
        (plansRes?.plans || []).map((p: any) => ({
          id: p.id,
          name: p.name,
          description: p.description,
          plan_type: p.plan_type,
          duration_days: Number(p.duration_days || (p.duration_months ? p.duration_months * 30 : 30)),
          duration_months: p.duration_months,
          meal_credits: p.meal_credits,
          price_paise: Number(p.price_paise || 0),
          price_inr: Math.round(Number(p.price_paise || 0) / 100),
          discount_percent: p.discount_percent,
          published: p.published !== false,
          active: p.active !== false,
        }))
      );

      setPendingApprovals(pendingRes?.pending || []);
      setSubscribers(subsRes?.subscriptions || []);
      setCounterOrders(ordersRes?.orders || []);
      setRiders(ridersRes?.riders || []);
      setSettlements(settleRes?.settlements || settleRes?.items || []);
      if (paySetRes?.settings) setPaymentSettings(paySetRes.settings);
      if (profRes?.provider) setProfile(profRes.provider);
      setNotifications(notifRes?.notifications || []);
      setUnreadCount(Number(notifRes?.unread_count || 0));
    },
    [queueDate, queueSlot]
  );

  const bootstrapSession = useCallback(async () => {
    setCheckingAuth(true);
    try {
      const res = await fetch('/api/provider/session', { cache: 'no-store' });
      const data = await res.json().catch(() => ({}));
      setAuthenticated(Boolean(data.authenticated));
      setUserEmail(data.user?.email || '');
      setIsAdmin(Boolean(data.isAdmin));

      if (data.provider?.id) {
        const nextSess: PartnerSession = {
          providerId: data.provider.id,
          businessName: data.provider.display_name || 'Mess Partner',
          email: data.user?.email || '',
          phone: '',
          status: data.provider.status || 'active',
        };
        setSession(nextSess);
        if (nextSess.status === 'active') {
          await loadAllPortalData(nextSess.providerId);
        }
      } else {
        setSession(null);
      }
    } finally {
      setCheckingAuth(false);
    }
  }, [loadAllPortalData]);

  useEffect(() => {
    void bootstrapSession();
  }, [bootstrapSession]);

  async function toggleOpenToday() {
    if (!session?.providerId) return;
    setTogglingStatus(true);
    try {
      const next = !isOpenToday;
      const res = await fetch('/api/provider/status', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ provider_id: session.providerId, is_open: next }),
      });
      if (res.ok) {
        setIsOpenToday(next);
        notify(next ? 'Kitchen marked OPEN today.' : 'Kitchen marked CLOSED / OFF today.');
      }
    } finally {
      setTogglingStatus(false);
    }
  }

  async function markAllNotifsRead() {
    if (!session?.providerId) return;
    await fetch('/api/provider/notifications', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ provider_id: session.providerId }),
    });
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    setUnreadCount(0);
  }

  async function handleLogout() {
    await fetch('/api/auth/logout', { method: 'POST' }).catch(() => null);
    router.push('/partner/login');
    router.refresh();
  }

  if (checkingAuth) {
    return (
      <main className="min-h-screen bg-[#f7f5f0] flex items-center justify-center p-6">
        <p className="text-sm font-bold text-slate-600">Loading Partner Workspace...</p>
      </main>
    );
  }

  if (!authenticated && !wantsRegister && !session) {
    return (
      <main className="min-h-screen bg-[#f7f5f0] px-4 py-12">
        <div className="mx-auto max-w-lg rounded-2xl border border-slate-200 bg-white p-8 text-center shadow-sm space-y-4">
          <div className="mx-auto grid h-12 w-12 place-items-center rounded-xl bg-amber-50 text-amber-800">
            <Store size={24} />
          </div>
          <h1 className="text-2xl font-black text-slate-950">Thali Partner Portal</h1>
          <p className="text-xs text-slate-600 leading-5">
            Sign in with your Kitchen Partner email &amp; OTP or password to manage live meal queues, 7-day menus, counter QR, subscribers, riders, and settlements.
          </p>
          <div className="flex flex-wrap justify-center gap-3 pt-2">
            <Link href="/partner/login" className="rounded-xl bg-orange-600 px-5 py-2.5 text-xs font-bold text-white hover:bg-orange-700">
              Sign In to Partner Portal
            </Link>
            <button
              type="button"
              onClick={() => router.push('/provider/portal?register=1')}
              className="rounded-xl border border-slate-300 px-5 py-2.5 text-xs font-bold text-slate-800 hover:bg-slate-50"
            >
              Register New Kitchen
            </button>
          </div>
        </div>
      </main>
    );
  }

  if (!session || session.status !== 'active') {
    return (
      <main className="min-h-screen bg-[#f7f5f0] px-4 py-8 sm:px-6 lg:px-8">
        <PartnerOnboardingWizard
          authenticated={authenticated}
          userEmail={userEmail}
          session={session}
          onSessionCreated={async (created) => {
            setSession(created);
            if (created.status === 'active') {
              await loadAllPortalData(created.providerId);
            }
          }}
        />
      </main>
    );
  }

  const NAV_ITEMS: Array<{ id: PartnerTab; label: string; icon: React.ReactNode; badge?: number }> = [
    { id: 'overview', label: 'Overview', icon: <LayoutDashboard size={15} /> },
    { id: 'queue', label: 'Kitchen Queue', icon: <ChefHat size={15} /> },
    { id: 'menu', label: 'Menu & Timings', icon: <UtensilsCrossed size={15} /> },
    { id: 'plans', label: 'Plans & QR', icon: <CreditCard size={15} /> },
    { id: 'approvals', label: 'Approvals', icon: <ShieldCheck size={15} />, badge: pendingApprovals.length },
    { id: 'subscribers', label: 'Subscribers', icon: <Users size={15} /> },
    { id: 'riders', label: 'Riders', icon: <Truck size={15} /> },
    { id: 'finance', label: 'Finance', icon: <Wallet size={15} /> },
    { id: 'profile', label: 'Profile & Reviews', icon: <Store size={15} /> },
    { id: 'support', label: 'Chat & Support', icon: <LifeBuoy size={15} /> },
  ];

  return (
    <div className="min-h-screen bg-[#f7f5f0] text-slate-900">
      {/* TOP BAR */}
      <header className="sticky top-0 z-30 border-b border-slate-200 bg-white/95 backdrop-blur">
        <div className="mx-auto flex max-w-7xl flex-wrap items-center justify-between gap-3 px-4 py-3 sm:px-6">
          <div className="flex items-center gap-3">
            <div className="grid h-9 w-9 place-items-center rounded-xl bg-orange-600 text-white font-black">
              T
            </div>
            <div>
              <h1 className="text-sm font-black text-slate-950">{session.businessName}</h1>
              <p className="text-[11px] text-slate-500">{userEmail || 'Partner Workspace'}</p>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              disabled={togglingStatus}
              onClick={toggleOpenToday}
              className={`rounded-full px-3 py-1.5 text-xs font-bold border transition ${
                isOpenToday
                  ? 'border-emerald-200 bg-emerald-50 text-emerald-800 hover:bg-emerald-100'
                  : 'border-slate-900 bg-slate-900 text-white'
              }`}
            >
              {isOpenToday ? 'Serving Today · ON' : 'Closed Today · OFF'}
            </button>

            <div className="relative">
              <button
                type="button"
                onClick={() => {
                  const next = !showNotifs;
                  setShowNotifs(next);
                  if (next && unreadCount > 0) void markAllNotifsRead();
                }}
                className="relative rounded-xl border border-slate-200 p-2 text-slate-700 hover:bg-slate-50"
                title="Partner Notifications"
              >
                <Bell size={16} />
                {unreadCount > 0 && (
                  <span className="absolute -right-1 -top-1 flex h-4 w-4 items-center justify-center rounded-full bg-orange-600 text-[10px] font-black text-white">
                    {unreadCount}
                  </span>
                )}
              </button>

              {showNotifs && (
                <div className="absolute right-0 mt-2 w-80 rounded-2xl border border-slate-200 bg-white p-4 shadow-lg z-40">
                  <div className="flex items-center justify-between border-b border-slate-100 pb-2">
                    <span className="text-xs font-black text-slate-950">Kitchen Alerts</span>
                    <button type="button" onClick={() => setShowNotifs(false)} className="text-[11px] font-bold text-slate-500">
                      Close
                    </button>
                  </div>
                  {notifications.length === 0 ? (
                    <p className="py-4 text-center text-xs text-slate-500">No recent alerts.</p>
                  ) : (
                    <ul className="mt-2 max-h-64 space-y-2 overflow-y-auto text-xs">
                      {notifications.slice(0, 10).map((n) => (
                        <li key={n.id} className="rounded-xl bg-slate-50 p-2.5">
                          <p className="font-bold text-slate-900">{n.title}</p>
                          <p className="mt-0.5 text-slate-600">{n.message}</p>
                        </li>
                      ))}
                    </ul>
                  )}
                </div>
              )}
            </div>

            {isAdmin && (
              <Link href="/admin/console" className="rounded-xl border border-slate-300 px-3 py-1.5 text-xs font-bold text-slate-700 hover:bg-slate-50">
                Admin Console
              </Link>
            )}

            <button
              type="button"
              onClick={handleLogout}
              className="inline-flex items-center gap-1 rounded-xl border border-slate-200 px-3 py-1.5 text-xs font-bold text-slate-600 hover:bg-slate-50"
            >
              <LogOut size={13} /> Sign Out
            </button>
          </div>
        </div>

        {/* HORIZONTAL SCROLLABLE NAV */}
        <nav aria-label="Partner Modules" className="border-t border-slate-100 bg-white">
          <div className="mx-auto flex max-w-7xl gap-1 overflow-x-auto px-4 py-2 sm:px-6">
            {NAV_ITEMS.map((item) => (
              <button
                key={item.id}
                type="button"
                onClick={() => setTab(item.id)}
                className={`inline-flex shrink-0 items-center gap-1.5 rounded-xl px-3 py-2 text-xs font-bold transition ${
                  tab === item.id
                    ? 'bg-slate-900 text-white'
                    : 'text-slate-600 hover:bg-slate-100 hover:text-slate-950'
                }`}
              >
                {item.icon}
                <span>{item.label}</span>
                {item.badge ? (
                  <span className="rounded-full bg-orange-600 px-1.5 py-0.5 text-[10px] font-black text-white">
                    {item.badge}
                  </span>
                ) : null}
              </button>
            ))}
          </div>
        </nav>
      </header>

      {/* WORKSPACE CONTENT */}
      <main className="mx-auto max-w-7xl px-4 py-6 sm:px-6 space-y-5">
        {notice && (
          <div
            role={noticeIsError ? 'alert' : 'status'}
            className={`flex items-center justify-between rounded-xl border px-4 py-2.5 text-xs font-semibold ${
              noticeIsError
                ? 'border-red-200 bg-red-50 text-red-700'
                : 'border-emerald-200 bg-emerald-50 text-emerald-900'
            }`}
          >
            <span>{notice}</span>
            <button type="button" onClick={() => setNotice('')} className="ml-4 font-bold underline">
              Dismiss
            </button>
          </div>
        )}

        {(tab === 'overview' || tab === 'queue') && (
          <PartnerOverviewAndQueueTab
            mode={tab}
            providerId={session.providerId}
            businessName={session.businessName}
            isOpenToday={isOpenToday}
            onToggleOpen={toggleOpenToday}
            togglingStatus={togglingStatus}
            metrics={metrics}
            forecast={forecast}
            recentRedemptions={recentRedemptions}
            queueItems={queueItems}
            riders={riders}
            queueDate={queueDate}
            queueSlot={queueSlot}
            onQueueFilterChange={(nextDate, nextSlot) => {
              setQueueDate(nextDate);
              setQueueSlot(nextSlot);
              void loadAllPortalData(session.providerId, nextDate, nextSlot);
            }}
            onRefresh={() => loadAllPortalData(session.providerId)}
            onNotify={notify}
          />
        )}

        {tab === 'menu' && (
          <PartnerMenuAndTimingsTab
            providerId={session.providerId}
            dishes={dishes}
            mealSlots={mealSlots}
            operatingHours={operatingHours}
            onRefresh={() => loadAllPortalData(session.providerId)}
            onNotify={notify}
          />
        )}

        {tab === 'plans' && (
          <PartnerPlansAndQrTab
            providerId={session.providerId}
            businessName={session.businessName}
            plans={plans}
            mealSlots={mealSlots}
            onRefresh={() => loadAllPortalData(session.providerId)}
            onNotify={notify}
          />
        )}

        {(tab === 'approvals' || tab === 'subscribers') && (
          <PartnerApprovalsAndSubscribersTab
            mode={tab}
            providerId={session.providerId}
            pendingApprovals={pendingApprovals}
            subscribers={subscribers}
            plans={plans}
            counterOrders={counterOrders}
            onRefresh={() => loadAllPortalData(session.providerId)}
            onNotify={notify}
          />
        )}

        {(tab === 'riders' || tab === 'finance') && (
          <PartnerRidersAndFinanceTab
            mode={tab}
            providerId={session.providerId}
            riders={riders}
            settlements={settlements}
            initialPaymentSettings={paymentSettings}
            onRefresh={() => loadAllPortalData(session.providerId)}
            onNotify={notify}
          />
        )}

        {(tab === 'profile' || tab === 'support') && (
          <PartnerProfileReviewsChatSupportTab
            mode={tab}
            providerId={session.providerId}
            businessName={session.businessName}
            ownerEmail={userEmail}
            profile={profile}
            onRefresh={() => loadAllPortalData(session.providerId)}
            onNotify={notify}
          />
        )}
      </main>
    </div>
  );
}

export default function ProviderPortalPage() {
  return (
    <Suspense
      fallback={
        <main className="min-h-screen bg-[#f7f5f0] flex items-center justify-center p-6">
          <p className="text-sm font-bold text-slate-600">Loading Partner Workspace...</p>
        </main>
      }
    >
      <PartnerPortalInner />
    </Suspense>
  );
}
