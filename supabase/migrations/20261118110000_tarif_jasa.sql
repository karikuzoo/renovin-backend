-- =============================================================================
-- 017 — Tarif jasa: dikelola super admin
-- Dipakai tab "Harga & pajak" di halaman Pengaturan (renovin-web).
-- Kontrak untuk FE: docs/contract-tarif-jasa.md
--
-- service_rates (migration 002) dipakai calculate_rab untuk baris jasa:
--   per_m2: luas dari item dengan tipe produk applies_to × tarif
--   flat  : 1 paket × tarif
-- Sama seperti pajak (Q13), tarif memengaruhi semua RAB yang dihitung setelah
-- perubahan, jadi hanya super admin yang boleh menambah/mengubah (Q17).
-- Tarif tidak dihapus; dinonaktifkan (active = false) supaya RAB lama tetap terlacak.
-- =============================================================================

drop policy "service rates: staff insert" on public.service_rates;
drop policy "service rates: staff update" on public.service_rates;

create policy "service rates: super admin insert"
  on public.service_rates for insert to authenticated
  with check ((select public.is_super_admin()));

create policy "service rates: super admin update"
  on public.service_rates for update to authenticated
  using ((select public.is_super_admin()))
  with check ((select public.is_super_admin()));

-- Rapikan isian dari web
create or replace function private.service_rates_normalize()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.code := upper(trim(new.code));
  new.name := trim(new.name);
  if new.code = '' then
    raise exception 'Kode tarif wajib diisi' using errcode = '23514';
  end if;
  if new.name = '' then
    raise exception 'Nama jasa wajib diisi' using errcode = '23514';
  end if;
  -- tarif flat tidak bergantung tipe produk
  if new.calc_type = 'flat' then
    new.applies_to := null;
  end if;
  return new;
end;
$$;

create trigger service_rates_normalize
  before insert or update on public.service_rates
  for each row execute function private.service_rates_normalize();
