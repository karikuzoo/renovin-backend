-- =============================================================================
-- 015 — Katalog: status terbit, merek, spesifikasi, ketersediaan
-- Dipakai halaman Katalog (renovin-web).
-- Kontrak untuk FE: docs/contract-katalog.md
--
-- products.status (baru) menggantikan products.active sebagai sumber kebenaran:
--   draft      belum tampil di aplikasi customer (sedang disiapkan admin)
--   published  tampil di aplikasi customer ("Terbit")
--   archived   tidak ditawarkan lagi; tetap ada agar project lama bisa ditelusuri
--
-- products.active TETAP ADA dan selalu = (status = 'published'), diisi trigger.
-- Jadi RLS, calculate_rab, dan aplikasi Android yang membaca `active` tidak
-- perlu berubah. Kalau hanya `active` yang diubah (mis. seed/skrip lama),
-- status ikut: true -> published, false -> archived.
--
-- Keputusan: docs/decisions.md Q15.
-- =============================================================================

create type public.catalog_status as enum ('draft', 'published', 'archived');
create type public.product_availability as enum ('available', 'indent', 'out_of_stock');

alter table public.products
  add column status            public.catalog_status,
  add column brand             text check (length(brand) <= 80),
  add column spec              text check (length(spec) <= 120),
  add column availability      public.product_availability not null default 'available',
  add column availability_note text check (length(availability_note) <= 80);

update public.products set status = case when active then 'published' else 'archived' end::public.catalog_status;

alter table public.products alter column status set not null;

comment on column public.products.status is 'draft / published (tampil di aplikasi customer) / archived. Sumber kebenaran; `active` diturunkan dari kolom ini.';
comment on column public.products.active is 'Turunan dari status (= status = published), diisi trigger. Jangan diubah langsung; ubah status.';
comment on column public.products.brand is 'Merek, contoh: Jayaboard, Roman.';
comment on column public.products.spec is 'Spesifikasi singkat satu baris, contoh: 9 mm · 120 × 240 cm.';
comment on column public.products.availability is 'Ketersediaan stok: available (tersedia), indent (pesan dulu), out_of_stock (habis).';
comment on column public.products.availability_note is 'Catatan ketersediaan, contoh: 3–5 hari. Dikosongkan otomatis bila available.';

create index products_status_idx on public.products (status);

-- -----------------------------------------------------------------------------
-- Sinkron status <-> active, rapikan teks, cek tipe sama dengan kategori
-- -----------------------------------------------------------------------------
create or replace function private.products_normalize()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_category_type public.product_type;
begin
  if tg_op = 'INSERT' then
    -- status kosong (insert lama yang hanya mengisi active) -> turunkan dari active
    new.status := coalesce(new.status, case when new.active then 'published' else 'archived' end::public.catalog_status);
  elsif new.status is not distinct from old.status and new.active is distinct from old.active then
    new.status := case when new.active then 'published' else 'archived' end::public.catalog_status;
  end if;
  new.active := (new.status = 'published');

  new.sku               := upper(trim(new.sku));
  new.name              := trim(new.name);
  new.brand             := nullif(trim(new.brand), '');
  new.spec              := nullif(trim(new.spec), '');
  new.description       := nullif(trim(new.description), '');
  new.availability_note := case when new.availability = 'available' then null
                                else nullif(trim(new.availability_note), '') end;

  if new.sku = '' then
    raise exception 'Kode bahan wajib diisi' using errcode = '23514';
  end if;
  if new.name = '' then
    raise exception 'Nama bahan wajib diisi' using errcode = '23514';
  end if;

  select c.type into v_category_type from public.product_categories c where c.id = new.category_id;
  if v_category_type is not null and v_category_type <> new.type then
    raise exception 'Tipe produk (%) tidak sama dengan tipe kategori (%)', new.type, v_category_type
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger products_normalize
  before insert or update on public.products
  for each row execute function private.products_normalize();
