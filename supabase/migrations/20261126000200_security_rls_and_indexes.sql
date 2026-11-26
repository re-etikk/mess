-- Thali Security Hardening & Schema Indexes (2026-11-26)
-- Fixes overly permissive public RLS on chat_messages with explicit uuid/text-safe casts.

drop policy if exists "chat_messages_select_public" on public.chat_messages;
drop policy if exists "chat_messages_insert_public" on public.chat_messages;
drop policy if exists "chat_messages_participant_select" on public.chat_messages;
drop policy if exists "chat_messages_participant_insert" on public.chat_messages;

create policy "chat_messages_participant_select" on public.chat_messages
  for select to authenticated
  using (
    customer_id::text = (select auth.uid()::text)
    or exists (
      select 1 from public.providers p
      where p.id::text = chat_messages.provider_id::text
        and p.owner_user_id::text = (select auth.uid()::text)
    )
    or exists (
      select 1 from public.provider_memberships pm
      where pm.provider_id::text = chat_messages.provider_id::text
        and pm.user_id::text = (select auth.uid()::text)
        and pm.active
    )
  );

create policy "chat_messages_participant_insert" on public.chat_messages
  for insert to authenticated
  with check (
    sender_id::text = (select auth.uid()::text)
    and (
      (sender_role = 'customer' and customer_id::text = (select auth.uid()::text))
      or (
        sender_role = 'provider'
        and (
          exists (
            select 1 from public.providers p
            where p.id::text = chat_messages.provider_id::text
              and p.owner_user_id::text = (select auth.uid()::text)
          )
          or exists (
            select 1 from public.provider_memberships pm
            where pm.provider_id::text = chat_messages.provider_id::text
              and pm.user_id::text = (select auth.uid()::text)
              and pm.active
          )
        )
      )
    )
  );
