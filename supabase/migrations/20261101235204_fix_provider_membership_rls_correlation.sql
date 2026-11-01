-- The unqualified `id` in these policies was resolving to
-- provider_memberships.id inside the EXISTS subquery instead of providers.id.
-- That made active owners unable to read/update their own provider row, notably
-- while the provider is pending review and is not covered by the public policy.
drop policy if exists providers_member_select on public.providers;
create policy providers_member_select on public.providers
for select to authenticated
using (
  exists (
    select 1
    from public.provider_memberships pm
    where pm.provider_id = providers.id
      and pm.user_id = (select auth.uid())
      and pm.active
  )
);

drop policy if exists providers_manager_update on public.providers;
create policy providers_manager_update on public.providers
for update to authenticated
using (
  exists (
    select 1
    from public.provider_memberships pm
    where pm.provider_id = providers.id
      and pm.user_id = (select auth.uid())
      and pm.active
      and pm.role in ('owner', 'manager')
  )
)
with check (
  exists (
    select 1
    from public.provider_memberships pm
    where pm.provider_id = providers.id
      and pm.user_id = (select auth.uid())
      and pm.active
      and pm.role in ('owner', 'manager')
  )
);
