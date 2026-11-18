-- =============================================================================
-- 018 — Kotak masuk chat untuk web admin
-- Kontrak untuk FE (web & Android): docs/contract-chat.md
--
-- Tabel conversations & messages sudah ada sejak migration 007. Yang ditambah:
--   1. View admin_conversations: daftar percakapan lengkap dengan klien,
--      pesanan, cuplikan pesan terakhir, dan jumlah pesan belum dibaca.
--   2. Notifikasi 'chat_message' ke admin saat customer membalas di percakapan
--      yang sudah berjalan (sebelumnya admin hanya diberi tahu saat chat dibuka).
--      Penerima: admin penanggung jawab pesanan; kalau belum ada, semua admin.
-- =============================================================================

create or replace view public.admin_conversations
with (security_invoker = true)
as
select
  c.id,
  c.status,
  c.created_at,
  c.last_message_at,
  c.customer_id,
  cu.full_name                         as customer_name,
  cu.email                             as customer_email,
  cu.phone                             as customer_phone,
  c.project_id,
  coalesce(p.code, c.order_code)       as order_code,
  p.title                              as project_title,
  p.status                             as project_status,
  p.assigned_admin_id,
  a.full_name                          as assigned_admin_name,
  lm.body                              as last_message_body,
  lm.sender_id                         as last_message_sender_id,
  (lm.sender_id = c.customer_id)       as last_message_from_customer,
  coalesce(st.message_count, 0)        as message_count,
  coalesce(st.unread_count, 0)         as unread_count
from public.conversations c
join public.profiles cu on cu.id = c.customer_id
left join public.projects p on p.id = c.project_id
left join public.profiles a on a.id = p.assigned_admin_id
left join lateral (
  select m.body, m.sender_id
  from public.messages m
  where m.conversation_id = c.id
  order by m.created_at desc, m.id desc
  limit 1
) lm on true
left join lateral (
  select
    count(*)                                                          as message_count,
    count(*) filter (where m.sender_id = c.customer_id and m.read_at is null) as unread_count
  from public.messages m
  where m.conversation_id = c.id
) st on true
where (select public.is_staff());

comment on view public.admin_conversations is
  'Daftar percakapan untuk web admin (khusus staff). unread_count = pesan dari customer yang belum dibaca. Kontrak: docs/contract-chat.md';

revoke all on public.admin_conversations from anon, authenticated;
grant select on public.admin_conversations to authenticated;

-- -----------------------------------------------------------------------------
-- Notifikasi: balasan staff -> customer (tetap), balasan customer -> admin (baru)
-- -----------------------------------------------------------------------------
create or replace function private.messages_after_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_conv     public.conversations;
  v_admin    uuid;
  v_name     text;
  v_has_prev boolean;
begin
  update public.conversations set last_message_at = new.created_at
  where id = new.conversation_id
  returning * into v_conv;

  if new.sender_id <> v_conv.customer_id then
    -- Balasan staff -> notifikasi ke customer
    perform private.notify_user(v_conv.customer_id, v_conv.project_id, 'chat_reply',
      'Balasan baru dari admin', left(new.body, 120));
  else
    -- Pesan pertama sudah diwakili notifikasi 'chat_opened'
    select exists (
      select 1 from public.messages m where m.conversation_id = new.conversation_id and m.id < new.id
    ) into v_has_prev;

    if v_has_prev then
      select full_name into v_name from public.profiles where id = v_conv.customer_id;
      select assigned_admin_id into v_admin from public.projects where id = v_conv.project_id;
      if v_admin is not null then
        perform private.notify_user(v_admin, v_conv.project_id, 'chat_message',
          'Pesan baru dari ' || coalesce(v_name, 'customer'), left(new.body, 120));
      else
        perform private.notify_role('admin', v_conv.project_id, 'chat_message',
          'Pesan baru dari ' || coalesce(v_name, 'customer'), left(new.body, 120));
      end if;
    end if;
  end if;

  return null;
end;
$$;
