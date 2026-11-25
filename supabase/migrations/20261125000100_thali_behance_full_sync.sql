-- Thali & Thali Partner — Self-Contained Complete Sync Migration (2026-11-26)
-- Strictly additive & idempotent; safe even if prior optional feature migrations were skipped.

-- 1. PROFILES: Food preference, email, default coordinates & onboarding flag
alter table public.profiles
  add column if not exists email text,
  add column if not exists food_preference text default 'veg',
  add column if not exists default_address text,
  add column if not exists default_locality text,
  add column if not exists default_city text,
  add column if not exists latitude numeric(9,6),
  add column if not exists longitude numeric(9,6),
  add column if not exists onboarding_completed boolean not null default false;

-- 2. PROVIDERS: Kitchen capabilities, delivery toggle, skip policy & live status
alter table public.providers
  add column if not exists supports_pickup boolean not null default true,
  add column if not exists supports_delivery boolean not null default false,
  add column if not exists allows_takeaway boolean not null default true,
  add column if not exists allows_monthly_plans boolean not null default true,
  add column if not exists supports_reusable_tiffin boolean not null default true,
  add column if not exists supports_disposable_box boolean not null default false,
  add column if not exists disposable_fee_paise bigint not null default 500,
  add column if not exists max_skips_per_week integer not null default 2,
  add column if not exists skip_cutoff_minutes integer not null default 120,
  add column if not exists is_accepting_orders boolean not null default true,
  add column if not exists contact_secondary_name text,
  add column if not exists contact_secondary_phone text;

-- 3. MENU ITEMS: 7-day schedules, add-ons vs specials
alter table public.menu_items
  add column if not exists day_of_week text not null default 'Daily',
  add column if not exists item_kind text not null default 'included';

create index if not exists menu_items_provider_day_idx
  on public.menu_items(provider_id, day_of_week, active);

-- 4. MESS REVIEWS: Create if missing + add photos & partner reply columns
create table if not exists public.mess_reviews (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  review_text text,
  food_quality_score integer check (food_quality_score between 1 and 5),
  hygiene_score integer check (hygiene_score between 1 and 5),
  service_score integer check (service_score between 1 and 5),
  tags text[] default '{}',
  image_paths text[] default '{}',
  partner_reply text,
  partner_replied_at timestamptz,
  is_verified_subscriber boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.mess_reviews
  add column if not exists image_paths text[] default '{}',
  add column if not exists partner_reply text,
  add column if not exists partner_replied_at timestamptz,
  add column if not exists is_verified_subscriber boolean not null default true;

create index if not exists mess_reviews_provider_idx
  on public.mess_reviews(provider_id, created_at desc);

alter table public.mess_reviews enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'mess_reviews' and policyname = 'reviews_read_public'
  ) then
    create policy "reviews_read_public" on public.mess_reviews for select using (true);
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'mess_reviews' and policyname = 'reviews_insert_authenticated'
  ) then
    create policy "reviews_insert_authenticated" on public.mess_reviews
      for insert with check (customer_id = auth.uid());
  end if;
end;
$$;

grant all on public.mess_reviews to service_role;
grant select, insert on public.mess_reviews to authenticated;
grant select on public.mess_reviews to anon;

-- 5. PROMO CODES: Create if missing before seeding THALI50
create table if not exists public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  provider_id uuid references public.providers(id) on delete cascade,
  title text not null,
  description text,
  discount_percent integer check (discount_percent between 1 and 100),
  flat_discount_paise bigint check (flat_discount_paise >= 0),
  min_order_paise bigint not null default 0,
  max_discount_paise bigint,
  applicable_to_plans boolean not null default true,
  applicable_to_daily boolean not null default true,
  valid_from timestamptz not null default now(),
  valid_until timestamptz,
  usage_limit integer,
  times_used integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists promo_codes_code_active_idx
  on public.promo_codes(code, is_active);

alter table public.promo_codes enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'promo_codes' and policyname = 'promos_read_public'
  ) then
    create policy "promos_read_public" on public.promo_codes
      for select using (is_active = true);
  end if;
end;
$$;

grant all on public.promo_codes to service_role;
grant select on public.promo_codes to anon, authenticated;

-- 6. CUSTOMER NOTIFICATIONS: Create if missing
create table if not exists public.customer_notifications (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  notification_type text not null default 'info',
  action_route text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists customer_notifications_idx
  on public.customer_notifications(customer_id, is_read, created_at desc);

alter table public.customer_notifications enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'customer_notifications' and policyname = 'notifications_read_owner'
  ) then
    create policy "notifications_read_owner" on public.customer_notifications
      for select using (customer_id = auth.uid());
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'customer_notifications' and policyname = 'notifications_update_owner'
  ) then
    create policy "notifications_update_owner" on public.customer_notifications
      for update using (customer_id = auth.uid());
  end if;
end;
$$;

grant all on public.customer_notifications to service_role;
grant select, update on public.customer_notifications to authenticated;

-- 7. SUBSCRIPTIONS: Create/Review preferences, Option B mode, Repeat days, Pause & Cancel survey
alter table public.subscriptions
  add column if not exists duration_days integer,
  add column if not exists selected_slots jsonb not null default '{}'::jsonb,
  add column if not exists repeat_days smallint[] not null default '{1,2,3,4,5,6,7}',
  add column if not exists packaging_preference text not null default 'reusable_tiffin',
  add column if not exists delivery_instructions text,
  add column if not exists promo_code text,
  add column if not exists discount_paise bigint not null default 0,
  add column if not exists payment_mode text not null default 'cashfree_online',
  add column if not exists auto_renewal boolean not null default false,
  add column if not exists reminder_days_before integer not null default 2,
  add column if not exists whatsapp_updates boolean not null default false,
  add column if not exists pause_started_at timestamptz,
  add column if not exists pause_ends_at timestamptz,
  add column if not exists paused_days_total integer not null default 0,
  add column if not exists skip_allowance integer not null default 2,
  add column if not exists skips_used integer not null default 0,
  add column if not exists cancellation_reason text;

-- 8. DAILY MEAL EVENTS: Coordinates Customer My Meals <-> Partner Kitchen Queue
create table if not exists public.daily_meal_events (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.subscriptions(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid not null references public.providers(id) on delete cascade,
  service_date date not null,
  slot text not null check (slot in ('BREAKFAST','LUNCH','DINNER','SNACKS')),
  status text not null default 'scheduled'
    check (status in ('scheduled','preparing','out_for_delivery','ready_at_counter','delivered','skipped','cancelled_by_kitchen')),
  custom_time_slot text,
  instructions text,
  addons_snapshot jsonb not null default '[]'::jsonb,
  fulfillment_mode text not null default 'delivery',
  eta_minutes integer,
  skipped_at timestamptz,
  skip_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (subscription_id, service_date, slot)
);

create index if not exists daily_meal_events_customer_date_idx
  on public.daily_meal_events(customer_id, service_date desc);
create index if not exists daily_meal_events_provider_date_idx
  on public.daily_meal_events(provider_id, service_date, slot, status);

alter table public.daily_meal_events enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'daily_meal_events' and policyname = 'dme_customer_read'
  ) then
    create policy "dme_customer_read" on public.daily_meal_events
      for select using (customer_id = auth.uid());
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'daily_meal_events' and policyname = 'dme_provider_all'
  ) then
    create policy "dme_provider_all" on public.daily_meal_events
      for all using (
        exists (
          select 1 from public.providers p
          where p.id = daily_meal_events.provider_id and p.owner_user_id = auth.uid()
        )
      );
  end if;
end;
$$;

grant all on public.daily_meal_events to service_role;
grant select, insert, update on public.daily_meal_events to authenticated;

-- 9. AUTH OTPS TABLE
create table if not exists public.auth_otps (
  id uuid primary key default gen_random_uuid(),
  identifier text not null,
  otp_code text not null,
  purpose text not null default 'auth',
  expires_at timestamptz not null,
  verified boolean not null default false,
  verification_token text,
  attempts integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists auth_otps_identifier_idx on public.auth_otps(identifier, created_at desc);
grant all on public.auth_otps to service_role;

-- 10. OPTIONAL PUBLIC STORAGE BUCKET FOR KITCHEN & DISH PHOTOS (safe no-op if unavailable)
do $$
begin
  insert into storage.buckets (id, name, public)
  values ('thali-media', 'thali-media', true)
  on conflict (id) do nothing;
exception when others then
  null;
end;
$$;

-- 11. REAL PROMO SEED (THALI50 flat ₹50 off + STUDENT50)
insert into public.promo_codes (code, provider_id, title, description, flat_discount_paise, min_order_paise, is_active)
values
  ('THALI50', null, 'Save ₹50 with THALI50', 'Flat ₹50 off on subscriptions of ₹500 or more.', 5000, 50000, true),
  ('STUDENT50', null, 'Student Saver ₹50', 'Flat ₹50 off on orders ₹500 and above.', 5000, 50000, true)
on conflict (code) do nothing;
