-- Preserve historical commercial records while allowing the identity and its personal data to be erased.
alter table public.providers alter column owner_user_id drop not null;
alter table public.providers drop constraint providers_owner_user_id_fkey;
alter table public.providers add constraint providers_owner_user_id_fkey foreign key (owner_user_id) references public.profiles(id) on delete set null;

alter table public.subscriptions alter column customer_id drop not null;
alter table public.subscriptions drop constraint subscriptions_customer_id_fkey;
alter table public.subscriptions add constraint subscriptions_customer_id_fkey foreign key (customer_id) references public.profiles(id) on delete set null;

alter table public.meal_bookings alter column customer_id drop not null;
alter table public.meal_bookings drop constraint meal_bookings_customer_id_fkey;
alter table public.meal_bookings add constraint meal_bookings_customer_id_fkey foreign key (customer_id) references public.profiles(id) on delete set null;

alter table public.meal_redemptions alter column customer_id drop not null;
alter table public.meal_redemptions drop constraint meal_redemptions_customer_id_fkey;
alter table public.meal_redemptions add constraint meal_redemptions_customer_id_fkey foreign key (customer_id) references public.profiles(id) on delete set null;

alter table public.payment_transactions alter column customer_id drop not null;
alter table public.payment_transactions drop constraint payment_transactions_customer_id_fkey;
alter table public.payment_transactions add constraint payment_transactions_customer_id_fkey foreign key (customer_id) references public.profiles(id) on delete set null;

alter table public.delivery_partner_profiles alter column user_id drop not null;
alter table public.delivery_partner_profiles drop constraint delivery_partner_profiles_user_id_fkey;
alter table public.delivery_partner_profiles add constraint delivery_partner_profiles_user_id_fkey foreign key (user_id) references public.profiles(id) on delete set null;

alter table public.commercial_agreements alter column accepted_by drop not null;
alter table public.commercial_agreements drop constraint commercial_agreements_accepted_by_fkey;
alter table public.commercial_agreements add constraint commercial_agreements_accepted_by_fkey foreign key (accepted_by) references public.profiles(id) on delete set null;

alter table public.support_tickets alter column created_by drop not null;
alter table public.support_tickets drop constraint support_tickets_created_by_fkey;
alter table public.support_tickets add constraint support_tickets_created_by_fkey foreign key (created_by) references public.profiles(id) on delete set null;

create table public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  account_type text not null check (account_type in ('customer', 'provider')),
  status text not null default 'pending' check (status in ('pending', 'completed', 'failed')),
  requested_at timestamptz not null default now(),
  completed_at timestamptz,
  retention_notice text not null default 'Historical payment, booking, redemption, settlement, and audit records may be retained in anonymized form where required.'
);
create index account_deletion_requests_status_idx on public.account_deletion_requests(status, requested_at);
alter table public.account_deletion_requests enable row level security;
revoke all on public.account_deletion_requests from anon, authenticated;
grant select, insert, update on public.account_deletion_requests to service_role;
