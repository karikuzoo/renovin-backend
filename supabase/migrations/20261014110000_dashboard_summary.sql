-- =============================================================================
-- 010 — Ringkasan angka untuk dashboard web admin
-- Dipakai kartu "Ringkasan studio" di Dashboard (dan bagian non-keuangan Laporan).
-- Kontrak untuk FE: docs/contract-data-admin-web.md
--
-- Semua angka dihitung dari view admin_orders, jadi aturan pengelompokan status
-- dan hak aksesnya sama persis dengan daftar pesanan.
-- =============================================================================

create or replace function public.dashboard_summary(
  p_from timestamptz default null,   -- filter submitted_at >= p_from (null = sejak awal)
  p_to   timestamptz default null    -- filter submitted_at <  p_to   (null = sampai sekarang)
)
returns table (
  total_orders         bigint,          -- new + in_progress + done (tanpa yang ditolak)
  new_orders           bigint,          -- menunggu diterima admin
  in_progress_orders   bigint,          -- sedang dikerjakan
  done_orders          bigint,          -- selesai
  rejected_orders      bigint,          -- ditolak super admin
  in_progress_by_status jsonb,          -- rincian in_progress per status detail, contoh {"rab_draft": 1}
  total_order_value    numeric,         -- jumlah order_value (RAB) dari total_orders
  valued_orders        bigint,          -- berapa pesanan yang sudah punya nilai RAB
  last_completed_at    timestamptz,     -- serah terima terakhir (null = belum ada)
  generated_at         timestamptz      -- waktu angka ini dihitung
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  if not public.is_staff() then
    raise exception 'Hanya admin atau super admin yang boleh melihat ringkasan dashboard'
      using errcode = '42501';
  end if;

  return query
  with o as (
    select *
    from public.admin_orders ao
    where (p_from is null or ao.submitted_at >= p_from)
      and (p_to   is null or ao.submitted_at <  p_to)
  )
  select
    count(*) filter (where o.status_group <> 'rejected'),
    count(*) filter (where o.status_group = 'new'),
    count(*) filter (where o.status_group = 'in_progress'),
    count(*) filter (where o.status_group = 'done'),
    count(*) filter (where o.status_group = 'rejected'),
    coalesce(
      (select jsonb_object_agg(s.status, s.n)
       from (select o2.status, count(*) as n from o o2
             where o2.status_group = 'in_progress' group by o2.status) s),
      '{}'::jsonb
    ),
    coalesce(sum(o.order_value) filter (where o.status_group <> 'rejected'), 0),
    count(o.order_value) filter (where o.status_group <> 'rejected'),
    (select max(h.changed_at)
     from public.project_status_history h
     join o o3 on o3.id = h.project_id
     where h.to_status = 'completed'),
    now()
  from o;
end;
$$;

comment on function public.dashboard_summary(timestamptz, timestamptz) is
  'Ringkasan angka dashboard web admin (khusus staff). Kontrak: docs/contract-data-admin-web.md';

revoke execute on function public.dashboard_summary(timestamptz, timestamptz) from public, anon;
grant execute on function public.dashboard_summary(timestamptz, timestamptz) to authenticated;

-- Nama file kontrak berganti (migration 009 menyebut nama lama).
comment on view public.admin_orders is
  'Daftar pesanan untuk web admin (khusus staff). Kontrak: docs/contract-data-admin-web.md';
