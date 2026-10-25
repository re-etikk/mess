-- MESS initial schema proposal, 2026-10-24.
-- Review against the actual Supabase project and current PostgreSQL/Supabase docs before applying.
-- Never apply directly to production without a staging migration/test/review.

create extension if not exists pgcrypto;

create type public.app_role as enum ('customer', 'provider', 'delivery_partner', 'admin', 'support');
create type public.provider_status as enum ('draft', 'pending_review', 'active', 'rejected', 'suspended');
create type public.membership_role as enum ('owner', 'manager', 'counter_staff');
create type public.plan_type as enum ('fixed_period', 'meal_credits');
create type public.subscription_status as enum ('pending_payment', 'active', 'paused', 'expired', 'cancelled', 'refund_pending', 'refunded', 'payment_failed');
create type public.booking_type as enum ('subscription_meal', 'single_meal');
create type public.fulfillment_mode as enum ('pickup', 'delivery');
create type public.booking_status as enum ('draft', 'pending_payment', 'confirmed', 'ready', 'assigned', 'accepted', 'picked_up', 'redeemed', 'delivered', 'cancelled', 'missed', 'failed_delivery', 'refund_pending', 'refunded');
create type public.qr_purpose as enum ('pickup', 'delivery_handoff');
create type public.payment_purpose as enum ('subscription_purchase', 'single_meal_purchase', 'delivery_fee', 'refund');
create type public.payment_status as enum ('created', 'pending', 'succeeded', 'failed', 'cancelled');
create type public.refund_status as enum ('requested', 'pending', 'succeeded', 'failed', 'rejected');
create type public.delivery_status as enum ('offered', 'accepted', 'picked_up', 'delivered', 'rejected', 'cancelled', 'failed', 'reassigned');
create type public.commission_category as enum ('provider_food', 'delivery_charge');
create type public.agreement_entity_type as enum ('provider', 'delivery_partner');
create type public.ledger_account_type as enum ('platform', 'provider', 'delivery_partner', 'payment_gateway');
create type public.ledger_entry_type as enum ('food_sale', 'delivery_charge', 'platform_commission', 'gateway_fee', 'refund', 'payout', 'delivery_payout', 'adjustment', 'tax');
create type public.settlement_status as enum ('draft', 'pending', 'processing', 'paid', 'failed', 'cancelled');
create type public.support_status as enum ('open', 'triaged', 'in_progress', 'waiting_for_user', 'resolved', 'closed');
create type public.support_priority as enum ('low', 'normal', 'high', 'urgent');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  phone_e164 text,
  avatar_path text,
  locale text not null default 'en-IN',
  timezone text not null default 'Asia/Kolkata',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_phone_nonempty check (phone_e164 is null or length(trim(phone_e164)) >= 7)
);

create table public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.app_role not null,
  granted_by uuid references public.profiles(id) on delete set null,
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (user_id, role)
);
create index user_roles_user_active_idx on public.user_roles(user_id, role) where revoked_at is null;

create table public.customer_addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  label text not null default 'Home',
  recipient_name text not null,
  recipient_phone_e164 text not null,
  address_line1 text not null,
  address_line2 text,
  locality text not null,
  city text not null,
  state text not null,
  pincode text not null,
  latitude numeric(9,6),
  longitude numeric(9,6),
  delivery_instructions text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint address_latitude_range check (latitude is null or latitude between -90 and 90),
  constraint address_longitude_range check (longitude is null or longitude between -180 and 180)
);
create index customer_addresses_customer_idx on public.customer_addresses(customer_id);
create unique index customer_addresses_one_default_idx on public.customer_addresses(customer_id) where is_default;

create table public.providers (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles(id) on delete restrict,
  display_name text not null,
  slug text not null unique,
  description text,
  logo_path text,
  cover_path text,
  public_phone text,
  public_email text,
  address_line1 text not null,
  address_line2 text,
  locality text not null,
  city text not null,
  state text not null,
  pincode text not null,
  latitude numeric(9,6),
  longitude numeric(9,6),
  timezone text not null default 'Asia/Kolkata',
  status public.provider_status not null default 'draft',
  supports_pickup boolean not null default true,
  supports_delivery boolean not null default false,
  approved_at timestamptz,
  approved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint providers_display_name_nonempty check (length(trim(display_name)) >= 2),
  constraint providers_latitude_range check (latitude is null or latitude between -90 and 90),
  constraint providers_longitude_range check (longitude is null or longitude between -180 and 180)
);
create index providers_status_city_idx on public.providers(status, city);
create index providers_owner_idx on public.providers(owner_user_id);

create table public.provider_compliance_documents (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  document_type text not null,
  document_reference text,
  storage_path text not null,
  expires_on date,
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected','expired')),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  review_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index provider_documents_provider_idx on public.provider_compliance_documents(provider_id, verification_status);

create table public.provider_memberships (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.membership_role not null,
  invited_by uuid references public.profiles(id) on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider_id, user_id)
);
create index provider_memberships_user_idx on public.provider_memberships(user_id, active);

create table public.provider_service_areas (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  area_name text not null,
  city text not null,
  pincode text,
  service_mode public.fulfillment_mode not null,
  radius_km numeric(6,2),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint service_area_radius_positive check (radius_km is null or radius_km > 0)
);
create index provider_service_areas_lookup_idx on public.provider_service_areas(city, pincode, service_mode, active);
create index provider_service_areas_provider_idx on public.provider_service_areas(provider_id);

create table public.provider_operating_hours (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  weekday smallint not null check (weekday between 0 and 6),
  opens_at time,
  closes_at time,
  closed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider_id, weekday),
  constraint operating_hours_valid check (closed or (opens_at is not null and closes_at is not null and opens_at <> closes_at))
);

create table public.meal_slots (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  name text not null,
  starts_at_local time not null,
  ends_at_local time not null,
  booking_cutoff_minutes integer not null default 0 check (booking_cutoff_minutes >= 0),
  daily_capacity integer check (daily_capacity is null or daily_capacity > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meal_slot_times_valid check (starts_at_local <> ends_at_local)
);
create index meal_slots_provider_active_idx on public.meal_slots(provider_id, active);

create table public.menu_items (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  name text not null,
  description text,
  image_path text,
  category text,
  dietary_type text not null default 'unspecified' check (dietary_type in ('vegetarian','vegan','non_vegetarian','jain','unspecified')),
  price_paise bigint not null check (price_paise >= 0),
  available_from date,
  available_until date,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint menu_item_date_range check (available_until is null or available_from is null or available_until >= available_from)
);
create index menu_items_provider_active_idx on public.menu_items(provider_id, active);

create table public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete cascade,
  name text not null,
  description text,
  plan_type public.plan_type not null,
  duration_months smallint,
  meal_credits integer,
  price_paise bigint not null check (price_paise >= 0),
  currency char(3) not null default 'INR' check (currency = 'INR'),
  promo_price_paise bigint check (promo_price_paise is null or promo_price_paise >= 0),
  daily_meal_limit smallint not null default 1 check (daily_meal_limit > 0),
  allow_pickup boolean not null default true,
  allow_delivery boolean not null default false,
  booking_cutoff_minutes integer not null default 0 check (booking_cutoff_minutes >= 0),
  cancellation_policy text not null,
  missed_meal_policy text not null,
  terms_version text not null default '1',
  published boolean not null default false,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint plan_duration_or_credits check (
    (plan_type = 'fixed_period' and duration_months is not null and duration_months in (1,3,6,12) and meal_credits is null)
    or (plan_type = 'meal_credits' and duration_months is null and meal_credits is not null and meal_credits > 0)
  ),
  constraint plan_promo_not_above_price check (promo_price_paise is null or promo_price_paise <= price_paise)
);
create index subscription_plans_provider_public_idx on public.subscription_plans(provider_id, published, active);

create table public.plan_meal_slots (
  plan_id uuid not null references public.subscription_plans(id) on delete cascade,
  meal_slot_id uuid not null references public.meal_slots(id) on delete cascade,
  primary key (plan_id, meal_slot_id)
);

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete restrict,
  provider_id uuid not null references public.providers(id) on delete restrict,
  plan_id uuid not null references public.subscription_plans(id) on delete restrict,
  status public.subscription_status not null default 'pending_payment',
  plan_type_snapshot public.plan_type not null,
  plan_name_snapshot text not null,
  terms_version_snapshot text not null,
  price_paid_paise bigint not null check (price_paid_paise >= 0),
  initial_meal_credits integer,
  remaining_meal_credits integer,
  starts_at timestamptz,
  expires_at timestamptz,
  pause_started_at timestamptz,
  activated_at timestamptz,
  cancelled_at timestamptz,
  payment_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint subscription_credit_invariants check (
    (plan_type_snapshot = 'fixed_period' and initial_meal_credits is null and remaining_meal_credits is null)
    or (plan_type_snapshot = 'meal_credits' and initial_meal_credits is not null and initial_meal_credits > 0 and remaining_meal_credits is not null and remaining_meal_credits between 0 and initial_meal_credits)
  ),
  constraint subscription_validity_range check (expires_at is null or starts_at is null or expires_at > starts_at)
);
create index subscriptions_customer_status_idx on public.subscriptions(customer_id, status, expires_at desc);
create index subscriptions_provider_status_idx on public.subscriptions(provider_id, status);

create table public.meal_bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete restrict,
  provider_id uuid not null references public.providers(id) on delete restrict,
  booking_type public.booking_type not null,
  subscription_id uuid references public.subscriptions(id) on delete restrict,
  menu_item_id uuid references public.menu_items(id) on delete restrict,
  meal_slot_id uuid not null references public.meal_slots(id) on delete restrict,
  fulfillment_mode public.fulfillment_mode not null,
  status public.booking_status not null default 'draft',
  service_at timestamptz not null,
  service_date date not null,
  food_price_paise bigint not null default 0 check (food_price_paise >= 0),
  discount_paise bigint not null default 0 check (discount_paise >= 0),
  subscription_covered_paise bigint not null default 0 check (subscription_covered_paise >= 0),
  delivery_fee_paise bigint not null default 0 check (delivery_fee_paise >= 0),
  tax_paise bigint not null default 0 check (tax_paise >= 0),
  total_due_paise bigint not null default 0 check (total_due_paise >= 0),
  currency char(3) not null default 'INR' check (currency = 'INR'),
  address_snapshot jsonb,
  customer_note text,
  idempotency_key text,
  confirmed_at timestamptz,
  ready_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint booking_source_valid check (
    (booking_type = 'subscription_meal' and subscription_id is not null)
    or (booking_type = 'single_meal' and subscription_id is null and menu_item_id is not null)
  ),
  constraint pickup_no_delivery_fee check (fulfillment_mode <> 'pickup' or delivery_fee_paise = 0),
  constraint delivery_requires_address check (fulfillment_mode <> 'delivery' or address_snapshot is not null),
  constraint booking_discount_not_above_food check (discount_paise <= food_price_paise),
  constraint booking_subscription_coverage_valid check (subscription_covered_paise <= food_price_paise - discount_paise),
  constraint booking_total_due_matches_components check (total_due_paise = food_price_paise - discount_paise - subscription_covered_paise + delivery_fee_paise + tax_paise),
  constraint booking_subscription_coverage_type check (booking_type <> 'single_meal' or subscription_covered_paise = 0),
  unique (customer_id, idempotency_key)
);
create index meal_bookings_customer_service_idx on public.meal_bookings(customer_id, service_at desc);
create index meal_bookings_provider_service_idx on public.meal_bookings(provider_id, service_date, meal_slot_id, status);
create index meal_bookings_subscription_idx on public.meal_bookings(subscription_id, service_at desc) where subscription_id is not null;

create table public.qr_redemption_tokens (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.meal_bookings(id) on delete cascade,
  provider_id uuid not null references public.providers(id) on delete restrict,
  customer_id uuid not null references public.profiles(id) on delete restrict,
  purpose public.qr_purpose not null,
  token_hash text not null unique,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  used_at timestamptz,
  invalidated_at timestamptz,
  attempts integer not null default 0 check (attempts >= 0),
  created_at timestamptz not null default now(),
  constraint qr_expiry_after_issue check (expires_at > issued_at),
  unique (booking_id, purpose, issued_at)
);
create index qr_tokens_booking_purpose_idx on public.qr_redemption_tokens(booking_id, purpose, expires_at desc);

create table public.meal_redemptions (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.meal_bookings(id) on delete restrict,
  subscription_id uuid references public.subscriptions(id) on delete restrict,
  customer_id uuid not null references public.profiles(id) on delete restrict,
  provider_id uuid not null references public.providers(id) on delete restrict,
  redeemed_by uuid references public.profiles(id) on delete set null,
  fulfillment_mode public.fulfillment_mode not null,
  confirmation_method text not null check (confirmation_method in ('pickup_qr','delivery_otp','delivery_qr','admin_override')),
  redeemed_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index meal_redemptions_customer_idx on public.meal_redemptions(customer_id, redeemed_at desc);
create index meal_redemptions_provider_idx on public.meal_redemptions(provider_id, redeemed_at desc);

create table public.delivery_partner_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete restrict,
  status text not null default 'pending_review' check (status in ('pending_review','approved','rejected','suspended')),
  is_online boolean not null default false,
  vehicle_type text,
  verification_reference text,
  payout_onboarding_status text not null default 'not_started' check (payout_onboarding_status in ('not_started','pending','verified','rejected')),
  approved_at timestamptz,
  approved_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index delivery_partner_status_online_idx on public.delivery_partner_profiles(status, is_online);

create table public.delivery_assignments (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.meal_bookings(id) on delete restrict,
  partner_id uuid references public.delivery_partner_profiles(id) on delete restrict,
  status public.delivery_status not null default 'offered',
  delivery_fee_paise bigint not null check (delivery_fee_paise >= 0),
  partner_payout_paise bigint not null check (partner_payout_paise >= 0),
  platform_fee_paise bigint not null default 0 check (platform_fee_paise >= 0),
  offered_at timestamptz not null default now(),
  accepted_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz,
  failed_at timestamptz,
  failure_reason text,
  assignment_version integer not null default 1 check (assignment_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_fee_split_not_overflow check (partner_payout_paise + platform_fee_paise <= delivery_fee_paise),
  unique (booking_id, assignment_version)
);
create index delivery_assignments_partner_status_idx on public.delivery_assignments(partner_id, status, offered_at desc);
create index delivery_assignments_booking_idx on public.delivery_assignments(booking_id);

create table public.delivery_location_events (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.delivery_assignments(id) on delete cascade,
  partner_id uuid not null references public.delivery_partner_profiles(id) on delete restrict,
  latitude numeric(9,6) not null check (latitude between -90 and 90),
  longitude numeric(9,6) not null check (longitude between -180 and 180),
  accuracy_m numeric(8,2),
  captured_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index delivery_location_events_assignment_time_idx on public.delivery_location_events(assignment_id, captured_at desc);

create table public.payment_transactions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete restrict,
  subscription_id uuid references public.subscriptions(id) on delete restrict,
  booking_id uuid references public.meal_bookings(id) on delete restrict,
  purpose public.payment_purpose not null,
  gateway_name text not null,
  gateway_order_id text,
  gateway_payment_id text,
  amount_paise bigint not null check (amount_paise >= 0),
  currency char(3) not null default 'INR' check (currency = 'INR'),
  status public.payment_status not null default 'created',
  idempotency_key text not null,
  gateway_fee_paise bigint check (gateway_fee_paise is null or gateway_fee_paise >= 0),
  verified_at timestamptz,
  failure_code text,
  sanitized_gateway_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint payment_reference_valid check (
    (purpose = 'subscription_purchase' and subscription_id is not null and booking_id is null)
    or (purpose in ('single_meal_purchase','delivery_fee') and booking_id is not null and subscription_id is null)
    or (purpose = 'refund' and (booking_id is not null or subscription_id is not null))
  ),
  unique (gateway_name, gateway_order_id),
  unique (gateway_name, gateway_payment_id),
  unique (customer_id, idempotency_key)
);
create index payment_transactions_customer_time_idx on public.payment_transactions(customer_id, created_at desc);
create index payment_transactions_status_time_idx on public.payment_transactions(status, created_at);

create table public.payment_webhook_events (
  id uuid primary key default gen_random_uuid(),
  gateway_name text not null,
  gateway_event_id text not null,
  event_type text not null,
  signature_verified boolean not null default false,
  processing_status text not null default 'received' check (processing_status in ('received','processing','processed','ignored','failed')),
  processed_at timestamptz,
  failure_code text,
  sanitized_payload jsonb not null default '{}'::jsonb,
  received_at timestamptz not null default now(),
  unique (gateway_name, gateway_event_id)
);
create index payment_webhook_processing_idx on public.payment_webhook_events(processing_status, received_at);

create table public.refunds (
  id uuid primary key default gen_random_uuid(),
  payment_transaction_id uuid not null references public.payment_transactions(id) on delete restrict,
  amount_paise bigint not null check (amount_paise > 0),
  reason_code text not null,
  reason_note text,
  status public.refund_status not null default 'requested',
  gateway_refund_id text,
  requested_by uuid references public.profiles(id) on delete set null,
  processed_by uuid references public.profiles(id) on delete set null,
  idempotency_key text not null unique,
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index refunds_payment_idx on public.refunds(payment_transaction_id, created_at desc);

create table public.platform_commission_rules (
  id uuid primary key default gen_random_uuid(),
  category public.commission_category not null,
  provider_id uuid references public.providers(id) on delete cascade,
  rate_bps integer not null check (rate_bps between 0 and 10000),
  effective_from timestamptz not null,
  effective_until timestamptz,
  active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint commission_rule_range check (effective_until is null or effective_until > effective_from)
);
create index commission_rules_lookup_idx on public.platform_commission_rules(category, provider_id, effective_from desc) where active;

create table public.commercial_agreements (
  id uuid primary key default gen_random_uuid(),
  entity_type public.agreement_entity_type not null,
  provider_id uuid references public.providers(id) on delete cascade,
  delivery_partner_id uuid references public.delivery_partner_profiles(id) on delete cascade,
  agreement_version text not null,
  provider_food_rate_bps integer check (provider_food_rate_bps between 0 and 10000),
  delivery_fee_rate_bps integer check (delivery_fee_rate_bps between 0 and 10000),
  free_commission_until timestamptz,
  effective_from timestamptz not null,
  effective_until timestamptz,
  accepted_by uuid not null references public.profiles(id) on delete restrict,
  accepted_at timestamptz not null,
  terms_snapshot jsonb not null,
  created_at timestamptz not null default now(),
  constraint agreement_single_entity check (
    (entity_type = 'provider' and provider_id is not null and delivery_partner_id is null)
    or (entity_type = 'delivery_partner' and delivery_partner_id is not null and provider_id is null)
  ),
  constraint agreement_range check (effective_until is null or effective_until > effective_from)
);
create index agreements_provider_idx on public.commercial_agreements(provider_id, effective_from desc) where provider_id is not null;
create index agreements_partner_idx on public.commercial_agreements(delivery_partner_id, effective_from desc) where delivery_partner_id is not null;

create table public.financial_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  account_type public.ledger_account_type not null,
  account_id uuid,
  entry_type public.ledger_entry_type not null,
  amount_paise bigint not null,
  currency char(3) not null default 'INR' check (currency = 'INR'),
  reference_type text not null,
  reference_id uuid not null,
  commission_base_paise bigint check (commission_base_paise is null or commission_base_paise >= 0),
  applied_rate_bps integer check (applied_rate_bps is null or applied_rate_bps between 0 and 10000),
  idempotency_key text not null unique,
  reverses_entry_id uuid references public.financial_ledger_entries(id) on delete restrict,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index financial_ledger_account_time_idx on public.financial_ledger_entries(account_type, account_id, created_at desc);
create index financial_ledger_reference_idx on public.financial_ledger_entries(reference_type, reference_id);

create table public.provider_settlements (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.providers(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  gross_food_paise bigint not null default 0,
  commission_paise bigint not null default 0,
  refund_paise bigint not null default 0,
  adjustment_paise bigint not null default 0,
  net_payable_paise bigint not null default 0,
  status public.settlement_status not null default 'draft',
  gateway_payout_reference text,
  generated_at timestamptz not null default now(),
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint provider_settlement_period_valid check (period_end >= period_start),
  unique (provider_id, period_start, period_end)
);
create index provider_settlements_provider_status_idx on public.provider_settlements(provider_id, status, period_end desc);

create table public.provider_settlement_items (
  id uuid primary key default gen_random_uuid(),
  settlement_id uuid not null references public.provider_settlements(id) on delete cascade,
  ledger_entry_id uuid not null references public.financial_ledger_entries(id) on delete restrict,
  amount_paise bigint not null,
  created_at timestamptz not null default now(),
  unique (settlement_id, ledger_entry_id)
);

create table public.delivery_payouts (
  id uuid primary key default gen_random_uuid(),
  delivery_partner_id uuid not null references public.delivery_partner_profiles(id) on delete restrict,
  period_start date not null,
  period_end date not null,
  gross_payout_paise bigint not null default 0,
  adjustment_paise bigint not null default 0,
  net_payout_paise bigint not null default 0,
  status public.settlement_status not null default 'draft',
  payout_reference text,
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_payout_period_valid check (period_end >= period_start),
  unique (delivery_partner_id, period_start, period_end)
);
create index delivery_payouts_partner_status_idx on public.delivery_payouts(delivery_partner_id, status, period_end desc);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  category text not null,
  title text not null,
  body text not null,
  deep_link text,
  metadata jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index notifications_user_unread_idx on public.notifications(user_id, created_at desc) where read_at is null;

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles(id) on delete restrict,
  about_user_id uuid references public.profiles(id) on delete set null,
  provider_id uuid references public.providers(id) on delete set null,
  booking_id uuid references public.meal_bookings(id) on delete set null,
  payment_transaction_id uuid references public.payment_transactions(id) on delete set null,
  category text not null,
  subject text not null,
  description text not null,
  status public.support_status not null default 'open',
  priority public.support_priority not null default 'normal',
  assigned_to uuid references public.profiles(id) on delete set null,
  resolution_note text,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index support_tickets_creator_idx on public.support_tickets(created_by, created_at desc);
create index support_tickets_status_idx on public.support_tickets(status, priority, created_at);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references public.profiles(id) on delete set null,
  action text not null,
  subject_type text not null,
  subject_id uuid,
  reason text,
  request_id text,
  sanitized_details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_subject_idx on public.audit_logs(subject_type, subject_id, created_at desc);
create index audit_logs_actor_idx on public.audit_logs(actor_user_id, created_at desc);

create table public.idempotency_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  scope text not null,
  idempotency_key text not null,
  request_hash text not null,
  response_status integer,
  response_body jsonb,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (scope, idempotency_key)
);
create index idempotency_records_created_idx on public.idempotency_records(created_at);

-- updated_at triggers
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();
create trigger customer_addresses_set_updated_at before update on public.customer_addresses for each row execute function public.set_updated_at();
create trigger providers_set_updated_at before update on public.providers for each row execute function public.set_updated_at();
create trigger provider_documents_set_updated_at before update on public.provider_compliance_documents for each row execute function public.set_updated_at();
create trigger provider_memberships_set_updated_at before update on public.provider_memberships for each row execute function public.set_updated_at();
create trigger provider_service_areas_set_updated_at before update on public.provider_service_areas for each row execute function public.set_updated_at();
create trigger provider_operating_hours_set_updated_at before update on public.provider_operating_hours for each row execute function public.set_updated_at();
create trigger meal_slots_set_updated_at before update on public.meal_slots for each row execute function public.set_updated_at();
create trigger menu_items_set_updated_at before update on public.menu_items for each row execute function public.set_updated_at();
create trigger subscription_plans_set_updated_at before update on public.subscription_plans for each row execute function public.set_updated_at();
create trigger subscriptions_set_updated_at before update on public.subscriptions for each row execute function public.set_updated_at();
create trigger meal_bookings_set_updated_at before update on public.meal_bookings for each row execute function public.set_updated_at();
create trigger delivery_partner_profiles_set_updated_at before update on public.delivery_partner_profiles for each row execute function public.set_updated_at();
create trigger delivery_assignments_set_updated_at before update on public.delivery_assignments for each row execute function public.set_updated_at();
create trigger payment_transactions_set_updated_at before update on public.payment_transactions for each row execute function public.set_updated_at();
create trigger refunds_set_updated_at before update on public.refunds for each row execute function public.set_updated_at();
create trigger provider_settlements_set_updated_at before update on public.provider_settlements for each row execute function public.set_updated_at();
create trigger delivery_payouts_set_updated_at before update on public.delivery_payouts for each row execute function public.set_updated_at();
create trigger support_tickets_set_updated_at before update on public.support_tickets for each row execute function public.set_updated_at();

-- Enable RLS on every table in the exposed public schema.
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.customer_addresses enable row level security;
alter table public.providers enable row level security;
alter table public.provider_compliance_documents enable row level security;
alter table public.provider_memberships enable row level security;
alter table public.provider_service_areas enable row level security;
alter table public.provider_operating_hours enable row level security;
alter table public.meal_slots enable row level security;
alter table public.menu_items enable row level security;
alter table public.subscription_plans enable row level security;
alter table public.plan_meal_slots enable row level security;
alter table public.subscriptions enable row level security;
alter table public.meal_bookings enable row level security;
alter table public.qr_redemption_tokens enable row level security;
alter table public.meal_redemptions enable row level security;
alter table public.delivery_partner_profiles enable row level security;
alter table public.delivery_assignments enable row level security;
alter table public.delivery_location_events enable row level security;
alter table public.payment_transactions enable row level security;
alter table public.payment_webhook_events enable row level security;
alter table public.refunds enable row level security;
alter table public.platform_commission_rules enable row level security;
alter table public.commercial_agreements enable row level security;
alter table public.financial_ledger_entries enable row level security;
alter table public.provider_settlements enable row level security;
alter table public.provider_settlement_items enable row level security;
alter table public.delivery_payouts enable row level security;
alter table public.notifications enable row level security;
alter table public.support_tickets enable row level security;
alter table public.audit_logs enable row level security;
alter table public.idempotency_records enable row level security;

-- Remove default table privileges, then grant only the operations intended for direct client access.
-- Server-side Edge Functions with protected secrets perform privileged writes and use the service role only server-side.
revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;

-- Profiles and personal addresses: own records only.
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.customer_addresses to authenticated;
create policy profiles_select_own on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert_own on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update_own on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy addresses_select_own on public.customer_addresses for select to authenticated using ((select auth.uid()) = customer_id);
create policy addresses_insert_own on public.customer_addresses for insert to authenticated with check ((select auth.uid()) = customer_id);
create policy addresses_update_own on public.customer_addresses for update to authenticated using ((select auth.uid()) = customer_id) with check ((select auth.uid()) = customer_id);
create policy addresses_delete_own on public.customer_addresses for delete to authenticated using ((select auth.uid()) = customer_id);

-- Role assignments are readable by the subject only; no client writes.
grant select on public.user_roles to authenticated;
create policy user_roles_select_own on public.user_roles for select to authenticated using ((select auth.uid()) = user_id);

-- Public provider rows use column-level grants so private owner/approval fields are not exposed.
grant select (id, display_name, slug, description, logo_path, cover_path, public_phone, public_email, address_line1, address_line2, locality, city, state, pincode, latitude, longitude, timezone, status, supports_pickup, supports_delivery, created_at, updated_at) on public.providers to anon, authenticated;
grant update (display_name, description, logo_path, cover_path, public_phone, public_email, address_line1, address_line2, locality, city, state, pincode, latitude, longitude, timezone, supports_pickup, supports_delivery) on public.providers to authenticated;
create policy providers_public_active_select on public.providers for select to anon, authenticated using (status = 'active');
create policy providers_member_select on public.providers for select to authenticated using (
  exists (select 1 from public.provider_memberships pm where pm.provider_id = id and pm.user_id = (select auth.uid()) and pm.active)
);
create policy providers_manager_update on public.providers for update to authenticated using (
  exists (select 1 from public.provider_memberships pm where pm.provider_id = id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager'))
) with check (
  exists (select 1 from public.provider_memberships pm where pm.provider_id = id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager'))
);

-- Provider memberships are self-readable. Creation/role changes are backend/admin only.
grant select on public.provider_memberships to authenticated;
create policy provider_memberships_select_own on public.provider_memberships for select to authenticated using ((select auth.uid()) = user_id);

-- Public catalogue read; all mutations require an active provider owner/manager.
grant select on public.provider_service_areas, public.provider_operating_hours, public.meal_slots, public.menu_items, public.subscription_plans, public.plan_meal_slots to anon, authenticated;
grant insert, update, delete on public.provider_service_areas, public.provider_operating_hours, public.meal_slots, public.menu_items, public.subscription_plans, public.plan_meal_slots to authenticated;
create policy service_areas_public_select on public.provider_service_areas for select to anon, authenticated using (active and exists (select 1 from public.providers p where p.id = provider_id and p.status = 'active'));
create policy service_areas_member_select on public.provider_service_areas for select to authenticated using (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active));
create policy service_areas_manager_all on public.provider_service_areas for all to authenticated using (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager'))) with check (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager')));
create policy operating_hours_public_select on public.provider_operating_hours for select to anon, authenticated using (exists (select 1 from public.providers p where p.id = provider_id and p.status = 'active'));
create policy operating_hours_member_select on public.provider_operating_hours for select to authenticated using (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active));
create policy operating_hours_manager_all on public.provider_operating_hours for all to authenticated using (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager'))) with check (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager')));
create policy meal_slots_public_select on public.meal_slots for select to anon, authenticated using (active and exists (select 1 from public.providers p where p.id = provider_id and p.status = 'active'));
create policy meal_slots_member_select on public.meal_slots for select to authenticated using (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active));
create policy meal_slots_manager_all on public.meal_slots for all to authenticated using (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager'))) with check (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager')));
create policy menu_items_public_select on public.menu_items for select to anon, authenticated using (active and exists (select 1 from public.providers p where p.id = provider_id and p.status = 'active'));
create policy menu_items_member_select on public.menu_items for select to authenticated using (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active));
create policy menu_items_manager_all on public.menu_items for all to authenticated using (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager'))) with check (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager')));
create policy plans_public_select on public.subscription_plans for select to anon, authenticated using (published and active and exists (select 1 from public.providers p where p.id = provider_id and p.status = 'active'));
create policy plans_member_select on public.subscription_plans for select to authenticated using (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active));
create policy plans_manager_all on public.subscription_plans for all to authenticated using (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager'))) with check (exists (select 1 from public.provider_memberships pm where pm.provider_id = provider_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager')));
create policy plan_slots_public_select on public.plan_meal_slots for select to anon, authenticated using (exists (select 1 from public.subscription_plans sp join public.providers p on p.id = sp.provider_id where sp.id = plan_id and sp.published and sp.active and p.status = 'active'));
create policy plan_slots_provider_member_select on public.plan_meal_slots for select to authenticated using (exists (select 1 from public.subscription_plans sp join public.provider_memberships pm on pm.provider_id = sp.provider_id where sp.id = plan_id and pm.user_id = (select auth.uid()) and pm.active));
create policy plan_slots_manager_all on public.plan_meal_slots for all to authenticated using (exists (select 1 from public.subscription_plans sp join public.provider_memberships pm on pm.provider_id = sp.provider_id where sp.id = plan_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager'))) with check (exists (select 1 from public.subscription_plans sp join public.provider_memberships pm on pm.provider_id = sp.provider_id where sp.id = plan_id and pm.user_id = (select auth.uid()) and pm.active and pm.role in ('owner','manager')));

-- Sensitive operational/financial records are read via narrowly scoped server endpoints initially.
-- No direct client writes are granted for subscriptions, bookings, QR tokens, redemptions,
-- delivery assignments/location events, payments/webhooks/refunds, commission rules,
-- agreements, ledger, settlements, payouts, compliance documents, audit logs or idempotency records.
-- Add specific SELECT policies only when a field-level data exposure review has been completed.

-- Profile/address read/write is user-owned; active providers/catalogue are public; all remaining tables are RLS-enabled
-- and have no direct anon/authenticated table privileges unless explicitly granted above.
