-- Admin API reads use the server-only Supabase service_role client.
-- Grant read access only to the specific operational tables rendered by the
-- protected admin console. Do not grant these privileges to anon/authenticated.
grant select on table
  public.audit_logs,
  public.meal_bookings,
  public.meal_redemptions,
  public.payment_transactions,
  public.profiles,
  public.provider_settlements,
  public.providers,
  public.refunds,
  public.subscriptions,
  public.support_tickets,
  public.user_roles
to service_role;

-- Provider review writes are limited to approval fields only. Public and
-- authenticated roles must not receive UPDATE access through this grant.
grant update (status, approved_at, approved_by)
on table public.providers
to service_role;
