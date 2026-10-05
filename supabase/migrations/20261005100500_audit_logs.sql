-- =============================================================================
-- 006 — Audit log
-- NFR Auditability: perubahan RAB, snapshot, katalog, dan tarif menyimpan
-- timestamp serta identitas user yang melakukan perubahan.
-- =============================================================================

create table public.audit_logs (
  id          bigint generated always as identity primary key,
  table_name  text not null,
  record_id   text,
  action      text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  old_data    jsonb,
  new_data    jsonb,
  actor_id    uuid,
  created_at  timestamptz not null default now()
);

create index audit_logs_record_idx on public.audit_logs (table_name, record_id, created_at desc);
create index audit_logs_actor_idx on public.audit_logs (actor_id, created_at desc);

create or replace function private.audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_row jsonb;
begin
  if tg_op in ('UPDATE', 'DELETE') then v_old := to_jsonb(old); end if;
  if tg_op in ('INSERT', 'UPDATE') then v_new := to_jsonb(new); end if;

  -- Lewati UPDATE yang tidak mengubah apa pun selain updated_at
  if tg_op = 'UPDATE' and (v_old - 'updated_at') = (v_new - 'updated_at') then
    return new;
  end if;

  v_row := coalesce(v_new, v_old);

  insert into public.audit_logs (table_name, record_id, action, old_data, new_data, actor_id)
  values (
    tg_table_name,
    coalesce(v_row ->> 'id', v_row ->> 'product_id', v_row ->> 'key'),
    tg_op,
    v_old,
    v_new,
    (select auth.uid())
  );

  return coalesce(new, old);
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'rabs', 'rab_line_items', 'rab_snapshots', 'reports',
    'products', 'product_internal_prices', 'service_rates', 'app_settings',
    'profiles'
  ]
  loop
    execute format(
      'create trigger %1$s_audit after insert or update or delete on public.%1$I
       for each row execute function private.audit_row()', t);
  end loop;
end;
$$;

alter table public.audit_logs enable row level security;

create policy "audit logs: staff baca"
  on public.audit_logs for select to authenticated
  using ((select public.is_staff()));

revoke insert, update, delete on public.audit_logs from anon, authenticated;
