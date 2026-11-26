-- Thali Complete Permission, OTP & Slot Cleanups (2026-11-27)
-- Safely idempotent: fixes `permission denied for table providers`, silent `menu_items` inserts,
-- `auth_otps` verification guarantees, `'all'` phantom slot cleanup, and public cover/DP storage.

-- 1. Restore full service_role access across public schema (cures 42501 permission denied on providers / menu_items / profiles / otps)
grant usage on schema public to service_role;
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant all privileges on all routines in schema public to service_role;

alter default privileges in schema public grant all privileges on tables to service_role;
alter default privileges in schema public grant all privileges on sequences to service_role;
alter default privileges in schema public grant all privileges on routines to service_role;

-- Ensure live kitchen open/closed column exists on providers
alter table public.providers
  add column if not exists is_accepting_orders boolean not null default true;

-- Public read access for diner discovery catalog
grant select on table
  public.providers,
  public.meal_slots,
  public.menu_items,
  public.subscription_plans,
  public.plan_meal_slots,
  public.provider_operating_hours
to anon, authenticated;

-- Ensure auth_otps exists with expected schema & is exclusively readable/writable via server service_role
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

alter table public.auth_otps
  add column if not exists purpose text not null default 'auth',
  add column if not exists verified boolean not null default false,
  add column if not exists verification_token text,
  add column if not exists attempts integer not null default 0,
  add column if not exists created_at timestamptz not null default now();

create index if not exists auth_otps_identifier_idx
  on public.auth_otps(identifier, created_at desc);

alter table public.auth_otps enable row level security;
revoke all on table public.auth_otps from anon, authenticated;
grant all privileges on table public.auth_otps to service_role;

-- 2. Remove or deactivate any phantom 'All' meal slot rows
update public.meal_slots
set active = false, updated_at = now()
where lower(trim(name)) = 'all';

do $$
begin
  delete from public.meal_slots
  where lower(trim(name)) = 'all'
    and not exists (
      select 1 from public.meal_bookings mb where mb.meal_slot_id = meal_slots.id
    )
    and not exists (
      select 1 from public.meal_redemptions mr where mr.meal_slot_id = meal_slots.id
    );
exception when others then
  null;
end;
$$;

-- 3. Ensure `thali-media` bucket exists & is public so kitchen covers & DPs persist across sessions
do $$
begin
  insert into storage.buckets (id, name, public)
  values ('thali-media', 'thali-media', true)
  on conflict (id) do update set public = true;
exception when others then
  null;
end;
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and policyname = 'thali_media_public_read'
  ) then
    create policy "thali_media_public_read" on storage.objects
      for select to anon, authenticated
      using (bucket_id = 'thali-media');
  end if;
exception when others then
  null;
end;
$$;
