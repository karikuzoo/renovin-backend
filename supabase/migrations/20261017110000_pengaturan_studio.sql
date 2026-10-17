-- =============================================================================
-- 013 — Pengaturan studio (profil studio, lokal, logo)
-- Dipakai halaman Pengaturan (renovin-web).
-- Kontrak untuk FE: docs/contract-pengaturan-studio.md
--
-- Kunci app_settings yang dipakai:
--   tax             {"tax_percent": 11}                      (sudah ada, migration 002)
--   studio_profile  {"name","email","phone","website","address","logo_url"}
--   locale          {"timezone","currency","language"}
--
-- Kunci baru hanya dibuat lewat migration (tidak ada policy INSERT/DELETE untuk user).
--
-- ASUMSI (docs/decisions.md Q13):
--   - studio_profile & locale: boleh diubah admin dan super admin.
--   - tax: hanya super admin, karena memengaruhi semua RAB baru.
-- =============================================================================

insert into public.app_settings (key, value, description, updated_by) values
  ('studio_profile',
   '{"name": "Renovin. Studio Interior", "email": null, "phone": null, "website": null, "address": null, "logo_url": null}',
   'Profil studio: nama, kontak, alamat, logo (tampil di web admin & laporan)', null),
  ('locale',
   '{"timezone": "Asia/Jakarta", "currency": "IDR", "language": "id"}',
   'Zona waktu, mata uang, dan bahasa tampilan', null)
on conflict (key) do nothing;

-- -----------------------------------------------------------------------------
-- Validasi isi pengaturan supaya web tidak menyimpan bentuk yang salah
-- -----------------------------------------------------------------------------
create or replace function private.app_settings_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_key   text;
  v_extra text[];
begin
  if jsonb_typeof(new.value) <> 'object' then
    raise exception 'Pengaturan % harus berupa objek JSON', new.key using errcode = '23514';
  end if;

  case new.key
    when 'tax' then
      if coalesce(jsonb_typeof(new.value -> 'tax_percent'), '') <> 'number'
         or (new.value ->> 'tax_percent')::numeric not between 0 and 100 then
        raise exception 'Pajak harus angka 0–100' using errcode = '23514';
      end if;
      v_extra := array(select jsonb_object_keys(new.value) except select 'tax_percent');

    when 'studio_profile' then
      v_extra := array(
        select jsonb_object_keys(new.value)
        except select unnest(array['name', 'email', 'phone', 'website', 'address', 'logo_url'])
      );
      foreach v_key in array array['name', 'email', 'phone', 'website', 'address', 'logo_url'] loop
        if new.value ? v_key and jsonb_typeof(new.value -> v_key) not in ('string', 'null') then
          raise exception 'Kolom % pada profil studio harus teks', v_key using errcode = '23514';
        end if;
      end loop;
      if nullif(trim(new.value ->> 'name'), '') is null then
        raise exception 'Nama studio wajib diisi' using errcode = '23514';
      end if;
      if nullif(new.value ->> 'email', '') is not null
         and (new.value ->> 'email') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
        raise exception 'Format email studio tidak valid' using errcode = '23514';
      end if;

    when 'locale' then
      v_extra := array(
        select jsonb_object_keys(new.value)
        except select unnest(array['timezone', 'currency', 'language'])
      );
      foreach v_key in array array['timezone', 'currency', 'language'] loop
        if coalesce(jsonb_typeof(new.value -> v_key), '') <> 'string' or trim(new.value ->> v_key) = '' then
          raise exception 'Kolom % pada pengaturan lokal wajib diisi', v_key using errcode = '23514';
        end if;
      end loop;

    else
      v_extra := '{}';
  end case;

  if cardinality(v_extra) > 0 then
    raise exception 'Kolom tidak dikenal pada pengaturan %: %', new.key, array_to_string(v_extra, ', ')
      using errcode = '23514';
  end if;

  new.updated_by := coalesce((select auth.uid()), new.updated_by);
  return new;
end;
$$;

create trigger app_settings_validate
  before insert or update on public.app_settings
  for each row execute function private.app_settings_validate();

-- -----------------------------------------------------------------------------
-- Hak ubah: profil & lokal untuk staff, pajak hanya super admin
-- -----------------------------------------------------------------------------
drop policy "settings: staff update" on public.app_settings;

create policy "settings: staff update profil & lokal"
  on public.app_settings for update to authenticated
  using ((select public.is_staff()) and key in ('studio_profile', 'locale'))
  with check ((select public.is_staff()) and key in ('studio_profile', 'locale'));

create policy "settings: super admin update"
  on public.app_settings for update to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));

-- Hanya kolom value yang boleh diubah dari web (key tetap, updated_* diisi trigger)
revoke insert, update, delete on public.app_settings from anon, authenticated;
grant update (value) on public.app_settings to authenticated;

-- -----------------------------------------------------------------------------
-- Bucket branding (publik): logo studio. SVG diizinkan untuk logo.
-- Path: studio/<file>
-- -----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('branding', 'branding', true, 2097152, array['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

create policy "branding: baca (user login)"
  on storage.objects for select to authenticated
  using (bucket_id = 'branding');

create policy "branding: staff upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'branding' and (select public.is_staff()) and (storage.foldername(name))[1] = 'studio');

create policy "branding: staff ganti"
  on storage.objects for update to authenticated
  using (bucket_id = 'branding' and (select public.is_staff()))
  with check (bucket_id = 'branding' and (select public.is_staff()) and (storage.foldername(name))[1] = 'studio');

create policy "branding: staff hapus"
  on storage.objects for delete to authenticated
  using (bucket_id = 'branding' and (select public.is_staff()));
