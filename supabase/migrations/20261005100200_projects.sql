-- =============================================================================
-- 003 — Project desain: foto, wall paint, penempatan furnitur, ukuran
-- FSD: FS-01 s.d. FS-07
-- =============================================================================

create type public.project_status as enum (
  'draft',
  'ready_to_submit',
  'sent_to_admin',
  'admin_processing',
  'rab_draft',
  'pending_approval',
  'approved',
  'correction',
  'rejected',
  'confirmed',
  'report_generated',
  'completed'
);

-- Nomor project yang mudah dibaca, dipakai juga sebagai "nomor pesanan" di chat.
create sequence public.project_code_seq;

create table public.projects (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null unique
                       default ('RNV-' || to_char(now(), 'YYMM') || '-' || lpad(nextval('public.project_code_seq')::text, 5, '0')),
  customer_id        uuid not null references public.profiles (id) default auth.uid(),
  title              text not null default 'Project baru',
  room_type          text,                               -- contoh: ruang tamu, kamar tidur
  notes              text,
  status             public.project_status not null default 'draft',
  assigned_admin_id  uuid references public.profiles (id),
  submitted_at       timestamptz,
  final_snapshot_id  uuid,                               -- FK ditambahkan di migration RAB
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index projects_customer_idx on public.projects (customer_id);
create index projects_status_idx on public.projects (status);
create index projects_assigned_admin_idx on public.projects (assigned_admin_id);

create trigger projects_set_updated_at
  before update on public.projects
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Foto ruangan (file di ImageKit)
-- -----------------------------------------------------------------------------
create table public.room_photos (
  id                 uuid primary key default gen_random_uuid(),
  project_id         uuid not null references public.projects (id) on delete cascade,
  original_file_id   text,
  original_url       text not null,
  processed_file_id  text,
  processed_url      text,                               -- hasil recolor + furnitur
  width              int check (width > 0),
  height             int check (height > 0),
  metadata           jsonb not null default '{}',
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (id, project_id)
);

create index room_photos_project_idx on public.room_photos (project_id);

create trigger room_photos_set_updated_at
  before update on public.room_photos
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Konfigurasi cat per area dinding
-- -----------------------------------------------------------------------------
create table public.wall_paints (
  id                 uuid primary key default gen_random_uuid(),
  project_id         uuid not null references public.projects (id) on delete cascade,
  photo_id           uuid not null,
  label              text,                               -- contoh: Dinding kiri
  mask_ref           jsonb not null default '{}',        -- referensi mask (URL/file_id/polygon)
  product_id         uuid references public.products (id),
  color_name         text,
  color_hex          text check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  preview_url        text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (id, project_id),
  foreign key (photo_id, project_id) references public.room_photos (id, project_id) on delete cascade
);

create index wall_paints_project_idx on public.wall_paints (project_id);
create index wall_paints_product_idx on public.wall_paints (product_id);

create trigger wall_paints_set_updated_at
  before update on public.wall_paints
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Penempatan furnitur
-- -----------------------------------------------------------------------------
create table public.furniture_placements (
  id                 uuid primary key default gen_random_uuid(),
  project_id         uuid not null references public.projects (id) on delete cascade,
  photo_id           uuid not null,
  product_id         uuid not null references public.products (id),
  x                  numeric(10, 4) not null default 0,
  y                  numeric(10, 4) not null default 0,
  scale              numeric(10, 4) not null default 1 check (scale > 0),
  rotation           numeric(10, 4) not null default 0,
  z_index            int not null default 0,
  rendered_url       text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  foreign key (photo_id, project_id) references public.room_photos (id, project_id) on delete cascade
);

create index furniture_placements_project_idx on public.furniture_placements (project_id);
create index furniture_placements_product_idx on public.furniture_placements (product_id);

create trigger furniture_placements_set_updated_at
  before update on public.furniture_placements
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Ukuran manual (sumber luas untuk RAB)
-- ASUMSI: luas = panjang × lebar (sesuai PRD §8). Lihat docs/decisions.md.
-- -----------------------------------------------------------------------------
create type public.measurement_area_type as enum ('wall', 'floor', 'ceiling', 'other');

create table public.room_measurements (
  id                 uuid primary key default gen_random_uuid(),
  project_id         uuid not null references public.projects (id) on delete cascade,
  wall_paint_id      uuid,                               -- area dinding yang diukur (opsional)
  area_type          public.measurement_area_type not null default 'wall',
  label              text,
  length             numeric(10, 3) not null check (length > 0),
  width              numeric(10, 3) not null check (width > 0),
  height             numeric(10, 3) check (height > 0),
  unit               text not null default 'm' check (unit = 'm'),
  area               numeric(12, 3) generated always as (round(length * width, 3)) stored,
  source             text not null default 'manual' check (source = 'manual'),
  created_by         uuid references public.profiles (id) default auth.uid(),
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  foreign key (wall_paint_id, project_id) references public.wall_paints (id, project_id) on delete set null (wall_paint_id)
);

create index room_measurements_project_idx on public.room_measurements (project_id);
create index room_measurements_wall_paint_idx on public.room_measurements (wall_paint_id);

create trigger room_measurements_set_updated_at
  before update on public.room_measurements
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Helper akses project
-- -----------------------------------------------------------------------------
create or replace function public.can_read_project(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.projects p
    where p.id = p_project_id
      and (p.customer_id = (select auth.uid()) or public.is_staff())
  );
$$;

-- Customer boleh mengubah desain hanya selama project belum dikirim.
create or replace function public.customer_can_edit_project(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.projects p
    where p.id = p_project_id
      and p.customer_id = (select auth.uid())
      and p.status in ('draft', 'ready_to_submit')
  );
$$;

-- Staff boleh mengoreksi desain/ukuran selama project diproses, sebelum final.
create or replace function public.staff_can_edit_project(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_staff() and exists (
    select 1 from public.projects p
    where p.id = p_project_id
      and p.status in ('sent_to_admin', 'admin_processing', 'rab_draft', 'correction')
  );
$$;

-- -----------------------------------------------------------------------------
-- RLS projects
-- Status TIDAK bisa diubah langsung; gunakan change_project_status().
-- -----------------------------------------------------------------------------
alter table public.projects enable row level security;

create policy "projects: baca milik sendiri atau staff"
  on public.projects for select to authenticated
  using (customer_id = (select auth.uid()) or (select public.is_staff()));

create policy "projects: customer buat project"
  on public.projects for insert to authenticated
  with check (customer_id = (select auth.uid()) and status = 'draft');

create policy "projects: customer edit selama draft"
  on public.projects for update to authenticated
  using (customer_id = (select auth.uid()) and status in ('draft', 'ready_to_submit'))
  with check (customer_id = (select auth.uid()));

create policy "projects: staff edit catatan"
  on public.projects for update to authenticated
  using ((select public.is_staff()))
  with check ((select public.is_staff()));

create policy "projects: customer hapus draft"
  on public.projects for delete to authenticated
  using (customer_id = (select auth.uid()) and status = 'draft');

revoke insert, update on public.projects from anon, authenticated;
grant insert (title, room_type, notes) on public.projects to authenticated;
grant update (title, room_type, notes) on public.projects to authenticated;
grant usage on sequence public.project_code_seq to authenticated;

-- -----------------------------------------------------------------------------
-- RLS tabel detail project (pola sama untuk keempat tabel)
-- -----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['room_photos', 'wall_paints', 'furniture_placements', 'room_measurements']
  loop
    execute format('alter table public.%I enable row level security', t);

    execute format($p$
      create policy "%1$s: baca" on public.%1$I for select to authenticated
      using (public.can_read_project(project_id))
    $p$, t);

    execute format($p$
      create policy "%1$s: insert" on public.%1$I for insert to authenticated
      with check (public.customer_can_edit_project(project_id) or public.staff_can_edit_project(project_id))
    $p$, t);

    execute format($p$
      create policy "%1$s: update" on public.%1$I for update to authenticated
      using (public.customer_can_edit_project(project_id) or public.staff_can_edit_project(project_id))
      with check (public.customer_can_edit_project(project_id) or public.staff_can_edit_project(project_id))
    $p$, t);

    execute format($p$
      create policy "%1$s: delete" on public.%1$I for delete to authenticated
      using (public.customer_can_edit_project(project_id) or public.staff_can_edit_project(project_id))
    $p$, t);
  end loop;
end;
$$;
