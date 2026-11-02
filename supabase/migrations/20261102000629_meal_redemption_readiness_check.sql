-- Read-only readiness probe used before issuing a provider meal QR.
-- The provider must never receive a QR if the atomic redemption RPC is absent.
create or replace function public.meal_redemption_is_ready()
returns boolean
language sql
stable
security invoker
set search_path = public, pg_temp
as $$
  select to_regprocedure('public.redeem_meal_atomic(uuid,uuid,date,text)') is not null;
$$;

revoke all on function public.meal_redemption_is_ready() from public, anon, authenticated;
grant execute on function public.meal_redemption_is_ready() to service_role;
