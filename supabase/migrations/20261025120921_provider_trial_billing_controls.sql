-- Platform-controlled one-month provider trial and post-trial usage pricing.
-- Payment collection is deliberately separate; this migration does not charge anyone.

create table public.platform_billing_settings (
  singleton boolean primary key default true check (singleton),
  free_trial_days integer not null default 30 check (free_trial_days between 0 and 365),
  fee_per_90_successful_redemptions_inr integer not null default 25 check (fee_per_90_successful_redemptions_inr between 0 and 100000),
  usage_billing_enabled boolean not null default false,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
create trigger platform_billing_settings_set_updated_at
  before update on public.platform_billing_settings
  for each row execute function public.set_updated_at();

-- This singleton is system configuration, not fabricated user/provider data.
insert into public.platform_billing_settings (singleton)
values (true)
on conflict (singleton) do nothing;

create table public.provider_billing_accounts (
  provider_id uuid primary key references public.providers(id) on delete cascade,
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  billing_exempt boolean not null default false,
  exempt_reason text,
  admin_note text,
  updated_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint provider_billing_trial_dates check (
    (trial_started_at is null and trial_ends_at is null)
    or (trial_started_at is not null and trial_ends_at is not null and trial_ends_at >= trial_started_at)
  ),
  constraint provider_billing_exemption_reason check (
    not billing_exempt or (exempt_reason is not null and length(trim(exempt_reason)) >= 3)
  )
);

create index provider_billing_trial_end_idx on public.provider_billing_accounts(trial_ends_at);
create trigger provider_billing_accounts_set_updated_at
  before update on public.provider_billing_accounts
  for each row execute function public.set_updated_at();

alter table public.platform_billing_settings enable row level security;
alter table public.provider_billing_accounts enable row level security;
revoke all on public.platform_billing_settings, public.provider_billing_accounts from anon, authenticated;
grant all on public.platform_billing_settings, public.provider_billing_accounts to service_role;
grant insert on public.audit_logs to service_role;

-- Existing real active providers begin their introductory period on rollout day.
insert into public.provider_billing_accounts (provider_id, trial_started_at, trial_ends_at)
select p.id, now(), now() + make_interval(days => s.free_trial_days)
from public.providers p
cross join public.platform_billing_settings s
where p.status = 'active' and s.singleton = true
on conflict (provider_id) do nothing;

-- Start the trial only when a provider is activated, never while waiting for review.
create or replace function public.start_provider_trial_on_activation()
returns trigger
language plpgsql
as $$
declare
  configured_trial_days integer;
begin
  if new.status = 'active' and (tg_op = 'INSERT' or (tg_op = 'UPDATE' and old.status is distinct from 'active')) then
    select free_trial_days into configured_trial_days
    from public.platform_billing_settings
    where singleton = true;

    insert into public.provider_billing_accounts (
      provider_id, trial_started_at, trial_ends_at
    ) values (
      new.id, now(), now() + make_interval(days => coalesce(configured_trial_days, 30))
    ) on conflict (provider_id) do nothing;
  end if;
  return new;
end;
$$;

create trigger providers_start_trial_on_activation
  after insert or update of status on public.providers
  for each row execute function public.start_provider_trial_on_activation();

-- Authenticated mess owners can submit real businesses; review and activation remain admin-only.
create or replace function public.submit_provider_application(
  p_display_name text,
  p_phone text,
  p_description text,
  p_address_line1 text,
  p_locality text,
  p_city text,
  p_state text,
  p_pincode text
)
returns table (provider_id uuid, provider_slug text)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor_id uuid := auth.uid();
  new_provider_id uuid := gen_random_uuid();
  new_slug text;
begin
  if actor_id is null then raise exception 'Authentication required'; end if;
  if length(trim(p_display_name)) < 2 or length(trim(p_display_name)) > 120 then raise exception 'Invalid business name'; end if;
  if length(trim(p_address_line1)) < 3 or length(trim(p_city)) < 2 or length(trim(p_state)) < 2 then raise exception 'Complete address required'; end if;
  if p_pincode !~ '^[0-9]{6}$' then raise exception 'A valid 6 digit PIN code is required'; end if;
  if p_phone is null or p_phone !~ '^\+?[0-9 ()-]{7,20}$' then raise exception 'A valid phone number is required'; end if;
  if length(coalesce(p_description, '')) > 1000 then raise exception 'Description is too long'; end if;

  perform pg_advisory_xact_lock(hashtext(actor_id::text)::bigint);
  if exists (
    select 1
    from public.provider_memberships pm
    join public.providers p on p.id = pm.provider_id
    where pm.user_id = actor_id and pm.active and p.status = 'pending_review'
  ) then
    raise exception 'A provider application is already awaiting review';
  end if;

  new_slug := trim(both '-' from regexp_replace(lower(p_display_name), '[^a-z0-9]+', '-', 'g'))
    || '-' || substring(new_provider_id::text, 1, 8);

  insert into public.profiles (id, display_name, phone_e164)
  values (actor_id, trim(p_display_name), nullif(trim(p_phone), ''))
  on conflict (id) do update set
    display_name = excluded.display_name,
    phone_e164 = coalesce(excluded.phone_e164, public.profiles.phone_e164);

  insert into public.providers (
    id, owner_user_id, display_name, slug, description, public_phone,
    address_line1, locality, city, state, pincode, status, supports_pickup, supports_delivery
  ) values (
    new_provider_id, actor_id, trim(p_display_name), new_slug, nullif(trim(p_description), ''),
    nullif(trim(p_phone), ''), trim(p_address_line1), nullif(trim(p_locality), ''), trim(p_city),
    trim(p_state), trim(p_pincode), 'pending_review', true, false
  );

  insert into public.provider_memberships (provider_id, user_id, role, active)
  values (new_provider_id, actor_id, 'owner', true);

  return query select new_provider_id, new_slug;
end;
$$;

revoke all on function public.submit_provider_application(text, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.submit_provider_application(text, text, text, text, text, text, text, text) to authenticated;
