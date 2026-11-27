-- Thali Per-Meal Slot Pricing & Order Sync Migration (2026-11-27)
-- Safely idempotent: adds partner-editable single_meal_price_paise on meal_slots,
-- restores grants, and ensures Customer/Partner single-meal rates sync cleanly.

alter table public.meal_slots
  add column if not exists single_meal_price_paise bigint default null;

-- Clean legacy bug where Included Thali dishes with price=0 were defaulted to 3000 paise (₹30)
-- only when created with default placeholder description, so partner slot rates control single-meal pricing.
update public.menu_items
set price_paise = 0, updated_at = now()
where is_add_on = false
  and coalesce(item_kind, 'included') = 'included'
  and price_paise = 3000
  and description in ('breakfast item', 'lunch item', 'snacks item', 'dinner item');

grant usage on schema public to service_role;
grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant select on table
  public.providers,
  public.meal_slots,
  public.menu_items,
  public.subscription_plans,
  public.plan_meal_slots,
  public.provider_operating_hours
to anon, authenticated;
