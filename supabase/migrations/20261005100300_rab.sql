-- =============================================================================
-- 004 — RAB (draft & line items), snapshot final, laporan PDF
-- FSD: FS-09, FS-11, FS-12, FS-13, §7
--
-- Formula (PRD §8):
--   Luas                       = panjang × lebar         (room_measurements.area)
--   Material subtotal internal = luas × harga katalog (I)
--   Material subtotal customer = luas × harga katalog (U)
--   Total customer             = material customer + jasa + adjustment + pajak
--   Total internal             = material internal
-- =============================================================================

create type public.rab_item_type as enum ('material', 'furniture', 'service', 'other');

-- -----------------------------------------------------------------------------
-- RAB (satu per project)
-- -----------------------------------------------------------------------------
create table public.rabs (
  id                       uuid primary key default gen_random_uuid(),
  project_id               uuid not null unique references public.projects (id) on delete cascade,
  material_total_customer  numeric(14, 2) not null default 0,
  material_total_internal  numeric(14, 2) not null default 0,
  service_total            numeric(14, 2) not null default 0,
  adjustment               numeric(14, 2) not null default 0,   -- koreksi manual admin (+/-)
  adjustment_note          text,
  tax_percent              numeric(5, 2) not null default 0 check (tax_percent >= 0),
  tax_amount               numeric(14, 2) not null default 0,
  grand_total_customer     numeric(14, 2) not null default 0,
  grand_total_internal     numeric(14, 2) not null default 0,
  notes                    text,
  calculated_by            uuid references public.profiles (id),
  calculated_at            timestamptz,
  updated_by               uuid references public.profiles (id) default auth.uid(),
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  unique (id, project_id)
);

-- Total selalu dihitung ulang oleh database, tidak pernah dikirim dari client.
create or replace function private.rabs_compute_totals()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.tax_amount := round(
    (new.material_total_customer + new.service_total + new.adjustment) * new.tax_percent / 100, 2
  );
  new.grand_total_customer := new.material_total_customer + new.service_total + new.adjustment + new.tax_amount;
  new.grand_total_internal := new.material_total_internal;
  new.updated_at := now();
  new.updated_by := coalesce((select auth.uid()), new.updated_by);
  return new;
end;
$$;

create trigger rabs_compute_totals
  before insert or update on public.rabs
  for each row execute function private.rabs_compute_totals();

-- -----------------------------------------------------------------------------
-- Baris RAB. Harga disalin saat dihitung supaya perubahan katalog tidak
-- mengubah RAB yang sudah ada.
-- -----------------------------------------------------------------------------
create table public.rab_line_items (
  id                   uuid primary key default gen_random_uuid(),
  rab_id               uuid not null,
  project_id           uuid not null,
  item_type            public.rab_item_type not null,
  product_id           uuid references public.products (id),
  service_rate_id      uuid references public.service_rates (id),
  wall_paint_id        uuid references public.wall_paints (id) on delete set null,
  placement_id         uuid references public.furniture_placements (id) on delete set null,
  description          text not null,
  quantity             numeric(12, 3) not null check (quantity >= 0),
  unit                 text not null,
  unit_price_customer  numeric(14, 2) not null default 0 check (unit_price_customer >= 0),
  unit_price_internal  numeric(14, 2) not null default 0 check (unit_price_internal >= 0),
  subtotal_customer    numeric(14, 2) generated always as (round(quantity * unit_price_customer, 2)) stored,
  subtotal_internal    numeric(14, 2) generated always as (round(quantity * unit_price_internal, 2)) stored,
  is_manual            boolean not null default true,   -- false = dibuat otomatis oleh calculate_rab()
  sort_order           int not null default 0,
  created_by           uuid references public.profiles (id) default auth.uid(),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  foreign key (rab_id, project_id) references public.rabs (id, project_id) on delete cascade
);

create index rab_line_items_rab_idx on public.rab_line_items (rab_id);
create index rab_line_items_project_idx on public.rab_line_items (project_id);

create trigger rab_line_items_set_updated_at
  before update on public.rab_line_items
  for each row execute function private.set_updated_at();

-- Hitung ulang total RAB dari line items.
create or replace function private.recalc_rab_totals(p_rab_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.rabs r
  set material_total_customer = coalesce(s.material_customer, 0),
      material_total_internal = coalesce(s.material_internal, 0),
      service_total           = coalesce(s.service, 0)
  from (
    select
      sum(subtotal_customer) filter (where item_type <> 'service') as material_customer,
      sum(subtotal_internal) filter (where item_type <> 'service') as material_internal,
      sum(subtotal_customer) filter (where item_type = 'service')  as service
    from public.rab_line_items
    where rab_id = p_rab_id
  ) s
  where r.id = p_rab_id;
end;
$$;

create or replace function private.rab_line_items_after_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.recalc_rab_totals(coalesce(new.rab_id, old.rab_id));
  return null;
end;
$$;

create trigger rab_line_items_recalc
  after insert or update or delete on public.rab_line_items
  for each row execute function private.rab_line_items_after_change();

-- -----------------------------------------------------------------------------
-- Snapshot final — insert-only, tidak bisa diubah atau dihapus.
-- -----------------------------------------------------------------------------
create table public.rab_snapshots (
  id          uuid primary key default gen_random_uuid(),
  project_id  uuid not null references public.projects (id) on delete restrict,
  version     int not null check (version > 0),
  data        jsonb not null,
  created_by  uuid references public.profiles (id),
  created_at  timestamptz not null default now(),
  unique (project_id, version)
);

create or replace function private.prevent_snapshot_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Snapshot final tidak dapat diubah atau dihapus' using errcode = '42501';
end;
$$;

create trigger rab_snapshots_immutable
  before update or delete on public.rab_snapshots
  for each row execute function private.prevent_snapshot_change();

alter table public.projects
  add constraint projects_final_snapshot_fk
  foreign key (final_snapshot_id) references public.rab_snapshots (id);

-- -----------------------------------------------------------------------------
-- Laporan PDF — satu laporan per snapshot. Generate ulang = upsert,
-- tidak membuat snapshot baru (NFR Reliability).
-- -----------------------------------------------------------------------------
create table public.reports (
  id            uuid primary key default gen_random_uuid(),
  project_id    uuid not null references public.projects (id) on delete restrict,
  snapshot_id   uuid not null unique references public.rab_snapshots (id),
  pdf_file_id   text,
  pdf_url       text not null,
  generated_by  uuid references public.profiles (id) default auth.uid(),
  generated_at  timestamptz not null default now()
);

create index reports_project_idx on public.reports (project_id);

-- -----------------------------------------------------------------------------
-- Helper: kapan RAB boleh diedit
-- ASUMSI (docs/decisions.md): staff saat admin_processing/rab_draft/correction,
-- super admin juga saat pending_approval.
-- -----------------------------------------------------------------------------
create or replace function public.can_edit_rab(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.projects p
    where p.id = p_project_id
      and (
        (public.is_staff() and p.status in ('admin_processing', 'rab_draft', 'correction'))
        or (public.is_super_admin() and p.status = 'pending_approval')
      )
  );
$$;

-- -----------------------------------------------------------------------------
-- Perhitungan RAB otomatis
-- -----------------------------------------------------------------------------
create or replace function private.calculate_rab(p_project_id uuid, p_actor uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rab_id      uuid;
  v_tax         numeric;
  v_has_items   boolean;
begin
  select coalesce((value ->> 'tax_percent')::numeric, 0) into v_tax
  from public.app_settings where key = 'tax';

  insert into public.rabs (project_id, tax_percent, calculated_by, calculated_at, updated_by)
  values (p_project_id, coalesce(v_tax, 0), p_actor, now(), p_actor)
  on conflict (project_id) do update
    set tax_percent   = excluded.tax_percent,
        calculated_by = excluded.calculated_by,
        calculated_at = excluded.calculated_at
  returning id into v_rab_id;

  -- Baris otomatis dibuat ulang; baris manual dari admin dipertahankan.
  delete from public.rab_line_items where rab_id = v_rab_id and not is_manual;

  -- 1) Cat: luas dari ukuran yang terhubung ke wall paint × harga katalog
  insert into public.rab_line_items (
    rab_id, project_id, item_type, product_id, wall_paint_id, description,
    quantity, unit, unit_price_customer, unit_price_internal, is_manual, sort_order, created_by
  )
  select
    v_rab_id, p_project_id, 'material', pr.id, wp.id,
    pr.name || coalesce(' — ' || wp.label, ''),
    m.total_area, pr.unit, pr.price_customer, coalesce(ip.price_internal, 0), false, 10, p_actor
  from public.wall_paints wp
  join public.products pr on pr.id = wp.product_id
  left join public.product_internal_prices ip on ip.product_id = pr.id
  join lateral (
    select sum(rm.area) as total_area
    from public.room_measurements rm
    where rm.wall_paint_id = wp.id
  ) m on m.total_area > 0
  where wp.project_id = p_project_id;

  -- 2) Furnitur: 1 unit per penempatan
  insert into public.rab_line_items (
    rab_id, project_id, item_type, product_id, placement_id, description,
    quantity, unit, unit_price_customer, unit_price_internal, is_manual, sort_order, created_by
  )
  select
    v_rab_id, p_project_id, 'furniture', pr.id, fp.id, pr.name,
    1, pr.unit, pr.price_customer, coalesce(ip.price_internal, 0), false, 20, p_actor
  from public.furniture_placements fp
  join public.products pr on pr.id = fp.product_id
  left join public.product_internal_prices ip on ip.product_id = pr.id
  where fp.project_id = p_project_id;

  -- 3) Jasa (per_m2: luas dari item dengan tipe applies_to; flat: 1 paket)
  select exists (select 1 from public.rab_line_items where rab_id = v_rab_id) into v_has_items;

  insert into public.rab_line_items (
    rab_id, project_id, item_type, service_rate_id, description,
    quantity, unit, unit_price_customer, unit_price_internal, is_manual, sort_order, created_by
  )
  select
    v_rab_id, p_project_id, 'service', sr.id, sr.name,
    case sr.calc_type
      when 'per_m2' then (
        select coalesce(sum(li.quantity), 0)
        from public.rab_line_items li
        join public.products pr on pr.id = li.product_id
        where li.rab_id = v_rab_id and pr.type = sr.applies_to and li.item_type <> 'service'
      )
      else 1
    end,
    case sr.calc_type when 'per_m2' then 'm2' else 'paket' end,
    sr.rate, 0, false, 30, p_actor
  from public.service_rates sr
  where sr.active
    and v_has_items
    and (sr.calc_type = 'flat' or exists (
      select 1 from public.rab_line_items li
      join public.products pr on pr.id = li.product_id
      where li.rab_id = v_rab_id and pr.type = sr.applies_to
    ));

  perform private.recalc_rab_totals(v_rab_id);
  return v_rab_id;
end;
$$;

-- Dipanggil web admin: supabase.rpc('calculate_rab', { p_project_id })
create or replace function public.calculate_rab(p_project_id uuid)
returns public.rabs
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rab_id uuid;
  v_rab    public.rabs;
begin
  if not public.can_edit_rab(p_project_id) then
    raise exception 'RAB tidak dapat dihitung pada status project ini atau Anda tidak berwenang'
      using errcode = '42501';
  end if;

  v_rab_id := private.calculate_rab(p_project_id, (select auth.uid()));
  select * into v_rab from public.rabs where id = v_rab_id;

  return v_rab;
end;
$$;

revoke execute on function public.calculate_rab(uuid) from public, anon;
grant execute on function public.calculate_rab(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- Pembuatan snapshot final (dipanggil oleh change_project_status → confirmed)
-- -----------------------------------------------------------------------------
create or replace function private.create_final_snapshot(p_project_id uuid, p_actor uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id       uuid;
  v_version  int;
  v_data     jsonb;
begin
  select coalesce(max(version), 0) + 1 into v_version
  from public.rab_snapshots where project_id = p_project_id;

  select jsonb_build_object(
    'project',  to_jsonb(p),
    'customer', jsonb_build_object('id', c.id, 'full_name', c.full_name, 'email', c.email, 'phone', c.phone),
    'photos', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at) from public.room_photos x where x.project_id = p.id), '[]'),
    'wall_paints', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at) from public.wall_paints x where x.project_id = p.id), '[]'),
    'furniture_placements', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.z_index, x.created_at) from public.furniture_placements x where x.project_id = p.id), '[]'),
    'measurements', coalesce((
      select jsonb_agg(to_jsonb(x) order by x.created_at) from public.room_measurements x where x.project_id = p.id), '[]'),
    'rab', (select to_jsonb(r) from public.rabs r where r.project_id = p.id),
    'rab_line_items', coalesce((
      select jsonb_agg(to_jsonb(li) order by li.sort_order, li.created_at)
      from public.rab_line_items li where li.project_id = p.id), '[]'),
    'version', v_version,
    'confirmed_by', p_actor,
    'confirmed_at', now()
  )
  into v_data
  from public.projects p
  join public.profiles c on c.id = p.customer_id
  where p.id = p_project_id;

  insert into public.rab_snapshots (project_id, version, data, created_by)
  values (p_project_id, v_version, v_data, p_actor)
  returning id into v_id;

  return v_id;
end;
$$;

-- -----------------------------------------------------------------------------
-- RLS
-- RAB berisi harga internal → hanya staff. Customer menerima hasil lewat PDF.
-- -----------------------------------------------------------------------------
alter table public.rabs           enable row level security;
alter table public.rab_line_items enable row level security;
alter table public.rab_snapshots  enable row level security;
alter table public.reports        enable row level security;

create policy "rabs: staff baca"
  on public.rabs for select to authenticated
  using ((select public.is_staff()));
create policy "rabs: staff update saat boleh edit"
  on public.rabs for update to authenticated
  using (public.can_edit_rab(project_id))
  with check (public.can_edit_rab(project_id));

-- Insert RAB hanya lewat calculate_rab(); admin hanya boleh mengubah kolom ini:
revoke insert, update, delete on public.rabs from anon, authenticated;
grant update (adjustment, adjustment_note, notes) on public.rabs to authenticated;

create policy "rab items: staff baca"
  on public.rab_line_items for select to authenticated
  using ((select public.is_staff()));
create policy "rab items: staff insert saat boleh edit"
  on public.rab_line_items for insert to authenticated
  with check (public.can_edit_rab(project_id));
create policy "rab items: staff update saat boleh edit"
  on public.rab_line_items for update to authenticated
  using (public.can_edit_rab(project_id))
  with check (public.can_edit_rab(project_id));
create policy "rab items: staff delete saat boleh edit"
  on public.rab_line_items for delete to authenticated
  using (public.can_edit_rab(project_id));

-- Snapshot: baca saja. Insert hanya lewat change_project_status().
create policy "snapshots: staff baca"
  on public.rab_snapshots for select to authenticated
  using ((select public.is_staff()));
revoke insert, update, delete on public.rab_snapshots from anon, authenticated;

-- Laporan: customer bisa melihat laporan project-nya sendiri.
create policy "reports: baca"
  on public.reports for select to authenticated
  using (public.can_read_project(project_id));

create policy "reports: staff insert untuk snapshot final"
  on public.reports for insert to authenticated
  with check (
    (select public.is_staff())
    and exists (
      select 1 from public.projects p
      where p.id = project_id
        and p.final_snapshot_id = snapshot_id
        and p.status in ('confirmed', 'report_generated')
    )
  );

create policy "reports: staff update (generate ulang)"
  on public.reports for update to authenticated
  using ((select public.is_staff()))
  with check (
    (select public.is_staff())
    and exists (
      select 1 from public.projects p
      where p.id = project_id
        and p.final_snapshot_id = snapshot_id
        and p.status in ('confirmed', 'report_generated')
    )
  );
