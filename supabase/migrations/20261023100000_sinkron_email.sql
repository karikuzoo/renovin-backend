-- =============================================================================
-- 014 — Sinkron email login (auth.users) ke public.profiles
-- Kontrak untuk FE: docs/contract-ganti-email.md
--
-- profiles.email hanya diisi sekali saat akun dibuat (private.handle_new_user).
-- Kalau user mengganti email lewat supabase.auth.updateUser({ email }), Supabase
-- baru mengubah auth.users.email setelah link konfirmasi diklik. Trigger ini
-- menyalin email baru itu ke profiles, supaya web & aplikasi menampilkan email
-- yang sama dengan email login.
-- =============================================================================

create or replace function private.handle_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
  set email = new.email
  where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function private.handle_user_email_change();

-- Perbaikan satu kali: samakan profil yang emailnya sudah telanjur berbeda
update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id
  and p.email is distinct from u.email;
