-- =============================================================================
-- 012 — Pindah admin penanggung jawab pesanan
-- Dipakai web admin: detail pesanan & halaman Tim.
-- Kontrak untuk FE: docs/contract-assign-project.md
--
-- Sebelumnya assigned_admin_id hanya terisi sekali (saat pesanan diterima lewat
-- change_project_status) dan tidak bisa diganti, karena kolomnya tidak di-grant.
--
-- ASUMSI (docs/decisions.md Q12):
--   - super_admin boleh memindahkan pesanan siapa pun.
--   - admin hanya boleh menyerahkan pesanan yang sedang ia tangani sendiri.
--   - Tidak berlaku untuk pesanan draft/ready_to_submit (belum dikirim) dan
--     completed/rejected (sudah selesai).
-- =============================================================================

create or replace function public.assign_project(p_project_id uuid, p_admin_id uuid)
returns public.projects
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid         uuid := (select auth.uid());
  v_role        public.user_role;
  v_target_role public.user_role;
  v_target_name text;
  v_project     public.projects;
  v_old_admin   uuid;
begin
  if v_uid is null then
    raise exception 'Harus login' using errcode = '28000';
  end if;

  select role into v_role from public.profiles where id = v_uid;
  if v_role is null or v_role not in ('admin', 'super_admin') then
    raise exception 'Hanya admin atau super admin yang boleh memindahkan penanggung jawab'
      using errcode = '42501';
  end if;

  select * into v_project from public.projects where id = p_project_id for update;
  if not found then
    raise exception 'Project tidak ditemukan' using errcode = 'P0002';
  end if;

  if v_project.status in ('draft', 'ready_to_submit') then
    raise exception 'Pesanan belum dikirim klien' using errcode = '23514';
  end if;
  if v_project.status in ('completed', 'rejected') then
    raise exception 'Penanggung jawab tidak bisa diubah untuk pesanan yang sudah selesai atau ditolak'
      using errcode = '23514';
  end if;

  if v_role = 'admin' and v_project.assigned_admin_id is distinct from v_uid then
    raise exception 'Admin hanya bisa menyerahkan pesanan yang sedang ia tangani'
      using errcode = '42501';
  end if;

  select role, full_name into v_target_role, v_target_name from public.profiles where id = p_admin_id;
  if v_target_role is null or v_target_role not in ('admin', 'super_admin') then
    raise exception 'Penanggung jawab baru harus akun admin atau super admin' using errcode = '23514';
  end if;

  v_old_admin := v_project.assigned_admin_id;
  if v_old_admin is not distinct from p_admin_id then
    return v_project;  -- tidak ada perubahan
  end if;

  update public.projects
  set assigned_admin_id = p_admin_id
  where id = p_project_id
  returning * into v_project;

  -- Tabel projects tidak punya trigger audit; catat perpindahan secara eksplisit.
  insert into public.audit_logs (table_name, record_id, action, old_data, new_data, actor_id)
  values (
    'projects', p_project_id::text, 'UPDATE',
    jsonb_build_object('assigned_admin_id', v_old_admin),
    jsonb_build_object('assigned_admin_id', p_admin_id),
    v_uid
  );

  if p_admin_id <> v_uid then
    perform private.notify_user(
      p_admin_id, p_project_id, 'project_assigned',
      'Pesanan dialihkan ke Anda',
      v_project.code || ' — ' || v_project.title
    );
  end if;

  return v_project;
end;
$$;

comment on function public.assign_project(uuid, uuid) is
  'Pindah admin penanggung jawab pesanan. Kontrak: docs/contract-assign-project.md';

revoke execute on function public.assign_project(uuid, uuid) from public, anon;
grant execute on function public.assign_project(uuid, uuid) to authenticated;
