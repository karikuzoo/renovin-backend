-- =============================================================================
-- 005 — Workflow status project, approval super admin, notifikasi
-- FSD: FS-07, FS-10, FS-12, §8
--
-- Status hanya bisa diubah lewat:
--   supabase.rpc('change_project_status', { p_project_id, p_to_status, p_note })
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Aturan transisi (ASUMSI — lihat docs/decisions.md, ubah lewat migration baru)
-- -----------------------------------------------------------------------------
create table public.project_status_transitions (
  from_status    public.project_status not null,
  to_status      public.project_status not null,
  allowed_roles  public.user_role[] not null,
  note_required  boolean not null default false,
  primary key (from_status, to_status)
);

comment on table public.project_status_transitions is
  'Daftar transisi status yang diizinkan beserta role yang boleh melakukannya. Dibaca UI untuk menampilkan tombol aksi.';

insert into public.project_status_transitions (from_status, to_status, allowed_roles, note_required) values
  ('draft',            'ready_to_submit',  '{customer}',               false),
  ('ready_to_submit',  'draft',            '{customer}',               false),
  ('draft',            'sent_to_admin',    '{customer}',               false),
  ('ready_to_submit',  'sent_to_admin',    '{customer}',               false),
  ('sent_to_admin',    'admin_processing', '{admin,super_admin}',      false),
  ('admin_processing', 'rab_draft',        '{admin,super_admin}',      false),
  ('rab_draft',        'admin_processing', '{admin,super_admin}',      false),
  ('rab_draft',        'pending_approval', '{admin,super_admin}',      false),
  ('pending_approval', 'approved',         '{super_admin}',            false),
  ('pending_approval', 'correction',       '{super_admin}',            true),
  ('pending_approval', 'rejected',         '{super_admin}',            true),
  ('correction',       'admin_processing', '{admin,super_admin}',      false),
  ('correction',       'rab_draft',        '{admin,super_admin}',      false),
  ('approved',         'confirmed',        '{admin,super_admin}',      false),
  ('confirmed',        'report_generated', '{admin,super_admin}',      false),
  ('report_generated', 'completed',        '{admin,super_admin}',      false);

-- -----------------------------------------------------------------------------
-- Riwayat status (audit trail perpindahan status)
-- -----------------------------------------------------------------------------
create table public.project_status_history (
  id           bigint generated always as identity primary key,
  project_id   uuid not null references public.projects (id) on delete cascade,
  from_status  public.project_status,
  to_status    public.project_status not null,
  note         text,
  changed_by   uuid references public.profiles (id),
  changed_at   timestamptz not null default now()
);

create index project_status_history_project_idx on public.project_status_history (project_id, changed_at);

-- -----------------------------------------------------------------------------
-- Keputusan super admin
-- -----------------------------------------------------------------------------
create type public.approval_decision as enum ('approved', 'correction', 'rejected');

create table public.approvals (
  id          uuid primary key default gen_random_uuid(),
  project_id  uuid not null references public.projects (id) on delete cascade,
  rab_id      uuid references public.rabs (id) on delete set null,
  decision    public.approval_decision not null,
  note        text,
  rab_data    jsonb,                                -- salinan RAB saat keputusan diambil
  decided_by  uuid not null references public.profiles (id),
  decided_at  timestamptz not null default now()
);

create index approvals_project_idx on public.approvals (project_id, decided_at);

-- -----------------------------------------------------------------------------
-- Notifikasi in-app (didengarkan web/android lewat Supabase Realtime)
-- -----------------------------------------------------------------------------
create table public.notifications (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  project_id  uuid references public.projects (id) on delete cascade,
  type        text not null,
  title       text not null,
  body        text,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_unread_idx on public.notifications (user_id) where read_at is null;

create or replace function private.notify_user(
  p_user_id uuid, p_project_id uuid, p_type text, p_title text, p_body text default null
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, project_id, type, title, body)
  values (p_user_id, p_project_id, p_type, p_title, p_body);
$$;

create or replace function private.notify_role(
  p_role public.user_role, p_project_id uuid, p_type text, p_title text, p_body text default null
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notifications (user_id, project_id, type, title, body)
  select id, p_project_id, p_type, p_title, p_body
  from public.profiles where role = p_role;
$$;

-- -----------------------------------------------------------------------------
-- Ubah status project
-- -----------------------------------------------------------------------------
create or replace function public.change_project_status(
  p_project_id uuid,
  p_to_status  public.project_status,
  p_note       text default null
)
returns public.projects
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := (select auth.uid());
  v_role        public.user_role;
  v_project     public.projects;
  v_transition  public.project_status_transitions;
  v_rab         public.rabs;
  v_snapshot_id uuid;
  v_label       text;
begin
  if v_uid is null then
    raise exception 'Harus login' using errcode = '28000';
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role is null then
    raise exception 'Profile user tidak ditemukan' using errcode = '28000';
  end if;

  select * into v_project from public.projects where id = p_project_id for update;
  if not found or (v_role = 'customer' and v_project.customer_id <> v_uid) then
    raise exception 'Project tidak ditemukan' using errcode = 'P0002';
  end if;

  select * into v_transition
  from public.project_status_transitions
  where from_status = v_project.status and to_status = p_to_status;

  if not found or not (v_role = any (v_transition.allowed_roles)) then
    raise exception 'Perubahan status % → % tidak diizinkan untuk role %',
      v_project.status, p_to_status, v_role using errcode = '42501';
  end if;

  if v_transition.note_required and nullif(trim(p_note), '') is null then
    raise exception 'Catatan wajib diisi untuk status %', p_to_status using errcode = '23514';
  end if;

  -- Validasi data minimum per status tujuan
  if p_to_status in ('ready_to_submit', 'sent_to_admin')
     and not exists (select 1 from public.room_photos where project_id = p_project_id) then
    raise exception 'Project belum memiliki foto ruangan' using errcode = '23514';
  end if;

  if p_to_status in ('rab_draft', 'pending_approval', 'confirmed') then
    select * into v_rab from public.rabs where project_id = p_project_id;
    if not found or not exists (select 1 from public.rab_line_items where rab_id = v_rab.id) then
      raise exception 'RAB belum dihitung atau masih kosong' using errcode = '23514';
    end if;
  end if;

  if p_to_status = 'report_generated'
     and not exists (select 1 from public.reports where snapshot_id = v_project.final_snapshot_id) then
    raise exception 'Laporan PDF untuk snapshot final belum dibuat' using errcode = '23514';
  end if;

  -- Efek samping
  if p_to_status = 'sent_to_admin' then
    v_project.submitted_at := now();
  end if;

  if p_to_status = 'admin_processing' and v_project.assigned_admin_id is null then
    v_project.assigned_admin_id := v_uid;
  end if;

  if p_to_status in ('approved', 'correction', 'rejected') then
    select * into v_rab from public.rabs where project_id = p_project_id;
    insert into public.approvals (project_id, rab_id, decision, note, rab_data, decided_by)
    values (
      p_project_id, v_rab.id, p_to_status::text::public.approval_decision, p_note,
      case when v_rab.id is null then null else jsonb_build_object(
        'rab', to_jsonb(v_rab),
        'line_items', (select coalesce(jsonb_agg(to_jsonb(li) order by li.sort_order), '[]')
                       from public.rab_line_items li where li.rab_id = v_rab.id)
      ) end,
      v_uid
    );
  end if;

  if p_to_status = 'confirmed' then
    v_snapshot_id := private.create_final_snapshot(p_project_id, v_uid);
    v_project.final_snapshot_id := v_snapshot_id;
  end if;

  update public.projects
  set status            = p_to_status,
      submitted_at      = v_project.submitted_at,
      assigned_admin_id = v_project.assigned_admin_id,
      final_snapshot_id = v_project.final_snapshot_id
  where id = p_project_id
  returning * into v_project;

  insert into public.project_status_history (project_id, from_status, to_status, note, changed_by)
  values (p_project_id, v_transition.from_status, p_to_status, p_note, v_uid);

  -- Notifikasi
  v_label := v_project.code || ' — ' || v_project.title;

  case p_to_status
    when 'sent_to_admin' then
      perform private.notify_role('admin', p_project_id, 'project_submitted', 'Project baru masuk', v_label);
    when 'pending_approval' then
      perform private.notify_role('super_admin', p_project_id, 'approval_requested', 'Menunggu persetujuan', v_label);
    when 'approved', 'correction', 'rejected' then
      if v_project.assigned_admin_id is not null then
        perform private.notify_user(v_project.assigned_admin_id, p_project_id, 'approval_' || p_to_status::text,
          'Keputusan super admin: ' || p_to_status::text, coalesce(p_note, v_label));
      else
        perform private.notify_role('admin', p_project_id, 'approval_' || p_to_status::text,
          'Keputusan super admin: ' || p_to_status::text, coalesce(p_note, v_label));
      end if;
    when 'report_generated' then
      perform private.notify_user(v_project.customer_id, p_project_id, 'report_ready',
        'Laporan desain Anda sudah siap', v_label);
    else
      null;
  end case;

  return v_project;
end;
$$;

revoke execute on function public.change_project_status(uuid, public.project_status, text) from public, anon;
grant execute on function public.change_project_status(uuid, public.project_status, text) to authenticated;

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
alter table public.project_status_transitions enable row level security;
alter table public.project_status_history     enable row level security;
alter table public.approvals                  enable row level security;
alter table public.notifications              enable row level security;

create policy "transitions: baca (user login)"
  on public.project_status_transitions for select to authenticated
  using (true);
revoke insert, update, delete on public.project_status_transitions from anon, authenticated;

create policy "status history: baca"
  on public.project_status_history for select to authenticated
  using (public.can_read_project(project_id));
revoke insert, update, delete on public.project_status_history from anon, authenticated;

create policy "approvals: staff baca"
  on public.approvals for select to authenticated
  using ((select public.is_staff()));
revoke insert, update, delete on public.approvals from anon, authenticated;

create policy "notifications: baca milik sendiri"
  on public.notifications for select to authenticated
  using (user_id = (select auth.uid()));
create policy "notifications: tandai dibaca"
  on public.notifications for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
revoke insert, update, delete on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

alter publication supabase_realtime add table public.notifications;
