-- Additive atomic pickup redemption. Call only from the authenticated server route
-- using the Supabase service-role client after HMAC token verification.
-- This migration is not permission to apply the repository baseline to production.

create or replace function public.redeem_meal_atomic(
  p_customer_id uuid,
  p_provider_id uuid,
  p_service_date date,
  p_slot_name text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_provider public.providers%rowtype;
  v_slot public.meal_slots%rowtype;
  v_subscription public.subscriptions%rowtype;
  v_daily_limit smallint;
  v_new_credits integer;
  v_booking_id uuid;
  v_redemption_id uuid;
  v_existing boolean;
  v_meal_count integer;
  v_local_now time;
  v_service_at timestamptz;
  v_idempotency_key text;
begin
  select * into v_provider
  from public.providers
  where id = p_provider_id and status = 'active';

  if not found then
    return jsonb_build_object('success', false, 'code', 'PROVIDER_NOT_ACTIVE', 'error', 'Provider is not active.');
  end if;

  if p_service_date <> (now() at time zone v_provider.timezone)::date then
    return jsonb_build_object('success', false, 'code', 'INVALID_SERVICE_DATE', 'error', 'QR is not for today.');
  end if;

  select * into v_slot
  from public.meal_slots
  where provider_id = p_provider_id and active = true and lower(name) = lower(trim(p_slot_name))
  limit 1;

  if not found then
    return jsonb_build_object('success', false, 'code', 'INVALID_SLOT', 'error', 'Meal slot is not active for this provider.');
  end if;

  v_local_now := (now() at time zone v_provider.timezone)::time;
  if (v_slot.starts_at_local <= v_slot.ends_at_local
      and (v_local_now < v_slot.starts_at_local or v_local_now > v_slot.ends_at_local))
     or (v_slot.starts_at_local > v_slot.ends_at_local
      and (v_local_now < v_slot.starts_at_local and v_local_now > v_slot.ends_at_local)) then
    return jsonb_build_object('success', false, 'code', 'OUTSIDE_MEAL_SLOT', 'error', 'Meal slot is not currently serving.');
  end if;

  -- Serialize scans for this customer/provider/date/slot. The booking unique key
  -- below is a second guard against retries and concurrent duplicate requests.
  perform pg_advisory_xact_lock(hashtextextended(
    p_customer_id::text || ':' || p_provider_id::text || ':' || p_service_date::text || ':' || v_slot.id::text,
    0
  ));

  select exists (
    select 1
    from public.meal_redemptions mr
    join public.meal_bookings mb on mb.id = mr.booking_id
    where mr.customer_id = p_customer_id
      and mr.provider_id = p_provider_id
      and mb.service_date = p_service_date
      and mb.meal_slot_id = v_slot.id
  ) into v_existing;

  if v_existing then
    return jsonb_build_object('success', false, 'code', 'ALREADY_REDEEMED', 'error', 'A meal was already redeemed for this slot today.');
  end if;

  select s.* into v_subscription
  from public.subscriptions s
  where s.customer_id = p_customer_id
    and s.provider_id = p_provider_id
    and s.status = 'active'
    and (s.starts_at is null or s.starts_at <= now())
    and (s.expires_at is null or s.expires_at > now())
    and exists (
      select 1
      from public.plan_meal_slots pms
      where pms.plan_id = s.plan_id and pms.meal_slot_id = v_slot.id
    )
    and (s.plan_type_snapshot = 'fixed_period'
      or (s.plan_type_snapshot = 'meal_credits' and coalesce(s.remaining_meal_credits, 0) > 0))
  order by s.created_at desc
  limit 1
  for update;

  if not found then
    return jsonb_build_object('success', false, 'code', 'NO_ACTIVE_SUBSCRIPTION', 'error', 'No valid meal entitlement is available.');
  end if;

  select daily_meal_limit into v_daily_limit
  from public.subscription_plans
  where id = v_subscription.plan_id and provider_id = p_provider_id and active = true;

  if v_daily_limit is null then
    return jsonb_build_object('success', false, 'code', 'PLAN_UNAVAILABLE', 'error', 'The subscription plan is unavailable.');
  end if;

  select count(*)::integer into v_meal_count
  from public.meal_redemptions mr
  where mr.subscription_id = v_subscription.id
    and (mr.redeemed_at at time zone v_provider.timezone)::date = p_service_date;

  if v_meal_count >= v_daily_limit then
    return jsonb_build_object('success', false, 'code', 'DAILY_LIMIT_REACHED', 'error', 'The daily meal limit has been reached.');
  end if;

  v_service_at := (p_service_date + v_slot.starts_at_local) at time zone v_provider.timezone;
  v_idempotency_key := 'pickup-qr:' || p_customer_id::text || ':' || p_provider_id::text || ':' || p_service_date::text || ':' || v_slot.id::text;

  insert into public.meal_bookings (
    customer_id, provider_id, booking_type, subscription_id, meal_slot_id,
    fulfillment_mode, status, service_at, service_date, idempotency_key
  ) values (
    p_customer_id, p_provider_id, 'subscription_meal', v_subscription.id, v_slot.id,
    'pickup', 'redeemed', v_service_at, p_service_date, v_idempotency_key
  ) on conflict (customer_id, idempotency_key) do nothing
  returning id into v_booking_id;

  if v_booking_id is null then
    return jsonb_build_object('success', false, 'code', 'ALREADY_REDEEMED', 'error', 'A meal was already redeemed for this slot today.');
  end if;

  if v_subscription.plan_type_snapshot = 'meal_credits' then
    update public.subscriptions
    set remaining_meal_credits = remaining_meal_credits - 1,
        status = case when remaining_meal_credits = 1 then 'expired'::public.subscription_status else status end,
        updated_at = now()
    where id = v_subscription.id
    returning remaining_meal_credits into v_new_credits;
  else
    v_new_credits := null;
  end if;

  insert into public.meal_redemptions (
    booking_id, subscription_id, customer_id, provider_id,
    fulfillment_mode, confirmation_method, metadata
  ) values (
    v_booking_id, v_subscription.id, p_customer_id, p_provider_id,
    'pickup', 'pickup_qr', jsonb_build_object('meal_slot_id', v_slot.id, 'service_date', p_service_date)
  ) returning id into v_redemption_id;

  return jsonb_build_object(
    'success', true,
    'redemption_id', v_redemption_id,
    'booking_id', v_booking_id,
    'subscription_id', v_subscription.id,
    'plan_type', v_subscription.plan_type_snapshot,
    'remaining_credits', v_new_credits,
    'redeemed_at', now()
  );
end;
$$;

revoke all on function public.redeem_meal_atomic(uuid, uuid, date, text) from public, anon, authenticated;
grant execute on function public.redeem_meal_atomic(uuid, uuid, date, text) to service_role;
