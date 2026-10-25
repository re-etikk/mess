-- Thali / MESS Complete Platform Migration: Menus, Addons, Invoices, Redemptions, and Atomic Procedures
-- Compatible with PostgreSQL 15+ and Supabase

-- 1. MENUS TABLE
create table if not exists public.menus (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  day_of_week text not null default 'Daily' check (day_of_week in ('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday','Daily')),
  slot text not null check (slot in ('BREAKFAST','LUNCH','SNACKS','DINNER','ALL')),
  items_included text[] not null default '{}',
  items_extra jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider_id, day_of_week, slot)
);

create index if not exists menus_provider_slot_idx on public.menus(provider_id, slot, is_active);

-- 2. ADDONS TABLE
create table if not exists public.addons (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  plan_id uuid references public.subscription_plans(id) on delete set null,
  item_name text not null,
  price_paise bigint not null default 0 check (price_paise >= 0),
  category text not null default 'addon',
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists addons_provider_idx on public.addons(provider_id, is_available);

-- 3. INVOICES TABLE
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  period_start timestamptz not null,
  period_end timestamptz not null,
  total_scans integer not null default 0 check (total_scans >= 0),
  total_due_paise bigint not null default 0 check (total_due_paise >= 0),
  razorpay_invoice_id text,
  razorpay_payment_id text,
  status text not null default 'pending' check (status in ('pending','paid','failed','waived')),
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists invoices_provider_status_idx on public.invoices(provider_id, status);

-- 4. REDEMPTIONS LEDGER (Single idempotent redemption per customer per slot per date)
create table if not exists public.redemptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid not null references public.providers(id) on delete cascade,
  subscription_id uuid references public.subscriptions(id) on delete set null,
  date date not null,
  slot text not null check (slot in ('BREAKFAST','LUNCH','SNACKS','DINNER','ALL')),
  amount_extra_paise bigint not null default 0 check (amount_extra_paise >= 0),
  extra_items jsonb not null default '[]'::jsonb,
  remarks text,
  redeemed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, provider_id, date, slot)
);

create index if not exists redemptions_user_date_idx on public.redemptions(user_id, date desc);
create index if not exists redemptions_provider_date_idx on public.redemptions(provider_id, date desc);

-- 5. ROW LEVEL SECURITY (RLS) POLICIES
alter table public.menus enable row level security;
alter table public.addons enable row level security;
alter table public.invoices enable row level security;
alter table public.redemptions enable row level security;

-- Menus: Publicly readable, editable by provider owner or manager
create policy "menus_read_all" on public.menus
  for select using (true);

create policy "menus_write_provider" on public.menus
  for all using (
    exists (
      select 1 from public.providers p
      where p.id = menus.provider_id
      and p.owner_user_id = auth.uid()
    )
    or exists (
      select 1 from public.provider_memberships m
      where m.provider_id = menus.provider_id
      and m.user_id = auth.uid()
      and m.active = true
    )
  );

-- Addons: Publicly readable, editable by provider owner
create policy "addons_read_all" on public.addons
  for select using (true);

create policy "addons_write_provider" on public.addons
  for all using (
    exists (
      select 1 from public.providers p
      where p.id = addons.provider_id
      and p.owner_user_id = auth.uid()
    )
  );

-- Invoices: Viewable by provider owner and admins
create policy "invoices_read_provider" on public.invoices
  for select using (
    exists (
      select 1 from public.providers p
      where p.id = invoices.provider_id
      and p.owner_user_id = auth.uid()
    )
  );

-- Redemptions: Customers see own, providers see their mess redemptions
create policy "redemptions_read_customer" on public.redemptions
  for select using (user_id = auth.uid());

create policy "redemptions_read_provider" on public.redemptions
  for select using (
    exists (
      select 1 from public.providers p
      where p.id = redemptions.provider_id
      and p.owner_user_id = auth.uid()
    )
  );

-- Service role bypass for all tables
grant all on public.menus to service_role;
grant all on public.addons to service_role;
grant all on public.invoices to service_role;
grant all on public.redemptions to service_role;

-- 6. ATOMIC REDEMPTION STORED PROCEDURE
create or replace function public.process_meal_redemption(
  p_user_id uuid,
  p_provider_id uuid,
  p_date date,
  p_slot text,
  p_extra_items jsonb default '[]'::jsonb,
  p_amount_extra_paise bigint default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_existing_id uuid;
  v_sub record;
  v_new_credits integer;
  v_redemption_id uuid;
begin
  -- 1. Check for duplicate scan for the same slot today
  select id into v_existing_id
  from public.redemptions
  where user_id = p_user_id
    and provider_id = p_provider_id
    and date = p_date
    and slot = p_slot;

  if v_existing_id is not null then
    return jsonb_build_object(
      'success', false,
      'error', 'Meal already redeemed for this slot today.',
      'code', 'ALREADY_REDEEMED'
    );
  end if;

  -- 2. Find active subscription for user and provider
  select * into v_sub
  from public.subscriptions
  where customer_id = p_user_id
    and provider_id = p_provider_id
    and status = 'active'
    and (expires_at is null or expires_at >= now())
  order by created_at desc
  limit 1;

  if v_sub.id is null then
    return jsonb_build_object(
      'success', false,
      'error', 'No active subscription or meal credit found for this mess.',
      'code', 'NO_ACTIVE_SUBSCRIPTION'
    );
  end if;

  -- 3. If meal tracker plan, ensure balance and deduct credit
  if v_sub.plan_type_snapshot = 'meal_credits' then
    if coalesce(v_sub.remaining_meal_credits, 0) <= 0 then
      return jsonb_build_object(
        'success', false,
        'error', 'No remaining meal credits in active plan. Please renew.',
        'code', 'NO_CREDITS_REMAINING'
      );
    end if;

    v_new_credits := v_sub.remaining_meal_credits - 1;

    update public.subscriptions
    set remaining_meal_credits = v_new_credits,
        status = case when v_new_credits = 0 then 'expired'::public.subscription_status else status end,
        updated_at = now()
    where id = v_sub.id;
  else
    v_new_credits := null;
  end if;

  -- 4. Record redemption atomically
  insert into public.redemptions (
    user_id,
    provider_id,
    subscription_id,
    date,
    slot,
    amount_extra_paise,
    extra_items
  ) values (
    p_user_id,
    p_provider_id,
    v_sub.id,
    p_date,
    p_slot,
    coalesce(p_amount_extra_paise, 0),
    coalesce(p_extra_items, '[]'::jsonb)
  ) returning id into v_redemption_id;

  return jsonb_build_object(
    'success', true,
    'redemption_id', v_redemption_id,
    'slot', p_slot,
    'plan_type', v_sub.plan_type_snapshot,
    'remaining_credits', v_new_credits,
    'amount_extra_paise', p_amount_extra_paise,
    'message', 'Meal successfully redeemed!'
  );
end;
$$;
