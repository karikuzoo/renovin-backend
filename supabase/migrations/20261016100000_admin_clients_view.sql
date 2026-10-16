-- =============================================================================
-- 011 — View daftar klien untuk web admin
-- Dipakai halaman Klien (renovin-web).
-- Kontrak untuk FE: docs/contract-admin-clients.md
--
-- Satu baris = satu customer yang pernah MENGIRIM pesanan (punya minimal satu
-- baris di admin_orders). Customer yang baru daftar / hanya punya draft belum
-- dianggap klien.
--
-- Semua angka dihitung dari view admin_orders, jadi pengelompokan status dan
-- hak aksesnya sama dengan daftar pesanan:
--   - security_invoker = true -> RLS tabel asal tetap berlaku untuk pemanggil.
--   - Filter is_staff() -> customer yang memanggil view ini selalu dapat 0 baris.
-- =============================================================================

-- Status klien, dihitung dari pesanan-pesanannya (urutan prioritas dari atas).
create type public.client_status as enum (
  'active',    -- punya pesanan in_progress
  'new',       -- punya pesanan new (belum diambil admin), tidak ada yang in_progress
  'done',      -- semua pesanan yang tidak ditolak sudah done
  'inactive'   -- semua pesanannya ditolak
);

create view public.admin_clients
with (security_invoker = true)
as
with agg as (
  select
    o.customer_id,
    count(*) filter (where o.status_group <> 'rejected')                 as order_count,
    count(*) filter (where o.status_group = 'in_progress')               as active_order_count,
    count(*) filter (where o.status_group = 'new')                       as new_order_count,
    count(*) filter (where o.status_group = 'done')                      as done_order_count,
    count(*) filter (where o.status_group = 'rejected')                  as rejected_order_count,
    coalesce(sum(o.order_value) filter (where o.status_group <> 'rejected'), 0) as total_order_value,
    min(o.submitted_at)                                                  as first_order_at,
    max(o.submitted_at)                                                  as last_order_at
  from public.admin_orders o
  group by o.customer_id
)
select
  c.id,
  c.full_name,
  c.email,
  c.phone,
  c.created_at                                    as registered_at,
  a.first_order_at                                as client_since,
  (case
     when a.active_order_count > 0 then 'active'
     when a.new_order_count    > 0 then 'new'
     when a.done_order_count   > 0 then 'done'
     else 'inactive'
   end)::public.client_status                     as client_status,

  a.order_count,
  a.active_order_count,
  a.new_order_count,
  a.done_order_count,
  a.rejected_order_count,
  a.total_order_value,
  a.last_order_at,

  -- "Proyek terkait": pesanan paling relevan. Prioritas in_progress -> new -> done
  -- -> rejected, lalu yang paling akhir dikirim di dalam kelompok yang sama.
  l.id                                            as related_order_id,
  l.code                                          as related_order_code,
  l.title                                         as related_order_title,
  l.status                                        as related_order_status,
  l.status_group                                  as related_order_status_group,
  l.order_value                                   as related_order_value,
  l.assigned_admin_name                           as related_order_admin_name
from agg a
join public.profiles c on c.id = a.customer_id
left join lateral (
  select o.id, o.code, o.title, o.status, o.status_group, o.order_value, o.assigned_admin_name
  from public.admin_orders o
  where o.customer_id = a.customer_id
  order by
    case o.status_group
      when 'in_progress' then 1
      when 'new'         then 2
      when 'done'        then 3
      else 4
    end,
    o.submitted_at desc nulls last,
    o.id desc
  limit 1
) l on true
where (select public.is_staff());

comment on view public.admin_clients is
  'Daftar klien untuk web admin (khusus staff). Kontrak: docs/contract-admin-clients.md';

revoke all on public.admin_clients from anon, authenticated;
grant select on public.admin_clients to authenticated;

-- Migration 009 & 010 masih menyebut nama kontrak lama (docs/contract-data-admin-web.md).
-- Kontrak sekarang dipecah satu file per fitur.
comment on view public.admin_orders is
  'Daftar pesanan untuk web admin (khusus staff). Kontrak: docs/contract-admin-orders.md';
comment on function public.dashboard_summary(timestamptz, timestamptz) is
  'Ringkasan angka dashboard web admin (khusus staff). Kontrak: docs/contract-dashboard-summary.md';
