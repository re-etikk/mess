-- Thali Security Hardening & Schema Indexes (2026-11-26)
-- Fixes overly permissive public RLS on chat_messages and strengthens lookup indexes.

drop policy if exists "chat_messages_select_public" on public.chat_messages;
drop policy if exists "chat_messages_insert_public" on public.chat_messages;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'chat_messages' and policyname = 'chat_messages_participant_select'
  ) then
    create policy "chat_messages_participant_select" on public.chat_messages
      for select to authenticated
      using (
        customer_id = auth.uid()::text
        or exists (
          select 1 from public.providers p
          where p.id = chat_messages.provider_id and p.owner_user_id = auth.uid()
        )
      );
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public' and tablename = 'chat_messages' and policyname = 'chat_messages_participant_insert'
  ) then
    create policy "chat_messages_participant_insert" on public.chat_messages
      for insert to authenticated
      with check (
        sender_id = auth.uid()::text
        and (
          (sender_role = 'customer' and customer_id = auth.uid()::text)
          or (
            sender_role = 'provider'
            and exists (
              select 1 from public.providers p
              where p.id = chat_messages.provider_id and p.owner_user_id = auth.uid()
            )
          )
        )
      );
  end if;
end;
$$;
