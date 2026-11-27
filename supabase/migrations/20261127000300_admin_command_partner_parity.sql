-- Thali Platform: Admin Command Center, RBAC, Support Desk, Offers, App Customization & Partner Web Parity
-- Safe, idempotent migration matching PostgreSQL 15+ and Supabase RLS standards.

-- 1. PLATFORM APP CONFIGURATION (Remote App Customization, Zones, Fees & Feature Flags)
create table if not exists public.platform_app_config (
  singleton boolean primary key default true check (singleton = true),
  hero_title text not null default 'Home-cooked meals from local messes',
  hero_subtitle text not null default 'Subscribe monthly or order a single plate from verified neighborhood kitchens.',
  hero_badge text not null default 'FRESH DAILY TIFFINS',
  active_cities jsonb not null default '["Noida","Bengaluru","Delhi","Gurugram","Pune","Hyderabad"]'::jsonb,
  default_commission_bps integer not null default 0 check (default_commission_bps >= 0 and default_commission_bps <= 5000),
  platform_fee_paise integer not null default 0 check (platform_fee_paise >= 0 and platform_fee_paise <= 50000),
  default_delivery_fee_paise integer not null default 0 check (default_delivery_fee_paise >= 0 and default_delivery_fee_paise <= 50000),
  free_delivery_above_paise integer not null default 0 check (free_delivery_above_paise >= 0),
  require_provider_approval boolean not null default true,
  customer_maintenance boolean not null default false,
  partner_maintenance boolean not null default false,
  maintenance_message text not null default 'Thali is undergoing quick scheduled maintenance. We will be back shortly.',
  min_customer_version text not null default '1.0.0',
  min_partner_version text not null default '1.0.0',
  feature_flags jsonb not null default '{"single_meal_orders":true,"cash_at_counter":true,"cashfree_online":true,"ai_features":true,"self_delivery":true,"snacks_slot":true,"banners_enabled":true}'::jsonb,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into public.platform_app_config (singleton) values (true) on conflict (singleton) do nothing;

alter table public.platform_app_config enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'platform_app_config' and policyname = 'app_config_public_read'
  ) then
    create policy "app_config_public_read" on public.platform_app_config for select using (true);
  end if;
end $$;
grant all on public.platform_app_config to service_role;
grant select on public.platform_app_config to anon, authenticated;

-- 2. ADMIN TEAM RBAC PERMISSIONS (Implements docs/ADMIN_SECURITY_MATRIX.md)
create table if not exists public.admin_team_permissions (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  admin_role text not null check (admin_role in ('super_admin','operations','finance','support','developer_readonly')),
  granted_by uuid references public.profiles(id) on delete set null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists admin_team_permissions_role_idx
  on public.admin_team_permissions(admin_role, revoked_at);

alter table public.admin_team_permissions enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'admin_team_permissions' and policyname = 'admin_team_own_read'
  ) then
    create policy "admin_team_own_read" on public.admin_team_permissions
      for select to authenticated using (user_id = auth.uid());
  end if;
end $$;
grant all on public.admin_team_permissions to service_role;
grant select on public.admin_team_permissions to authenticated;

-- 3. SUPPORT TICKETS UPGRADE + THREADED CONVERSATIONS
alter table public.support_tickets
  alter column created_by drop not null;

alter table public.support_tickets
  add column if not exists requester_name text,
  add column if not exists requester_email text,
  add column if not exists requester_phone text,
  add column if not exists requester_role text not null default 'customer',
  add column if not exists resolution_action text,
  add column if not exists promo_code_granted text,
  add column if not exists refund_amount_paise bigint;

create table if not exists public.support_ticket_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  sender_role text not null check (sender_role in ('customer','provider','admin','system')),
  sender_id uuid references public.profiles(id) on delete set null,
  sender_name text not null default 'Thali Support',
  message text not null,
  is_internal boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists support_ticket_messages_idx
  on public.support_ticket_messages(ticket_id, created_at asc);

alter table public.support_ticket_messages enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'support_ticket_messages' and policyname = 'support_msg_owner_select'
  ) then
    create policy "support_msg_owner_select" on public.support_ticket_messages
      for select to authenticated
      using (
        is_internal = false
        and exists (
          select 1 from public.support_tickets st
          where st.id = support_ticket_messages.ticket_id and st.created_by = auth.uid()
        )
      );
  end if;
end $$;
grant all on public.support_ticket_messages to service_role;
grant select on public.support_ticket_messages to authenticated;

-- 4. PROMO CODES UPGRADE + PER-USER REDEMPTIONS TRACKER
alter table public.promo_codes
  add column if not exists first_order_only boolean not null default false,
  add column if not exists max_uses_per_user integer,
  add column if not exists show_in_app boolean not null default true,
  add column if not exists created_by uuid references public.profiles(id) on delete set null;

create table if not exists public.promo_redemptions (
  id uuid primary key default gen_random_uuid(),
  promo_code_id uuid references public.promo_codes(id) on delete set null,
  code text not null,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid references public.providers(id) on delete set null,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  discount_paise bigint not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists promo_redemptions_code_user_idx
  on public.promo_redemptions(code, customer_id, created_at desc);

alter table public.promo_redemptions enable row level security;
grant all on public.promo_redemptions to service_role;

-- 5. PLATFORM & KITCHEN ANNOUNCEMENTS / BANNERS (Ensure presence + targeting fields)
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid references public.providers(id) on delete cascade,
  title text not null,
  body text not null,
  badge_text text default 'OFFER',
  action_url text,
  image_url text,
  is_featured boolean not null default false,
  starts_at timestamptz not null default now(),
  expires_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.announcements
  add column if not exists target_audience text not null default 'all',
  add column if not exists promo_code text,
  add column if not exists priority integer not null default 0,
  add column if not exists created_by uuid references public.profiles(id) on delete set null;

create index if not exists announcements_active_idx
  on public.announcements(is_active, priority desc, created_at desc);

alter table public.announcements enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'announcements' and policyname = 'announcements_read_public'
  ) then
    create policy "announcements_read_public" on public.announcements
      for select using (is_active = true);
  end if;
end $$;
grant all on public.announcements to service_role;
grant select on public.announcements to anon, authenticated;

-- 6. WALK-IN COUNTER ORDERS TABLE (Fixes /api/provider/orders 503 on Mobile & Web)
create table if not exists public.counter_orders (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  customer_name text not null,
  customer_phone text,
  slot text not null default 'LUNCH',
  items_summary text not null default 'Daily Meal',
  amount_paise bigint not null check (amount_paise >= 0),
  payment_mode text not null default 'counter_cash' check (payment_mode in ('counter_cash','counter_upi','online')),
  status text not null default 'completed',
  recorded_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists counter_orders_provider_idx
  on public.counter_orders(provider_id, created_at desc);

alter table public.counter_orders enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'counter_orders' and policyname = 'counter_orders_provider_all'
  ) then
    create policy "counter_orders_provider_all" on public.counter_orders
      for all to authenticated
      using (
        exists (
          select 1 from public.providers p
          where p.id = counter_orders.provider_id and p.owner_user_id = auth.uid()
        )
      )
      with check (
        exists (
          select 1 from public.providers p
          where p.id = counter_orders.provider_id and p.owner_user_id = auth.uid()
        )
      );
  end if;
end $$;
grant all on public.counter_orders to service_role;
grant select, insert on public.counter_orders to authenticated;

-- 7. PARTNER PERSISTENT IN-APP NOTIFICATIONS
create table if not exists public.partner_notifications (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  title text not null,
  message text not null,
  notification_type text not null default 'info',
  action_tab text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists partner_notifications_idx
  on public.partner_notifications(provider_id, is_read, created_at desc);

alter table public.partner_notifications enable row level security;
do $$
begin
  if not exists (
    select 1 from pg_policies where schemaname = 'public' and tablename = 'partner_notifications' and policyname = 'partner_notif_owner_all'
  ) then
    create policy "partner_notif_owner_all" on public.partner_notifications
      for all to authenticated
      using (
        exists (
          select 1 from public.providers p
          where p.id = partner_notifications.provider_id and p.owner_user_id = auth.uid()
        )
      );
  end if;
end $$;
grant all on public.partner_notifications to service_role;
grant select, update on public.partner_notifications to authenticated;

-- 8. MODERATION, FEATURED RANKING & MISSING SCHEMA COLUMNS
alter table public.profiles
  add column if not exists account_status text not null default 'active' check (account_status in ('active','suspended','blocked')),
  add column if not exists suspension_reason text,
  add column if not exists suspended_at timestamptz,
  add column if not exists suspended_by uuid references public.profiles(id) on delete set null;

alter table public.providers
  add column if not exists is_featured boolean not null default false,
  add column if not exists featured_rank integer not null default 100,
  add column if not exists commission_bps_override integer,
  add column if not exists is_verified_badge boolean not null default false,
  add column if not exists suspension_reason text;

alter table public.subscription_plans
  add column if not exists duration_days integer;

alter table public.subscriptions
  add column if not exists upgrade_from_subscription_id uuid;

-- 9. WIDEN customer_notifications.notification_type CHECK CONSTRAINT SAFELY
do $$
declare
  c record;
begin
  for c in
    select conname
    from pg_constraint
    where conrelid = 'public.customer_notifications'::regclass
      and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%notification_type%'
  loop
    execute format('alter table public.customer_notifications drop constraint %I', c.conname);
  end loop;
  alter table public.customer_notifications
    add constraint customer_notifications_type_check
    check (notification_type in ('meal_redemption','plan_expiry','menu_update','billing','offer','system','payment','subscription','support','info'));
exception when others then
  null;
end $$;
