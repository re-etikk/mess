-- MESS provider + operations foundation (review before production).
-- Sensitive redemption, payment, settlement and admin actions MUST run in trusted server code.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id),
  business_type text not null check (business_type in ('mess','restaurant','home_tiffin','hostel_canteen')),
  name text not null check (length(trim(name)) between 2 and 120),
  slug text unique,
  description text,
  contact_name text,
  phone text,
  email text,
  address_line text not null,
  locality text,
  city text not null,
  state text,
  postal_code text,
  country_code text not null default 'IN',
  latitude double precision,
  longitude double precision,
  fssai_reference text,
  verification_status text not null default 'draft' check (verification_status in ('draft','submitted','in_review','needs_changes','approved','rejected','suspended')),
  publication_status text not null default 'unpublished' check (publication_status in ('unpublished','published','paused','closed')),
  timezone text not null default 'Asia/Kolkata',
  platform_terms_version text,
  platform_terms_accepted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((latitude is null and longitude is null) or (latitude between -90 and 90 and longitude between -180 and 180))
);

create table if not exists public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  member_role text not null check (member_role in ('owner','manager','cashier','menu_editor','finance_viewer')),
  status text not null default 'active' check (status in ('invited','active','suspended','removed')),
  invited_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (business_id, user_id)
);

create table if not exists public.provider_documents (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  document_type text not null,
  storage_path text not null,
  status text not null default 'submitted' check (status in ('submitted','in_review','approved','rejected','expired')),
  reviewer_user_id uuid references public.profiles(id),
  reviewed_at timestamptz,
  review_note text,
  expires_on date,
  created_at timestamptz not null default now()
);

create table if not exists public.business_hours (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  is_closed boolean not null default false,
  opens_at time,
  closes_at time,
  created_at timestamptz not null default now(),
  unique (business_id, weekday),
  check (is_closed or (opens_at is not null and closes_at is not null))
);

create table if not exists public.meal_slots (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  code text not null,
  starts_at time not null,
  ends_at time not null,
  last_redemption_at time,
  display_order integer not null default 0,
  is_active boolean not null default true,
  daily_redemption_limit integer not null default 1 check (daily_redemption_limit >= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, code),
  check (starts_at <> ends_at)
);

create table if not exists public.menu_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null,
  description text,
  category text not null default 'other',
  is_vegetarian boolean,
  dietary_tags text[] not null default '{}',
  allergen_tags text[] not null default '{}',
  image_path text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, name)
);

create table if not exists public.daily_menus (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  meal_slot_id uuid not null references public.meal_slots(id) on delete cascade,
  menu_date date not null,
  status text not null default 'draft' check (status in ('draft','published','sold_out','cancelled')),
  customer_note text,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, meal_slot_id, menu_date)
);

create table if not exists public.daily_menu_items (
  id uuid primary key default gen_random_uuid(),
  daily_menu_id uuid not null references public.daily_menus(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id),
  inclusion_type text not null check (inclusion_type in ('included','paid_addon','upgrade','substitution')),
  included_quantity numeric(10,2) not null default 0 check (included_quantity >= 0),
  unit_label text not null default 'serving',
  extra_unit_price numeric(12,2) not null default 0 check (extra_unit_price >= 0),
  max_quantity numeric(10,2),
  stock_quantity numeric(10,2),
  is_available boolean not null default true,
  applies_to_plan_ids uuid[] not null default '{}',
  display_order integer not null default 0,
  price_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (daily_menu_id, menu_item_id),
  check (max_quantity is null or max_quantity >= 0),
  check (stock_quantity is null or stock_quantity >= 0)
);

create table if not exists public.plan_templates (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  plan_type text not null check (plan_type in ('fixed_period','meal_tracker')),
  name text not null,
  duration_days integer not null check (duration_days > 0),
  price numeric(12,2) not null check (price >= 0),
  meal_credits integer check (meal_credits is null or meal_credits > 0),
  max_per_slot_per_day integer not null default 1 check (max_per_slot_per_day >= 1),
  validity_policy text not null default 'earlier_of_expiry_or_credit_exhaustion' check (validity_policy in ('expiry_only','earlier_of_expiry_or_credit_exhaustion')),
  pause_days_allowed integer not null default 0 check (pause_days_allowed >= 0),
  discount_type text check (discount_type in ('fixed','percent')),
  discount_value numeric(12,2) check (discount_value is null or discount_value >= 0),
  terms_text text not null default '',
  is_active boolean not null default true,
  is_published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((plan_type = 'fixed_period' and meal_credits is null) or (plan_type = 'meal_tracker' and meal_credits is not null)),
  check (discount_type <> 'percent' or discount_value is null or discount_value <= 100)
);

create table if not exists public.plan_meal_slots (
  plan_template_id uuid not null references public.plan_templates(id) on delete cascade,
  meal_slot_id uuid not null references public.meal_slots(id) on delete cascade,
  primary key (plan_template_id, meal_slot_id)
);

create table if not exists public.plan_included_items (
  id uuid primary key default gen_random_uuid(),
  plan_template_id uuid not null references public.plan_templates(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id) on delete cascade,
  included_quantity numeric(10,2) not null check (included_quantity >= 0),
  unit_label text not null default 'serving',
  unique (plan_template_id, menu_item_id)
);

create table if not exists public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references public.profiles(id),
  business_id uuid not null references public.businesses(id),
  plan_template_id uuid references public.plan_templates(id),
  plan_type text not null check (plan_type in ('fixed_period','meal_tracker')),
  status text not null default 'pending_payment' check (status in ('pending_payment','active','paused','expired','exhausted','cancelled','refunded')),
  starts_at timestamptz,
  expires_at timestamptz,
  meals_purchased integer,
  meals_redeemed integer not null default 0 check (meals_redeemed >= 0),
  price_paid numeric(12,2) not null default 0 check (price_paid >= 0),
  terms_snapshot jsonb not null default '{}'::jsonb,
  activated_payment_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (meals_purchased is null or meals_purchased >= meals_redeemed),
  check (plan_type <> 'meal_tracker' or meals_purchased is not null)
);

create table if not exists public.daily_meal_orders (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references public.profiles(id),
  business_id uuid not null references public.businesses(id),
  meal_slot_id uuid not null references public.meal_slots(id),
  menu_date date not null,
  status text not null default 'pending_payment' check (status in ('pending_payment','paid','redeemed','cancelled','refunded','expired')),
  base_price numeric(12,2) not null check (base_price >= 0),
  add_ons_total numeric(12,2) not null default 0 check (add_ons_total >= 0),
  final_total numeric(12,2) not null check (final_total >= 0),
  price_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.daily_qr_sessions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  service_date date not null,
  token_digest text not null,
  token_version integer not null default 1,
  issued_by uuid references public.profiles(id),
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  unique (business_id, service_date),
  check (expires_at > issued_at)
);

create table if not exists public.meal_redemptions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  customer_user_id uuid not null references public.profiles(id),
  meal_slot_id uuid not null references public.meal_slots(id),
  daily_menu_id uuid references public.daily_menus(id),
  subscription_id uuid references public.subscriptions(id),
  daily_meal_order_id uuid references public.daily_meal_orders(id),
  qr_session_id uuid not null references public.daily_qr_sessions(id),
  service_date date not null,
  status text not null default 'confirmed' check (status in ('confirmed','reversed','disputed')),
  credit_deducted boolean not null default false,
  idempotency_key text not null,
  redeemed_at timestamptz not null default now(),
  reversed_at timestamptz,
  reversal_reason text,
  constraint uq_customer_business_slot_date unique (customer_user_id, business_id, meal_slot_id, service_date),
  unique (idempotency_key),
  check ((subscription_id is not null) <> (daily_meal_order_id is not null))
);

create table if not exists public.redemption_addons (
  id uuid primary key default gen_random_uuid(),
  redemption_id uuid not null references public.meal_redemptions(id) on delete cascade,
  menu_item_id uuid not null references public.menu_items(id),
  quantity numeric(10,2) not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  line_total numeric(12,2) not null check (line_total >= 0),
  payment_id uuid,
  price_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  customer_user_id uuid not null references public.profiles(id),
  business_id uuid references public.businesses(id),
  subscription_id uuid references public.subscriptions(id),
  daily_meal_order_id uuid references public.daily_meal_orders(id),
  payment_purpose text not null check (payment_purpose in ('subscription','daily_meal','addon','refund_adjustment')),
  gateway text not null,
  gateway_order_id text,
  gateway_payment_id text,
  amount numeric(12,2) not null check (amount >= 0),
  currency char(3) not null default 'INR',
  status text not null default 'created' check (status in ('created','pending','authorized','captured','failed','refunded','partially_refunded','cancelled')),
  webhook_event_id text,
  idempotency_key text not null unique,
  verified_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (gateway, gateway_payment_id),
  unique (gateway, webhook_event_id)
);

alter table public.subscriptions add constraint fk_subscription_activation_payment foreign key (activated_payment_id) references public.payments(id) deferrable initially deferred;
alter table public.redemption_addons add constraint fk_redemption_addon_payment foreign key (payment_id) references public.payments(id);

create table if not exists public.promotion_codes (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  code text not null,
  title text not null,
  discount_type text not null check (discount_type in ('fixed','percent')),
  discount_value numeric(12,2) not null check (discount_value >= 0),
  min_order_amount numeric(12,2) not null default 0 check (min_order_amount >= 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  total_redemption_limit integer check (total_redemption_limit is null or total_redemption_limit > 0),
  per_customer_limit integer not null default 1 check (per_customer_limit > 0),
  eligible_plan_ids uuid[] not null default '{}',
  allow_stacking boolean not null default false,
  status text not null default 'draft' check (status in ('draft','scheduled','published','paused','expired')),
  created_at timestamptz not null default now(),
  check (ends_at > starts_at),
  check (discount_type <> 'percent' or discount_value <= 100),
  unique (business_id, code)
);

create table if not exists public.promotion_redemptions (
  id uuid primary key default gen_random_uuid(),
  promotion_code_id uuid not null references public.promotion_codes(id),
  customer_user_id uuid not null references public.profiles(id),
  payment_id uuid references public.payments(id),
  amount_saved numeric(12,2) not null check (amount_saved >= 0),
  redeemed_at timestamptz not null default now()
);

create table if not exists public.financial_ledger (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  payment_id uuid references public.payments(id),
  entry_type text not null check (entry_type in ('gross_sale','platform_fee','gateway_fee','refund','adjustment','provider_payable','payout')),
  amount numeric(12,2) not null,
  currency char(3) not null default 'INR',
  reference_type text,
  reference_id uuid,
  description text,
  immutable_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.provider_settlements (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  period_start date not null,
  period_end date not null,
  gross_amount numeric(12,2) not null default 0,
  platform_fee numeric(12,2) not null default 0,
  gateway_fee numeric(12,2) not null default 0,
  refund_amount numeric(12,2) not null default 0,
  net_payable numeric(12,2) not null default 0,
  status text not null default 'draft' check (status in ('draft','needs_review','approved','processing','paid','failed','on_hold')),
  gateway_transfer_id text,
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  paid_at timestamptz,
  statement_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  check (period_end >= period_start)
);

create table if not exists public.business_feedback (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id),
  customer_user_id uuid not null references public.profiles(id),
  redemption_id uuid not null references public.meal_redemptions(id),
  rating smallint not null check (rating between 1 and 5),
  comment text,
  moderation_status text not null default 'pending' check (moderation_status in ('pending','published','hidden','rejected')),
  created_at timestamptz not null default now(),
  unique (customer_user_id, redemption_id)
);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id),
  business_id uuid references public.businesses(id),
  category text not null check (category in ('provider_onboarding','redemption','payment','settlement','customer_dispute','technical','other')),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  status text not null default 'open' check (status in ('open','investigating','waiting_for_user','resolved','closed')),
  subject text not null,
  description text not null,
  assigned_to uuid references public.profiles(id),
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.platform_admin_roles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  platform_role text not null check (platform_role in ('super_admin','operations','finance','support','developer_readonly')),
  granted_by uuid references public.profiles(id),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  mfa_required boolean not null default true
);

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles(id),
  actor_role text,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  reason text,
  before_snapshot jsonb,
  after_snapshot jsonb,
  request_id text,
  ip_hash text,
  created_at timestamptz not null default now()
);

create table if not exists public.platform_feature_flags (
  flag_key text primary key,
  description text not null,
  enabled boolean not null default false,
  rollout_percentage integer not null default 0 check (rollout_percentage between 0 and 100),
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

create index if not exists idx_businesses_status_city on public.businesses(verification_status, publication_status, city);
create index if not exists idx_business_owner on public.businesses(owner_user_id);
create index if not exists idx_slots_business_order on public.meal_slots(business_id, display_order);
create index if not exists idx_daily_menus_date_business on public.daily_menus(business_id, menu_date, status);
create index if not exists idx_subscriptions_customer_status on public.subscriptions(customer_user_id, status, expires_at);
create index if not exists idx_subscriptions_business_status on public.subscriptions(business_id, status);
create index if not exists idx_daily_orders_customer_date on public.daily_meal_orders(customer_user_id, menu_date, status);
create index if not exists idx_redemptions_business_date_slot on public.meal_redemptions(business_id, service_date, meal_slot_id);
create index if not exists idx_redemptions_customer_date on public.meal_redemptions(customer_user_id, service_date desc);
create index if not exists idx_payments_status_created on public.payments(status, created_at desc);
create index if not exists idx_ledger_business_created on public.financial_ledger(business_id, created_at desc);
create index if not exists idx_support_status_priority on public.support_tickets(status, priority, created_at);
create index if not exists idx_admin_audit_created on public.admin_audit_logs(created_at desc);

-- RLS is enabled everywhere. The live implementation must add/test policies before client access.
-- Prefer trusted server endpoints for payment, redemption, admin, ledger and settlement writes.
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','businesses','business_members','provider_documents','business_hours','meal_slots','menu_items',
    'daily_menus','daily_menu_items','plan_templates','plan_meal_slots','plan_included_items','subscriptions',
    'daily_meal_orders','daily_qr_sessions','meal_redemptions','redemption_addons','payments','promotion_codes',
    'promotion_redemptions','financial_ledger','provider_settlements','business_feedback','support_tickets',
    'platform_admin_roles','admin_audit_logs','platform_feature_flags'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- Minimal baseline policies. Extend and test alongside server handlers before production.
create policy "profile self select" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "profile self insert" on public.profiles for insert to authenticated with check (id = (select auth.uid()));
create policy "profile self update" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "business public approved read" on public.businesses for select to anon, authenticated using (verification_status = 'approved' and publication_status = 'published');
create policy "business owner read" on public.businesses for select to authenticated using (owner_user_id = (select auth.uid()));
create policy "business owner create draft" on public.businesses for insert to authenticated with check (owner_user_id = (select auth.uid()) and verification_status = 'draft' and publication_status = 'unpublished');
-- No direct owner UPDATE policy on businesses: approval/publication fields must be changed by trusted server endpoints.

create policy "provider documents owner read" on public.provider_documents for select to authenticated using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "provider documents owner insert submitted" on public.provider_documents for insert to authenticated with check (status = 'submitted' and reviewer_user_id is null and reviewed_at is null and exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));

create policy "business hours owner all" on public.business_hours for all to authenticated using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid()))) with check (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "meal slots owner all" on public.meal_slots for all to authenticated using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid()))) with check (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "menu items owner all" on public.menu_items for all to authenticated using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid()))) with check (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "daily menus owner read" on public.daily_menus for select to authenticated using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "daily menus owner insert draft" on public.daily_menus for insert to authenticated with check (status = 'draft' and published_at is null and exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "daily menus owner update draft" on public.daily_menus for update to authenticated using (status = 'draft' and published_at is null and exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid()))) with check (status = 'draft' and published_at is null and exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "plans owner read" on public.plan_templates for select to authenticated using (exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "plans owner insert draft" on public.plan_templates for insert to authenticated with check (is_published = false and exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "plans owner update draft" on public.plan_templates for update to authenticated using (is_published = false and exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid()))) with check (is_published = false and exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));

create policy "daily menu items owner all on draft" on public.daily_menu_items for all to authenticated using (exists (select 1 from public.daily_menus dm join public.businesses b on b.id = dm.business_id where dm.id = daily_menu_id and dm.status = 'draft' and b.owner_user_id = (select auth.uid()))) with check (exists (select 1 from public.daily_menus dm join public.businesses b on b.id = dm.business_id where dm.id = daily_menu_id and dm.status = 'draft' and b.owner_user_id = (select auth.uid())));
create policy "plan slots owner all draft" on public.plan_meal_slots for all to authenticated using (exists (select 1 from public.plan_templates p join public.businesses b on b.id = p.business_id where p.id = plan_template_id and p.is_published = false and b.owner_user_id = (select auth.uid()))) with check (exists (select 1 from public.plan_templates p join public.businesses b on b.id = p.business_id where p.id = plan_template_id and p.is_published = false and b.owner_user_id = (select auth.uid())));
create policy "plan items owner all draft" on public.plan_included_items for all to authenticated using (exists (select 1 from public.plan_templates p join public.businesses b on b.id = p.business_id where p.id = plan_template_id and p.is_published = false and b.owner_user_id = (select auth.uid()))) with check (exists (select 1 from public.plan_templates p join public.businesses b on b.id = p.business_id where p.id = plan_template_id and p.is_published = false and b.owner_user_id = (select auth.uid())));

create policy "business public published menu read" on public.daily_menus for select to anon, authenticated using (status = 'published' and exists (select 1 from public.businesses b where b.id = business_id and b.verification_status = 'approved' and b.publication_status = 'published'));
create policy "business public published plans read" on public.plan_templates for select to anon, authenticated using (is_published = true and exists (select 1 from public.businesses b where b.id = business_id and b.verification_status = 'approved' and b.publication_status = 'published'));

create policy "subscriptions customer or provider read" on public.subscriptions for select to authenticated using (customer_user_id = (select auth.uid()) or exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "daily orders customer or provider read" on public.daily_meal_orders for select to authenticated using (customer_user_id = (select auth.uid()) or exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "redemptions customer or provider read" on public.meal_redemptions for select to authenticated using (
  customer_user_id = (select auth.uid()) or exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid()))
);
create policy "feedback customer read own" on public.business_feedback for select to authenticated using (customer_user_id = (select auth.uid()));
create policy "feedback provider read published" on public.business_feedback for select to authenticated using (moderation_status = 'published' and exists (select 1 from public.businesses b where b.id = business_id and b.owner_user_id = (select auth.uid())));
create policy "public feedback read for approved business" on public.business_feedback for select to anon, authenticated using (moderation_status = 'published' and exists (select 1 from public.businesses b where b.id = business_id and b.verification_status = 'approved' and b.publication_status = 'published'));
create policy "support creator read own" on public.support_tickets for select to authenticated using (created_by = (select auth.uid()));
create policy "support creator insert own" on public.support_tickets for insert to authenticated with check (created_by = (select auth.uid()));

-- Do not add anon/authenticated direct policies for payments, ledger, settlements, QR issuance,
-- admin roles/audit logs, or redemption writes. Use trusted, authorization-checked server endpoints.


create policy "public menu item read for published menu" on public.daily_menu_items for select to anon, authenticated using (is_available = true and exists (
  select 1 from public.daily_menus dm join public.businesses b on b.id = dm.business_id
  where dm.id = daily_menu_id and dm.status = 'published' and b.verification_status = 'approved' and b.publication_status = 'published'
));
create policy "public meal slots read for approved business" on public.meal_slots for select to anon, authenticated using (
  is_active = true and exists (select 1 from public.businesses b where b.id = business_id and b.verification_status = 'approved' and b.publication_status = 'published')
);
create policy "public business hours read for approved business" on public.business_hours for select to anon, authenticated using (
  exists (select 1 from public.businesses b where b.id = business_id and b.verification_status = 'approved' and b.publication_status = 'published')
);
create policy "public plan meal slots read" on public.plan_meal_slots for select to anon, authenticated using (
  exists (select 1 from public.plan_templates p join public.businesses b on b.id = p.business_id where p.id = plan_template_id and p.is_published = true and b.verification_status = 'approved' and b.publication_status = 'published')
);
create policy "public included plan items read" on public.plan_included_items for select to anon, authenticated using (
  exists (select 1 from public.plan_templates p join public.businesses b on b.id = p.business_id where p.id = plan_template_id and p.is_published = true and b.verification_status = 'approved' and b.publication_status = 'published')
);
create policy "public menu item catalogue read for approved business" on public.menu_items for select to anon, authenticated using (
  is_active = true and exists (select 1 from public.businesses b where b.id = business_id and b.verification_status = 'approved' and b.publication_status = 'published')
);

-- Explicit grants are required even when policies exist. Review these against the project's
-- Data API exposure settings. Sensitive finance/admin/QR tables are server-only by design.
grant select, insert, update on public.profiles to authenticated;
grant select on public.businesses, public.business_hours to anon, authenticated;
grant insert on public.businesses to authenticated;
grant select, insert on public.provider_documents to authenticated;
grant select, insert, update, delete on public.business_hours, public.meal_slots, public.menu_items, public.daily_menus, public.daily_menu_items to authenticated;
grant select, insert, update, delete on public.plan_templates, public.plan_meal_slots, public.plan_included_items to authenticated;
grant select on public.subscriptions, public.daily_meal_orders, public.meal_redemptions, public.business_feedback to authenticated;
grant select on public.business_feedback to anon;
grant select on public.daily_menus, public.daily_menu_items, public.meal_slots, public.menu_items, public.plan_templates, public.plan_meal_slots, public.plan_included_items, public.business_hours to anon, authenticated;
revoke all on public.daily_qr_sessions, public.redemption_addons, public.payments, public.promotion_redemptions, public.financial_ledger, public.provider_settlements, public.platform_admin_roles, public.admin_audit_logs, public.platform_feature_flags from anon, authenticated;

