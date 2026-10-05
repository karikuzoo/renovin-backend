-- =============================================================================
-- 001 — Fondasi: schema private, role user, tabel profiles, helper RLS
-- =============================================================================

-- Schema "private" tidak diekspos lewat API (PostgREST), jadi fungsi internal
-- di sini tidak bisa dipanggil langsung dari web/android.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Helper umum
-- -----------------------------------------------------------------------------
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Role & profiles
-- -----------------------------------------------------------------------------
create type public.user_role as enum ('customer', 'admin', 'super_admin');

create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text,
  full_name   text,
  phone       text,
  role        public.user_role not null default 'customer',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.profiles is 'Data user aplikasi. Kolom role menentukan hak akses (dibaca oleh RLS).';

create index profiles_role_idx on public.profiles (role);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function private.set_updated_at();

-- Profile dibuat otomatis saat user signup. Semua user baru = customer.
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, phone)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'phone'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- -----------------------------------------------------------------------------
-- Helper role untuk RLS
-- (security definer supaya tidak terkena RLS tabel profiles itu sendiri)
-- -----------------------------------------------------------------------------
create or replace function public.my_role()
returns public.user_role
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = (select auth.uid());
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role in ('admin', 'super_admin') from public.profiles where id = (select auth.uid())),
    false
  );
$$;

create or replace function public.is_super_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select role = 'super_admin' from public.profiles where id = (select auth.uid())),
    false
  );
$$;

-- -----------------------------------------------------------------------------
-- RLS profiles
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;

create policy "profiles: baca milik sendiri atau staff"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()) or (select public.is_staff()));

create policy "profiles: update milik sendiri"
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- User hanya boleh mengubah nama & nomor HP. Kolom role/email dikunci;
-- role diubah lewat fungsi set_user_role() oleh super admin.
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (full_name, phone) on public.profiles to authenticated;

-- -----------------------------------------------------------------------------
-- Super admin mengubah role user lain
-- -----------------------------------------------------------------------------
create or replace function public.set_user_role(p_user_id uuid, p_role public.user_role)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles;
begin
  if not public.is_super_admin() then
    raise exception 'Hanya super admin yang dapat mengubah role' using errcode = '42501';
  end if;

  if p_user_id = (select auth.uid()) then
    raise exception 'Tidak dapat mengubah role akun sendiri' using errcode = '42501';
  end if;

  update public.profiles set role = p_role where id = p_user_id
  returning * into v_profile;

  if not found then
    raise exception 'User tidak ditemukan' using errcode = 'P0002';
  end if;

  return v_profile;
end;
$$;

revoke execute on function public.set_user_role(uuid, public.user_role) from public, anon;
grant execute on function public.set_user_role(uuid, public.user_role) to authenticated;
