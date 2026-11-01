-- Add the minimum catalog fields required for web/mobile meal-slot and paid add-on parity.
-- Apply this through a staging branch first; the connected production project currently
-- has no migration history recorded, so do not apply the repository baseline blindly.

alter table public.menu_items
  add column if not exists meal_slot_id uuid references public.meal_slots(id) on delete set null,
  add column if not exists is_add_on boolean not null default false,
  add column if not exists max_quantity integer not null default 5;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'menu_items_max_quantity_positive'
      and conrelid = 'public.menu_items'::regclass
  ) then
    alter table public.menu_items
      add constraint menu_items_max_quantity_positive check (max_quantity between 1 and 100);
  end if;
end;
$$;

create index if not exists menu_items_provider_slot_active_idx
  on public.menu_items(provider_id, meal_slot_id, active);
