-- =============================================================================
-- 007 — Chat customer ↔ admin
-- FSD: FS-14. Customer membuka percakapan dengan mengisi nomor pesanan
-- (projects.code). Pengiriman WhatsApp ditangani edge function terpisah
-- (lihat docs/decisions.md).
-- =============================================================================

create type public.conversation_status as enum ('open', 'closed');

create table public.conversations (
  id               uuid primary key default gen_random_uuid(),
  customer_id      uuid not null references public.profiles (id) on delete cascade default auth.uid(),
  project_id       uuid references public.projects (id) on delete set null,
  order_code       text,
  status           public.conversation_status not null default 'open',
  created_at       timestamptz not null default now(),
  last_message_at  timestamptz not null default now()
);

create index conversations_customer_idx on public.conversations (customer_id);
create index conversations_last_message_idx on public.conversations (last_message_at desc);
create unique index conversations_one_open_per_project
  on public.conversations (project_id) where status = 'open' and project_id is not null;

-- Nomor pesanan → project milik customer tersebut
create or replace function private.conversations_resolve_order_code()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.order_code is not null then
    new.order_code := upper(trim(new.order_code));

    select id into new.project_id
    from public.projects
    where code = new.order_code and customer_id = new.customer_id;

    if new.project_id is null then
      raise exception 'Nomor pesanan % tidak ditemukan', new.order_code using errcode = 'P0002';
    end if;
  end if;
  return new;
end;
$$;

create trigger conversations_resolve_order_code
  before insert on public.conversations
  for each row execute function private.conversations_resolve_order_code();

create or replace function private.conversations_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.notify_role('admin', new.project_id, 'chat_opened', 'Chat baru dari customer',
    coalesce('Nomor pesanan ' || new.order_code, 'Tanpa nomor pesanan'));
  return null;
end;
$$;

create trigger conversations_after_insert
  after insert on public.conversations
  for each row execute function private.conversations_after_insert();

-- -----------------------------------------------------------------------------
-- Pesan
-- -----------------------------------------------------------------------------
create table public.messages (
  id               bigint generated always as identity primary key,
  conversation_id  uuid not null references public.conversations (id) on delete cascade,
  sender_id        uuid not null references public.profiles (id) default auth.uid(),
  body             text not null check (char_length(body) between 1 and 4000),
  attachment_url   text,
  read_at          timestamptz,
  created_at       timestamptz not null default now()
);

create index messages_conversation_idx on public.messages (conversation_id, created_at);

create or replace function private.messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conv public.conversations;
begin
  update public.conversations set last_message_at = new.created_at
  where id = new.conversation_id
  returning * into v_conv;

  -- Balasan staff → notifikasi ke customer
  if new.sender_id <> v_conv.customer_id then
    perform private.notify_user(v_conv.customer_id, v_conv.project_id, 'chat_reply',
      'Balasan baru dari admin', left(new.body, 120));
  end if;

  return null;
end;
$$;

create trigger messages_after_insert
  after insert on public.messages
  for each row execute function private.messages_after_insert();

-- -----------------------------------------------------------------------------
-- Helper & RLS
-- -----------------------------------------------------------------------------
create or replace function public.can_access_conversation(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.conversations c
    where c.id = p_conversation_id
      and (c.customer_id = (select auth.uid()) or public.is_staff())
  );
$$;

alter table public.conversations enable row level security;
alter table public.messages      enable row level security;

create policy "conversations: baca"
  on public.conversations for select to authenticated
  using (customer_id = (select auth.uid()) or (select public.is_staff()));

create policy "conversations: customer buat"
  on public.conversations for insert to authenticated
  with check (
    customer_id = (select auth.uid())
    and (project_id is null or public.can_read_project(project_id))
  );

create policy "conversations: staff ubah status"
  on public.conversations for update to authenticated
  using ((select public.is_staff()))
  with check ((select public.is_staff()));

revoke insert, update, delete on public.conversations from anon, authenticated;
grant insert (order_code, project_id) on public.conversations to authenticated;
grant update (status) on public.conversations to authenticated;

create policy "messages: baca"
  on public.messages for select to authenticated
  using (public.can_access_conversation(conversation_id));

create policy "messages: kirim"
  on public.messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and public.can_access_conversation(conversation_id)
    and exists (select 1 from public.conversations c where c.id = conversation_id and c.status = 'open')
  );

create policy "messages: tandai dibaca"
  on public.messages for update to authenticated
  using (public.can_access_conversation(conversation_id) and sender_id <> (select auth.uid()))
  with check (public.can_access_conversation(conversation_id));

revoke insert, update, delete on public.messages from anon, authenticated;
grant insert (conversation_id, body, attachment_url) on public.messages to authenticated;
grant update (read_at) on public.messages to authenticated;

alter publication supabase_realtime add table public.messages, public.conversations;
