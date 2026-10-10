-- =============================================================================
-- 008 — Supabase Storage (menggantikan ImageKit)
--
-- Alasan: domain ik.imagekit.io diblokir "Internet Baik" di jaringan Telkom
-- Group (Telkomsel, by.U, IndiHome), sehingga gambar tidak bisa ditampilkan.
-- Lihat docs/decisions.md (A2).
--
-- Bucket & konvensi path:
--   catalog       PUBLIK   products/<product_id>/<file>      gambar & aset PNG produk
--   room-photos   PRIVAT   <project_id>/<file>               foto ruangan, hasil desain
--   reports       PRIVAT   <project_id>/<file>               PDF laporan final
--
-- Kolom *_file_id menyimpan PATH objek di bucket.
-- Kolom *_url menyimpan URL publik (bucket catalog) atau PATH objek (bucket
-- privat; tampilkan dengan signed URL: storage.from(bucket).createSignedUrl).
-- =============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('catalog',     'catalog',     true,  5242880,  array['image/jpeg', 'image/png', 'image/webp']),
  ('room-photos', 'room-photos', false, 10485760, array['image/jpeg', 'image/png', 'image/webp']),
  ('reports',     'reports',     false, 10485760, array['application/pdf'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- -----------------------------------------------------------------------------
-- Helper: ambil project_id dari folder pertama path objek.
-- Path yang folder pertamanya bukan UUID -> null (dan otomatis ditolak policy).
-- -----------------------------------------------------------------------------
create or replace function public.storage_project_id(p_name text)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
begin
  return (storage.foldername(p_name))[1]::uuid;
exception
  when invalid_text_representation then
    return null;
end;
$$;

-- -----------------------------------------------------------------------------
-- catalog (publik): semua orang bisa melihat lewat URL publik,
-- hanya staff yang boleh upload / ganti / hapus.
-- -----------------------------------------------------------------------------
create policy "catalog: baca (user login)"
  on storage.objects for select to authenticated
  using (bucket_id = 'catalog');

create policy "catalog: staff upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'catalog' and (select public.is_staff()));

create policy "catalog: staff ganti"
  on storage.objects for update to authenticated
  using (bucket_id = 'catalog' and (select public.is_staff()))
  with check (bucket_id = 'catalog' and (select public.is_staff()));

create policy "catalog: staff hapus"
  on storage.objects for delete to authenticated
  using (bucket_id = 'catalog' and (select public.is_staff()));

-- -----------------------------------------------------------------------------
-- room-photos (privat): mengikuti hak akses project.
--   baca  : pemilik project atau staff
--   tulis : customer selama draft / ready_to_submit, staff selama diproses
-- -----------------------------------------------------------------------------
create policy "room-photos: baca"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'room-photos'
    and public.can_read_project(public.storage_project_id(name))
  );

create policy "room-photos: upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'room-photos'
    and (
      public.customer_can_edit_project(public.storage_project_id(name))
      or public.staff_can_edit_project(public.storage_project_id(name))
    )
  );

create policy "room-photos: ganti"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'room-photos'
    and (
      public.customer_can_edit_project(public.storage_project_id(name))
      or public.staff_can_edit_project(public.storage_project_id(name))
    )
  )
  with check (
    bucket_id = 'room-photos'
    and (
      public.customer_can_edit_project(public.storage_project_id(name))
      or public.staff_can_edit_project(public.storage_project_id(name))
    )
  );

create policy "room-photos: hapus"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'room-photos'
    and (
      public.customer_can_edit_project(public.storage_project_id(name))
      or public.staff_can_edit_project(public.storage_project_id(name))
    )
  );

-- -----------------------------------------------------------------------------
-- reports (privat): customer membaca laporan project-nya sendiri,
-- staff membuat / memperbarui. Tidak ada hapus: laporan final adalah arsip.
-- -----------------------------------------------------------------------------
create policy "reports: baca"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'reports'
    and public.can_read_project(public.storage_project_id(name))
  );

create policy "reports: staff upload"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'reports'
    and (select public.is_staff())
    and public.storage_project_id(name) is not null
  );

create policy "reports: staff ganti"
  on storage.objects for update to authenticated
  using (bucket_id = 'reports' and (select public.is_staff()))
  with check (
    bucket_id = 'reports'
    and (select public.is_staff())
    and public.storage_project_id(name) is not null
  );
