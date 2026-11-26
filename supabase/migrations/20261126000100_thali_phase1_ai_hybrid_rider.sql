-- Thali Phase 1 — AI/ML Metadata, Hybrid Fulfillment & Mess-Owned Rider Portal (2026-11-26)
-- Strictly additive & idempotent; safe to run right after 20261125000100_thali_behance_full_sync.sql.

-- 1. SUBSCRIPTIONS: Per-subscriber fulfillment mode ('pickup' | 'delivery') + optional drop address
alter table public.subscriptions
  add column if not exists fulfillment_mode text not null default 'pickup',
  add column if not exists delivery_address text;

-- 2. PROVIDER RIDERS: Mess-owned delivery staff (Name + Phone + 4-digit PIN -> zero platform APK)
create table if not exists public.provider_riders (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  name text not null,
  phone text not null,
  pin_code text not null,
  is_active boolean not null default true,
  last_lat numeric(9,6),
  last_lng numeric(9,6),
  last_location_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider_id, phone)
);

create index if not exists provider_riders_provider_idx
  on public.provider_riders(provider_id, is_active);

alter table public.provider_riders enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'provider_riders' and policyname = 'provider_riders_owner_all'
  ) then
    create policy "provider_riders_owner_all" on public.provider_riders
      for all using (
        exists (
          select 1 from public.providers p
          where p.id = provider_riders.provider_id and p.owner_user_id = auth.uid()
        )
      );
  end if;
end;
$$;

grant all on public.provider_riders to service_role;

-- 3. DAILY MEAL EVENTS: Live rider assignment & GPS telemetry
alter table public.daily_meal_events
  add column if not exists rider_id uuid references public.provider_riders(id) on delete set null,
  add column if not exists rider_name text,
  add column if not exists rider_phone text,
  add column if not exists rider_lat numeric(9,6),
  add column if not exists rider_lng numeric(9,6),
  add column if not exists rider_updated_at timestamptz,
  add column if not exists delivery_address text;

-- 4. MENU ITEMS: AI nutrition / spice estimation metadata
alter table public.menu_items
  add column if not exists estimated_calories integer,
  add column if not exists estimated_protein_g integer,
  add column if not exists spice_level text;
