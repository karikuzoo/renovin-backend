-- =============================================================================
-- 009 — View daftar pesanan untuk web admin
-- Dipakai halaman Dashboard, Pesanan, dan Pesanan Baru (renovin-web).
-- Kontrak untuk FE: docs/data-admin-web.md
--
-- Satu baris = satu project yang sudah dikirim customer, lengkap dengan data
-- customer, admin penanggung jawab, nilai RAB, total luas, dan foto sampul.
--
-- Keamanan:
--   - security_invoker = true -> RLS tabel asal tetap berlaku untuk pemanggil.
--   - Filter is_staff() -> customer yang memanggil view ini selalu dapat 0 baris
--     (customer tetap membaca project miliknya lewat tabel projects).
-- =============================================================================

-- Pengelompokan 12 status project menjadi tab di web admin.
create type public.order_status_group as enum (
  'new',          -- sent_to_admin: pesanan masuk, belum diambil admin
  'in_progress',  -- admin_processing s.d. report_generated
  'done',         -- completed
  'rejected'      -- rejected (ditolak super admin)
);

create or replace function public.order_status_group_of(p_status public.project_status)
returns public.order_status_group
language sql
immutable
set search_path = ''
as $$
  select case p_status
    when 'sent_to_admin' then 'new'
    when 'completed'     then 'done'
    when 'rejected'      then 'rejected'
    when 'draft'           then null
    when 'ready_to_submit' then null
    else 'in_progress'
  end::public.order_status_group;
$$;

comment on function public.order_status_group_of(public.project_status) is
  'Kelompok tab web admin untuk sebuah status project. null untuk draft/ready_to_submit (belum dikirim).';

create view public.admin_orders
with (security_invoker = true)
as
select
  p.id,
  p.code,
  p.title,
  p.room_type,
  p.notes,
  p.status,
  public.order_status_group_of(p.status)  as status_group,
  p.submitted_at,
  p.updated_at,

  p.customer_id,
  c.full_name                             as customer_name,
  c.email                                 as customer_email,
  c.phone                                 as customer_phone,

  p.assigned_admin_id,
  a.full_name                             as assigned_admin_name,

  -- null selama RAB belum pernah dihitung
  r.grand_total_customer                  as order_value,
  r.calculated_at                         as rab_calculated_at,

  coalesce(m.total_area, 0)               as total_area,
  coalesce(m.measurement_count, 0)        as measurement_count,

  -- PATH objek di bucket privat room-photos; tampilkan dengan createSignedUrl
  ph.cover_photo_path,
  coalesce(ph.photo_count, 0)             as photo_count
from public.projects p
join public.profiles c on c.id = p.customer_id
left join public.profiles a on a.id = p.assigned_admin_id
left join public.rabs r on r.project_id = p.id
left join lateral (
  select sum(rm.area) as total_area, count(*) as measurement_count
  from public.room_measurements rm
  where rm.project_id = p.id
) m on true
left join lateral (
  select
    (array_agg(rp.original_url order by rp.created_at, rp.id))[1] as cover_photo_path,
    count(*)                                                       as photo_count
  from public.room_photos rp
  where rp.project_id = p.id
) ph on true
where p.status not in ('draft', 'ready_to_submit')
  and (select public.is_staff());

comment on view public.admin_orders is
  'Daftar pesanan untuk web admin (khusus staff). Kontrak: docs/data-admin-web.md';

revoke all on public.admin_orders from anon, authenticated;
grant select on public.admin_orders to authenticated;

-- Filter "pesanan baru" & urutan terbaru di daftar pesanan.
create index if not exists projects_submitted_at_idx on public.projects (submitted_at desc);
