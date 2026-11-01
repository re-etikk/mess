-- Additive migration: Atomic meal QR redemption stored procedure
-- Complies with core schema tables (meal_redemptions, subscriptions, providers, meal_slots)
-- Ensure this is applied to staging first before production rollout.

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
  v_provider record;
  v_slot record;
  v_existing_redemption_id uuid;
  v_subscription record;
  v_new_credits integer;
  v_redemption_id uuid;
begin
  -- 1. Validate provider status
  select id, status into v_provider
  from public.providers
  where id = p_provider_id;

  if not found or v_provider.status <> 'active' then
    return jsonb_build_object(
      'success', false,
      'code', 'PROVIDER_NOT_ACTIVE',
      'error', 'Kitchen partner is not active or approved for meal redemption.'
    );
  end if;

  -- 2. Validate meal slot
  select id, name, active into v_slot
  from public.meal_slots
  where provider_id = p_provider_id
    and active = true
    and lower(name) = lower(p_slot_name)
  limit 1;

  if not found then
    return jsonb_build_object(
      'success', false,
      'code', 'INVALID_SLOT',
      'error', 'Meal slot is not active or configured for this kitchen partner.'
    );
  end if;

  -- 3. Check for duplicate redemption for the customer on the same date and slot
  select mr.id into v_existing_redemption_id
  from public.meal_redemptions mr
  where mr.customer_id = p_customer_id
    and mr.provider_id = p_provider_id
    and mr.redeemed_at::date = p_service_date
  limit 1;

  if v_existing_redemption_id is not null then
    return jsonb_build_object(
      'success', false,
      'code', 'ALREADY_REDEEMED',
      'error', 'A meal has already been redeemed for this service slot today.'
    );
  end if;

  -- 4. Locate an active entitlement in subscriptions
  select * into v_subscription
  from public.subscriptions
  where customer_id = p_customer_id
    and provider_id = p_provider_id
    and status = 'active'
    and (starts_at is null or starts_at::date <= p_service_date)
    and (expires_at is null or expires_at >= now())
  order by created_at desc
  limit 1
  for update;

  if not found then
    return jsonb_build_object(
      'success', false,
      'code', 'NO_ACTIVE_SUBSCRIPTION',
      'error', 'No active meal pass found for this kitchen. Please purchase or renew a plan.'
    );
  end if;

  -- 5. If meal-credit pack, verify and deduct credit atomically
  if v_subscription.plan_type_snapshot = 'meal_credits' then
    if coalesce(v_subscription.remaining_meal_credits, 0) <= 0 then
      return jsonb_build_object(
        'success', false,
        'code', 'INSUFFICIENT_CREDITS',
        'error', 'All meal credits on this subscription have been used.'
      );
    end if;

    v_new_credits := v_subscription.remaining_meal_credits - 1;

    update public.subscriptions
    set remaining_meal_credits = v_new_credits,
        status = case when v_new_credits = 0 then 'expired'::public.subscription_status else status end,
        updated_at = now()
    where id = v_subscription.id;
  else
    v_new_credits := null;
  end if;

  -- 6. Insert verified redemption record
  insert into public.meal_redemptions (
    customer_id,
    provider_id,
    redeemed_at
  ) values (
    p_customer_id,
    p_provider_id,
    now()
  ) returning id into v_redemption_id;

  return jsonb_build_object(
    'success', true,
    'redemption_id', v_redemption_id,
    'plan_type', v_subscription.plan_type_snapshot,
    'remaining_credits', v_new_credits,
    'redeemed_at', now()
  );
end;
$$;

grant execute on function public.redeem_meal_atomic(uuid, uuid, date, text) to authenticated, service_role;
