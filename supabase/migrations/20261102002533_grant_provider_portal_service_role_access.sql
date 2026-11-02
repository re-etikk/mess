-- The Next.js provider APIs authenticate users first, then use the server-only
-- service-role client for scoped data operations. Grant only the operations
-- those routes require; row ownership remains enforced by provider-auth.ts.
grant usage on schema public to service_role;
grant select, insert, update on public.meal_slots to service_role;
grant select, insert, update on public.provider_operating_hours to service_role;
grant select, insert, delete on public.subscription_plans to service_role;
grant select, insert on public.plan_meal_slots to service_role;

-- Correct policies whose unqualified provider_id previously resolved to the
-- membership row itself, which could let one provider member access another
-- provider's records.
drop policy if exists meal_slots_manager_all on public.meal_slots;
create policy meal_slots_manager_all on public.meal_slots
  for all to authenticated
  using (exists (
    select 1 from public.provider_memberships pm
    where pm.provider_id = meal_slots.provider_id
      and pm.user_id = (select auth.uid())
      and pm.active and pm.role in ('owner', 'manager')
  ))
  with check (exists (
    select 1 from public.provider_memberships pm
    where pm.provider_id = meal_slots.provider_id
      and pm.user_id = (select auth.uid())
      and pm.active and pm.role in ('owner', 'manager')
  ));

drop policy if exists meal_slots_member_select on public.meal_slots;
create policy meal_slots_member_select on public.meal_slots
  for select to authenticated
  using (exists (
    select 1 from public.provider_memberships pm
    where pm.provider_id = meal_slots.provider_id
      and pm.user_id = (select auth.uid()) and pm.active
  ));

drop policy if exists plans_manager_all on public.subscription_plans;
create policy plans_manager_all on public.subscription_plans
  for all to authenticated
  using (exists (
    select 1 from public.provider_memberships pm
    where pm.provider_id = subscription_plans.provider_id
      and pm.user_id = (select auth.uid())
      and pm.active and pm.role in ('owner', 'manager')
  ))
  with check (exists (
    select 1 from public.provider_memberships pm
    where pm.provider_id = subscription_plans.provider_id
      and pm.user_id = (select auth.uid())
      and pm.active and pm.role in ('owner', 'manager')
  ));

drop policy if exists plans_member_select on public.subscription_plans;
create policy plans_member_select on public.subscription_plans
  for select to authenticated
  using (exists (
    select 1 from public.provider_memberships pm
    where pm.provider_id = subscription_plans.provider_id
      and pm.user_id = (select auth.uid()) and pm.active
  ));
