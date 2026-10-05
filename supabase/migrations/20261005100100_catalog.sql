-- =============================================================================
-- 002 — Katalog produk, harga internal, tarif jasa, pengaturan aplikasi
-- FSD: FS-05, FS-15, §7 (RAB)
-- =============================================================================

create type public.product_type as enum ('paint', 'furniture', 'material', 'other');
create type public.service_calc_type as enum ('per_m2', 'flat');

-- -----------------------------------------------------------------------------
-- Kategori
-- -----------------------------------------------------------------------------
create table public.product_categories (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text not null unique,
  type        public.product_type not null,
  sort_order  int not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger product_categories_set_updated_at
  before update on public.product_categories
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Produk (harga yang terlihat customer)
-- File gambar disimpan di ImageKit; di sini hanya file_id & URL-nya.
-- -----------------------------------------------------------------------------
create table public.products (
  id               uuid primary key default gen_random_uuid(),
  category_id      uuid not null references public.product_categories (id),
  type             public.product_type not null,
  sku              text not null unique,
  name             text not null,
  description      text,
  unit             text not null,                       -- contoh: m2, pcs, liter
  price_customer   numeric(14, 2) not null check (price_customer >= 0),

  -- khusus cat
  color_name       text,
  color_hex        text check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),

  -- khusus furnitur (cm), dipakai untuk auto-scale di preview
  width_cm         numeric(8, 2) check (width_cm > 0),
  depth_cm         numeric(8, 2) check (depth_cm > 0),
  height_cm        numeric(8, 2) check (height_cm > 0),

  -- gambar katalog (thumbnail) dan aset visual untuk compositing (PNG transparan)
  image_file_id    text,
  image_url        text,
  asset_file_id    text,
  asset_url        text,

  active           boolean not null default true,
  created_by       uuid references public.profiles (id) default auth.uid(),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  constraint products_paint_has_color check (type <> 'paint' or color_hex is not null)
);

comment on column public.products.price_customer is 'Harga katalog (U) untuk formula RAB customer.';
comment on column public.products.active is 'Produk nonaktif tidak ditawarkan lagi, tetapi tidak dihapus agar project lama tetap bisa ditelusuri.';

create index products_category_idx on public.products (category_id);
create index products_type_active_idx on public.products (type, active);

create trigger products_set_updated_at
  before update on public.products
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Harga internal — tabel terpisah karena RLS bekerja per baris, bukan per
-- kolom. Customer tidak boleh membaca tabel ini sama sekali.
-- -----------------------------------------------------------------------------
create table public.product_internal_prices (
  product_id      uuid primary key references public.products (id) on delete cascade,
  price_internal  numeric(14, 2) not null check (price_internal >= 0),
  updated_by      uuid references public.profiles (id) default auth.uid(),
  updated_at      timestamptz not null default now()
);

comment on table public.product_internal_prices is 'Harga katalog (I) untuk formula RAB internal. Hanya staff.';

create trigger product_internal_prices_set_updated_at
  before update on public.product_internal_prices
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Master tarif jasa
-- -----------------------------------------------------------------------------
create table public.service_rates (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  name        text not null,
  calc_type   public.service_calc_type not null,
  applies_to  public.product_type,                     -- per_m2: luas dari item jenis ini
  rate        numeric(14, 2) not null check (rate >= 0),
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),

  constraint service_rates_per_m2_needs_type check (calc_type <> 'per_m2' or applies_to is not null)
);

create trigger service_rates_set_updated_at
  before update on public.service_rates
  for each row execute function private.set_updated_at();

-- -----------------------------------------------------------------------------
-- Pengaturan aplikasi (key-value), contoh: key = 'tax' → {"tax_percent": 11}
-- -----------------------------------------------------------------------------
create table public.app_settings (
  key         text primary key,
  value       jsonb not null,
  description text,
  updated_by  uuid references public.profiles (id) default auth.uid(),
  updated_at  timestamptz not null default now()
);

create trigger app_settings_set_updated_at
  before update on public.app_settings
  for each row execute function private.set_updated_at();

insert into public.app_settings (key, value, description, updated_by)
values ('tax', '{"tax_percent": 11}', 'Persentase pajak untuk RAB customer', null);

-- -----------------------------------------------------------------------------
-- RLS
-- -----------------------------------------------------------------------------
alter table public.product_categories      enable row level security;
alter table public.products                enable row level security;
alter table public.product_internal_prices enable row level security;
alter table public.service_rates           enable row level security;
alter table public.app_settings            enable row level security;

-- Kategori
create policy "categories: baca (user login)"
  on public.product_categories for select to authenticated
  using (active or (select public.is_staff()));
create policy "categories: staff insert"
  on public.product_categories for insert to authenticated
  with check ((select public.is_staff()));
create policy "categories: staff update"
  on public.product_categories for update to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

-- Produk: customer hanya melihat produk aktif. Tidak ada policy delete —
-- produk dinonaktifkan, bukan dihapus.
create policy "products: baca (user login)"
  on public.products for select to authenticated
  using (active or (select public.is_staff()));
create policy "products: staff insert"
  on public.products for insert to authenticated
  with check ((select public.is_staff()));
create policy "products: staff update"
  on public.products for update to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

-- Harga internal: staff saja
create policy "internal prices: staff baca"
  on public.product_internal_prices for select to authenticated
  using ((select public.is_staff()));
create policy "internal prices: staff insert"
  on public.product_internal_prices for insert to authenticated
  with check ((select public.is_staff()));
create policy "internal prices: staff update"
  on public.product_internal_prices for update to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

-- Tarif jasa
create policy "service rates: baca (user login)"
  on public.service_rates for select to authenticated
  using (active or (select public.is_staff()));
create policy "service rates: staff insert"
  on public.service_rates for insert to authenticated
  with check ((select public.is_staff()));
create policy "service rates: staff update"
  on public.service_rates for update to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));

-- Pengaturan
create policy "settings: baca (user login)"
  on public.app_settings for select to authenticated
  using (true);
create policy "settings: staff update"
  on public.app_settings for update to authenticated
  using ((select public.is_staff())) with check ((select public.is_staff()));
