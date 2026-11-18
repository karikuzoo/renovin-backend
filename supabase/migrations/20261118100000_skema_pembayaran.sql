-- =============================================================================
-- 016 — Skema pembayaran per pesanan (pencatatan, BUKAN transaksi)
-- Kontrak untuk FE (web & Android): docs/contract-pembayaran.md
-- Keputusan: docs/decisions.md Q16
--
-- Aplikasi tidak memproses uang. Yang dicatat:
--   1. Skema yang diminta klien (requested_scheme) dari aplikasi Android.
--   2. Skema yang ditetapkan admin: Lunas / DP / Termin / Progress, berupa
--      1–4 baris pembayaran dalam PERSEN dari total RAB.
--   3. Baris yang sudah dibayar (ditandai admin, dengan tanggal & catatan).
--
-- Aturan (Q16):
--   - Total semua baris = 100%.
--   - Pembayaran pertama minimal 30% (kecuali Lunas = 1 baris 100%).
--   - DP = tepat 2 baris (DP + pelunasan). Termin & Progress = 2–4 baris.
--   - Termin: setiap baris wajib punya tanggal jatuh tempo, urut naik.
--   - Progress: setiap baris wajib punya keterangan tahap pekerjaan.
--   - Sebelum konfirmasi final hanya persen yang disimpan; nominal dihitung
--     dari total RAB terbaru. Saat status menjadi 'confirmed', skema WAJIB ada
--     dan nominal DIBEKUKAN (dibulatkan ke rupiah, baris terakhir menampung sisa).
--   - Tanda "sudah dibayar" hanya setelah skema dikunci.
-- =============================================================================

create type public.payment_scheme as enum ('full', 'dp', 'termin', 'progress');

-- -----------------------------------------------------------------------------
-- Tabel
-- -----------------------------------------------------------------------------
create table public.payment_plans (
  project_id        uuid primary key references public.projects (id) on delete cascade,
  requested_scheme  public.payment_scheme,
  requested_note    text check (length(requested_note) <= 500),
  requested_at      timestamptz,
  scheme            public.payment_scheme,
  total_amount      numeric(14, 2),
  locked_at         timestamptz,
  updated_by        uuid references public.profiles (id),
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  constraint payment_plans_locked_complete check (locked_at is null or (scheme is not null and total_amount is not null))
);

comment on table public.payment_plans is 'Skema pembayaran per pesanan (pencatatan, bukan transaksi). Kontrak: docs/contract-pembayaran.md';
comment on column public.payment_plans.requested_scheme is 'Skema yang diminta klien dari aplikasi. Admin boleh menetapkan skema lain.';
comment on column public.payment_plans.scheme is 'Skema yang ditetapkan admin; null = belum ditetapkan.';
comment on column public.payment_plans.total_amount is 'Total RAB yang dibekukan saat konfirmasi final; null sebelum dikunci.';

create trigger payment_plans_set_updated_at
  before update on public.payment_plans
  for each row execute function private.set_updated_at();

create table public.payment_installments (
  id                uuid primary key default gen_random_uuid(),
  project_id        uuid not null references public.payment_plans (project_id) on delete cascade,
  seq               int not null check (seq between 1 and 4),
  label             text not null check (length(label) between 1 and 60),
  percent           numeric(5, 2) not null check (percent > 0 and percent <= 100),
  due_date          date,
  milestone         text check (length(milestone) <= 120),
  amount            numeric(14, 2),
  paid_at           date,
  paid_note         text check (length(paid_note) <= 300),
  paid_recorded_by  uuid references public.profiles (id),
  paid_recorded_at  timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),

  unique (project_id, seq)
);

comment on column public.payment_installments.amount is 'Nominal yang dibekukan saat konfirmasi final; null sebelum dikunci (hitung dari persen × total RAB).';
comment on column public.payment_installments.paid_at is 'Tanggal pembayaran diterima (dicatat admin). null = belum dibayar.';

create trigger payment_installments_set_updated_at
  before update on public.payment_installments
  for each row execute function private.set_updated_at();

create trigger payment_plans_audit after insert or update or delete on public.payment_plans
  for each row execute function private.audit_row();
create trigger payment_installments_audit after insert or update or delete on public.payment_installments
  for each row execute function private.audit_row();

-- -----------------------------------------------------------------------------
-- Validasi baris pembayaran (dipakai saat simpan dan saat mengunci)
-- p_items: [{label, percent, due_date, milestone}] berurutan
-- -----------------------------------------------------------------------------
create or replace function private.validate_installments(p_scheme public.payment_scheme, p_items jsonb)
returns void
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_count int := jsonb_array_length(coalesce(p_items, '[]'));
  v_total numeric := 0;
  v_item  jsonb;
  v_pct   numeric;
  v_prev  date;
  v_due   date;
  i       int := 0;
begin
  if p_scheme is null then
    raise exception 'Pilih skema pembayaran' using errcode = '23514';
  end if;

  case p_scheme
    when 'full' then
      if v_count <> 1 then raise exception 'Skema Lunas harus tepat 1 pembayaran' using errcode = '23514'; end if;
    when 'dp' then
      if v_count <> 2 then raise exception 'Skema DP harus tepat 2 pembayaran (DP dan pelunasan)' using errcode = '23514'; end if;
    else
      if v_count not between 2 and 4 then
        raise exception 'Skema % harus 2 sampai 4 pembayaran', case p_scheme when 'termin' then 'Termin' else 'Progress' end
          using errcode = '23514';
      end if;
  end case;

  for v_item in select * from jsonb_array_elements(p_items) loop
    i := i + 1;
    begin
      v_pct := (v_item ->> 'percent')::numeric;
    exception when others then
      raise exception 'Persen pembayaran ke-% tidak valid', i using errcode = '23514';
    end;
    if v_pct is null or v_pct <= 0 or v_pct > 100 or v_pct <> round(v_pct, 2) then
      raise exception 'Persen pembayaran ke-% harus lebih dari 0 dan paling banyak 2 angka di belakang koma', i using errcode = '23514';
    end if;
    if i = 1 and p_scheme <> 'full' and v_pct < 30 then
      raise exception 'Pembayaran pertama minimal 30%%' using errcode = '23514';
    end if;
    v_total := v_total + v_pct;

    if p_scheme = 'termin' then
      begin
        v_due := (v_item ->> 'due_date')::date;
      exception when others then
        raise exception 'Tanggal jatuh tempo termin ke-% tidak valid', i using errcode = '23514';
      end;
      if v_due is null then
        raise exception 'Termin ke-% wajib punya tanggal jatuh tempo', i using errcode = '23514';
      end if;
      if v_prev is not null and v_due <= v_prev then
        raise exception 'Tanggal jatuh tempo termin harus berurutan' using errcode = '23514';
      end if;
      v_prev := v_due;
    end if;

    if p_scheme = 'progress' and nullif(trim(v_item ->> 'milestone'), '') is null then
      raise exception 'Tahap pekerjaan untuk pembayaran ke-% wajib diisi', i using errcode = '23514';
    end if;
  end loop;

  if v_total <> 100 then
    raise exception 'Total persen harus 100%%, sekarang %', v_total || '%' using errcode = '23514';
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Kunci skema: bekukan total & nominal tiap baris dari total RAB
-- -----------------------------------------------------------------------------
create or replace function private.lock_payment_plan(p_project_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan  public.payment_plans;
  v_total numeric;
  v_items jsonb;
  v_sum   numeric := 0;
  v_last  int;
begin
  select * into v_plan from public.payment_plans where project_id = p_project_id for update;
  if not found or v_plan.scheme is null then
    raise exception 'Skema pembayaran belum ditetapkan admin' using errcode = '23514';
  end if;
  if v_plan.locked_at is not null then
    return;
  end if;

  select grand_total_customer into v_total from public.rabs where project_id = p_project_id;
  if v_total is null then
    raise exception 'RAB belum dihitung' using errcode = '23514';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'label', label, 'percent', percent, 'due_date', due_date, 'milestone', milestone) order by seq), '[]')
  into v_items
  from public.payment_installments where project_id = p_project_id;
  perform private.validate_installments(v_plan.scheme, v_items);

  select max(seq) into v_last from public.payment_installments where project_id = p_project_id;

  update public.payment_installments
  set amount = round(v_total * percent / 100, 0)
  where project_id = p_project_id and seq < v_last;

  select coalesce(sum(amount), 0) into v_sum
  from public.payment_installments where project_id = p_project_id and seq < v_last;

  update public.payment_installments
  set amount = v_total - v_sum
  where project_id = p_project_id and seq = v_last;

  update public.payment_plans
  set total_amount = v_total, locked_at = now()
  where project_id = p_project_id;
end;
$$;

-- Konfirmasi final mewajibkan skema yang valid, lalu menguncinya
create or replace function private.projects_lock_payment_on_confirm()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'confirmed' and old.status is distinct from 'confirmed' then
    perform private.lock_payment_plan(new.id);
  end if;
  return new;
end;
$$;

create trigger projects_lock_payment_on_confirm
  before update of status on public.projects
  for each row execute function private.projects_lock_payment_on_confirm();

-- -----------------------------------------------------------------------------
-- RPC: klien meminta skema (Android)
-- -----------------------------------------------------------------------------
create or replace function public.request_payment_scheme(
  p_project_id uuid,
  p_scheme     public.payment_scheme,
  p_note       text default null
)
returns public.payment_plans
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_project public.projects;
  v_plan    public.payment_plans;
begin
  if p_scheme is null then
    raise exception 'Pilih skema pembayaran' using errcode = '23514';
  end if;

  select * into v_project from public.projects where id = p_project_id;
  if not found or v_project.customer_id is distinct from (select auth.uid()) then
    raise exception 'Project tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_project.status in ('confirmed', 'report_generated', 'completed', 'rejected') then
    raise exception 'Skema pembayaran tidak bisa diubah setelah pesanan dikonfirmasi' using errcode = '42501';
  end if;

  insert into public.payment_plans (project_id, requested_scheme, requested_note, requested_at)
  values (p_project_id, p_scheme, nullif(trim(p_note), ''), now())
  on conflict (project_id) do update
    set requested_scheme = excluded.requested_scheme,
        requested_note   = excluded.requested_note,
        requested_at     = excluded.requested_at
  returning * into v_plan;

  return v_plan;
end;
$$;

-- -----------------------------------------------------------------------------
-- RPC: admin menetapkan skema & baris pembayaran (mengganti semua baris)
-- p_installments: [{ "label": "DP", "percent": 30, "due_date": "2026-11-30", "milestone": "..." }]
-- -----------------------------------------------------------------------------
create or replace function public.save_payment_plan(
  p_project_id   uuid,
  p_scheme       public.payment_scheme,
  p_installments jsonb
)
returns public.payment_plans
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_project public.projects;
  v_plan    public.payment_plans;
  v_item    jsonb;
  v_label   text;
  i         int := 0;
begin
  if not public.is_staff() then
    raise exception 'Hanya admin yang bisa menetapkan skema pembayaran' using errcode = '42501';
  end if;

  select * into v_project from public.projects where id = p_project_id for update;
  if not found then
    raise exception 'Project tidak ditemukan' using errcode = 'P0002';
  end if;
  if v_project.status in ('draft', 'ready_to_submit', 'sent_to_admin', 'rejected') then
    raise exception 'Terima pesanan dulu sebelum menetapkan skema pembayaran' using errcode = '42501';
  end if;

  select * into v_plan from public.payment_plans where project_id = p_project_id;
  if found and v_plan.locked_at is not null then
    raise exception 'Skema pembayaran sudah dikunci saat konfirmasi final' using errcode = '42501';
  end if;

  perform private.validate_installments(p_scheme, p_installments);

  insert into public.payment_plans (project_id, scheme, updated_by)
  values (p_project_id, p_scheme, (select auth.uid()))
  on conflict (project_id) do update set scheme = excluded.scheme, updated_by = excluded.updated_by;

  delete from public.payment_installments where project_id = p_project_id;

  for v_item in select * from jsonb_array_elements(p_installments) loop
    i := i + 1;
    v_label := coalesce(nullif(trim(v_item ->> 'label'), ''), case p_scheme
      when 'full' then 'Pelunasan'
      when 'dp' then case i when 1 then 'DP' else 'Pelunasan' end
      when 'termin' then 'Termin ' || i
      else 'Tahap ' || i
    end);
    insert into public.payment_installments (project_id, seq, label, percent, due_date, milestone)
    values (
      p_project_id, i, v_label, (v_item ->> 'percent')::numeric,
      nullif(v_item ->> 'due_date', '')::date,
      nullif(trim(v_item ->> 'milestone'), '')
    );
  end loop;

  -- Pesanan lama yang sudah melewati konfirmasi final (sebelum fitur ini ada): langsung dikunci
  if v_project.status in ('confirmed', 'report_generated', 'completed') then
    perform private.lock_payment_plan(p_project_id);
  end if;

  select * into v_plan from public.payment_plans where project_id = p_project_id;
  return v_plan;
end;
$$;

-- -----------------------------------------------------------------------------
-- RPC: admin menandai / membatalkan tanda "sudah dibayar"
-- -----------------------------------------------------------------------------
create or replace function public.set_installment_paid(
  p_installment_id uuid,
  p_paid           boolean,
  p_paid_at        date default null,
  p_note           text default null
)
returns public.payment_installments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row     public.payment_installments;
  v_project public.projects;
  v_locked  timestamptz;
begin
  if not public.is_staff() then
    raise exception 'Hanya admin yang bisa mencatat pembayaran' using errcode = '42501';
  end if;

  select * into v_row from public.payment_installments where id = p_installment_id for update;
  if not found then
    raise exception 'Baris pembayaran tidak ditemukan' using errcode = 'P0002';
  end if;

  select locked_at into v_locked from public.payment_plans where project_id = v_row.project_id;
  if v_locked is null then
    raise exception 'Pembayaran baru bisa dicatat setelah konfirmasi final' using errcode = '42501';
  end if;

  if p_paid then
    if p_paid_at > (now() at time zone 'Asia/Jakarta')::date then
      raise exception 'Tanggal pembayaran tidak boleh di masa depan' using errcode = '23514';
    end if;
    update public.payment_installments
    set paid_at = coalesce(p_paid_at, (now() at time zone 'Asia/Jakarta')::date),
        paid_note = nullif(trim(p_note), ''),
        paid_recorded_by = (select auth.uid()),
        paid_recorded_at = now()
    where id = p_installment_id
    returning * into v_row;

    select * into v_project from public.projects where id = v_row.project_id;
    perform private.notify_user(v_project.customer_id, v_project.id, 'payment_recorded',
      'Pembayaran ' || v_row.label || ' sudah tercatat', v_project.code || ' — ' || v_project.title);
  else
    update public.payment_installments
    set paid_at = null, paid_note = null, paid_recorded_by = null, paid_recorded_at = null
    where id = p_installment_id
    returning * into v_row;
  end if;

  return v_row;
end;
$$;

revoke execute on function public.request_payment_scheme(uuid, public.payment_scheme, text) from public, anon;
revoke execute on function public.save_payment_plan(uuid, public.payment_scheme, jsonb) from public, anon;
revoke execute on function public.set_installment_paid(uuid, boolean, date, text) from public, anon;
grant execute on function public.request_payment_scheme(uuid, public.payment_scheme, text) to authenticated;
grant execute on function public.save_payment_plan(uuid, public.payment_scheme, jsonb) to authenticated;
grant execute on function public.set_installment_paid(uuid, boolean, date, text) to authenticated;

-- -----------------------------------------------------------------------------
-- Ringkasan per pesanan (kolom Pembayaran di daftar pesanan, Laporan)
-- total_amount: total terkunci, atau total RAB terbaru sebelum dikunci
-- (customer tidak bisa membaca rabs → null sebelum dikunci).
-- -----------------------------------------------------------------------------
create view public.order_payment_summary
with (security_invoker = true)
as
select
  p.id                                                    as project_id,
  pp.requested_scheme,
  pp.scheme,
  pp.locked_at,
  coalesce(pp.total_amount, r.grand_total_customer)       as total_amount,
  coalesce(i.installment_count, 0)                        as installment_count,
  coalesce(i.paid_count, 0)                               as paid_count,
  coalesce(i.paid_amount, 0)                              as paid_amount,
  case
    when pp.scheme is null then 'no_plan'
    when pp.locked_at is null then 'planned'
    when coalesce(i.paid_count, 0) = 0 then 'unpaid'
    when i.paid_count < i.installment_count then 'partial'
    else 'paid'
  end                                                     as payment_status,
  i.next_label,
  i.next_due_date
from public.projects p
left join public.payment_plans pp on pp.project_id = p.id
left join public.rabs r on r.project_id = p.id
left join lateral (
  select
    count(*)                                         as installment_count,
    count(*) filter (where x.paid_at is not null)    as paid_count,
    sum(x.amount) filter (where x.paid_at is not null) as paid_amount,
    (array_agg(x.label order by x.seq) filter (where x.paid_at is null))[1]    as next_label,
    (array_agg(x.due_date order by x.seq) filter (where x.paid_at is null))[1] as next_due_date
  from public.payment_installments x
  where x.project_id = p.id
) i on true;

comment on view public.order_payment_summary is
  'Status pembayaran per pesanan: no_plan / planned (belum dikunci) / unpaid / partial / paid. Kontrak: docs/contract-pembayaran.md';

revoke all on public.order_payment_summary from anon, authenticated;
grant select on public.order_payment_summary to authenticated;

-- -----------------------------------------------------------------------------
-- RLS: baca mengikuti project; semua tulis lewat RPC di atas
-- -----------------------------------------------------------------------------
alter table public.payment_plans        enable row level security;
alter table public.payment_installments enable row level security;

create policy "payment plans: baca"
  on public.payment_plans for select to authenticated
  using (public.can_read_project(project_id));

create policy "payment installments: baca"
  on public.payment_installments for select to authenticated
  using (public.can_read_project(project_id));

revoke insert, update, delete on public.payment_plans, public.payment_installments from anon, authenticated;
