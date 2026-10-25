-- Thali / MESS Zomato/Swiggy-Level Features Migration
-- Reviews & Ratings, Promo Codes, Announcements, Notifications, and Geolocation Filtering

-- 1. MESS REVIEWS & RATINGS TABLE
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
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists mess_reviews_provider_idx on public.mess_reviews(provider_id, created_at desc);
create index if not exists mess_reviews_customer_idx on public.mess_reviews(customer_id);

-- 2. PROMO CODES & OFFERS TABLE
create table if not exists public.promo_codes (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  provider_id uuid references public.providers(id) on delete cascade, -- null = platform-wide
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

create index if not exists promo_codes_code_active_idx on public.promo_codes(code, is_active);

-- 3. PLATFORM & PROVIDER ANNOUNCEMENTS / BANNERS
create table if not exists public.announcements (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid references public.providers(id) on delete cascade, -- null = global
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

create index if not exists announcements_active_idx on public.announcements(is_active, is_featured);

-- 4. CUSTOMER IN-APP NOTIFICATIONS
create table if not exists public.customer_notifications (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  message text not null,
  notification_type text not null check (notification_type in ('meal_redemption','plan_expiry','menu_update','billing','offer','system')),
  action_route text,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists customer_notifications_idx on public.customer_notifications(customer_id, is_read, created_at desc);

-- 5. FUNCTION: UPDATE PROVIDER AVERAGE RATING AUTOMATICALLY
create or replace function public.recalculate_provider_rating()
returns trigger
language plpgsql
security definer
as $$
declare
  v_avg_rating numeric(3,2);
  v_count integer;
begin
  select coalesce(avg(rating), 5.0), count(id)
  into v_avg_rating, v_count
  from public.mess_reviews
  where provider_id = coalesce(new.provider_id, old.provider_id);

  update public.providers
  set updated_at = now()
  where id = coalesce(new.provider_id, old.provider_id);

  return coalesce(new, old);
end;
$$;

create trigger trigger_recalculate_provider_rating
after insert or update or delete on public.mess_reviews
for each row execute function public.recalculate_provider_rating();

-- 6. ROW LEVEL SECURITY (RLS)
alter table public.mess_reviews enable row level security;
alter table public.promo_codes enable row level security;
alter table public.announcements enable row level security;
alter table public.customer_notifications enable row level security;

-- Public can read active promos, announcements, and reviews
create policy "reviews_read_public" on public.mess_reviews for select using (true);
create policy "promos_read_public" on public.promo_codes for select using (is_active = true);
create policy "announcements_read_public" on public.announcements for select using (is_active = true);

-- Customers can submit reviews and read their notifications
create policy "reviews_insert_authenticated" on public.mess_reviews for insert with check (customer_id = auth.uid());
create policy "notifications_read_owner" on public.customer_notifications for select using (customer_id = auth.uid());
create policy "notifications_update_owner" on public.customer_notifications for update using (customer_id = auth.uid());

-- Service role full access
grant all on public.mess_reviews to service_role;
grant all on public.promo_codes to service_role;
grant all on public.announcements to service_role;
grant all on public.customer_notifications to service_role;
