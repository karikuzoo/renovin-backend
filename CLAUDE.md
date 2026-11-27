# renovin-backend: Supabase untuk Renovin

Konfigurasi **Supabase** untuk Renovin (studio desain interior): migration database, RLS, seed, dan edge functions. **Tidak ada server API.** Web admin (`renovin-web`, Next.js) dan aplikasi customer (`renovin-android`) mengakses Supabase langsung, jadi **RLS adalah satu-satunya pengaman**.

Bahasa: komentar SQL, dokumen, pesan error untuk pengguna, dan pesan commit memakai **bahasa Indonesia**.

Baca dulu: `README.md` (alur kerja, env), `docs/erd.md` (tabel, hak akses, bucket, RPC), `docs/decisions.md` (keputusan Q1–Q17), dan `docs/contract-<fitur>.md` untuk fitur yang disentuh.

## Lingkungan

- Project dev: **`renovin-dev`** (ref `yblaopjkopdrrnwrxgqt`, Singapura). `renovin-prod` belum dibuat.
- Secret ada di Bitwarden (organisasi "Renovin", koleksi "Renovin - shared"). `service_role` / secret key **tidak pernah** dipakai di web atau Android.
- Branch utama: **`development`**. Alur: branch `feature/…` / `fix/…` / `docs/…` → PR ke `development` → merge → `npm run push:dev`.

```bash
npm run migration:new -- <nama>   # file baru di supabase/migrations
npx supabase db push --dry-run    # cek sebelum push
npm run push:dev                  # terapkan ke renovin-dev
npm run types                     # generate types/database.types.ts (salin ke renovin-web)
npm run functions:deploy          # deploy edge functions
```

Tidak ada Docker di laptop tim, jadi tidak bisa `supabase start` lokal. **CI GitHub** (`.github/workflows/ci.yml`) menjalankan semua migration + `seed.sql` dari nol, `supabase db lint`, dan `deno check` edge functions di setiap PR.

## Aturan migration

1. Semua perubahan database lewat migration. **Migration yang sudah di-push tidak diedit**; perbaikan = migration baru.
2. Kepala file: `-- 0NN — <judul>` (nomor urut berikutnya), lalu ringkasan, kontrak FE terkait, dan nomor keputusan (Qn) kalau ada.
3. **Backward compatible**: tambah kolom/tabel boleh; hapus atau ganti nama kolom menunggu Android lama tidak dipakai. Jangan ubah kolom view `admin_orders` yang sudah dipakai web.
4. **RLS aktif di setiap tabel baru**, policy per operasi dan per role. Helper: `public.is_staff()`, `public.is_super_admin()`, `public.can_read_project(id)`, `public.my_role()`.
5. Fungsi: `security definer` + `set search_path = ''` + nama objek lengkap (`public.x`). Helper internal di schema **`private`**. RPC untuk FE di `public`, `revoke … from public, anon` lalu `grant … to authenticated`.
6. Penulisan yang punya aturan bisnis lewat **RPC** (contoh `save_payment_plan`, `assign_project`, `change_project_status`), tabelnya hanya `select` untuk FE (`revoke insert, update, delete`).
7. Error untuk pengguna: `raise exception '<pesan bahasa Indonesia>' using errcode = …`. Kode yang dipakai: `23514` aturan dilanggar, `42501` tidak berhak / status tidak mengizinkan, `P0002` tidak ditemukan, `28000` belum login. FE menampilkan `error.message` apa adanya.
8. Tabel penting dipasangi audit: `create trigger <t>_audit after insert or update or delete … execute function private.audit_row()`.
9. Notifikasi dalam aplikasi: `private.notify_user(user, project, type, title, body)` / `private.notify_role(role, …)`. Tipe baru → tambahkan ke `docs/contract-notifikasi.md`.
10. Status pesanan **hanya** berubah lewat `public.change_project_status` (tabel `project_status_transitions` mengatur siapa boleh apa).
11. View untuk web: `with (security_invoker = true)` + filter `(select public.is_staff())` kalau khusus staff.

## Setiap fitur baru / perubahan kontrak

- Tulis atau perbarui **`docs/contract-<fitur>.md`** (format: Data → Siapa boleh apa → Contoh pemanggilan TS → Error → Belum tersedia), dan tambahkan ke daftar di `README.md`.
- Keputusan bisnis baru → baris baru di **`docs/decisions.md`** (Qn berikutnya).
- RPC / edge function baru → `docs/erd.md`.
- Perubahan yang dipakai customer → kabari tim Android (lihat kontraknya).
- Data contoh di **`supabase/seed.sql`** (hanya untuk lokal/dev, CI menjalankannya dari nol, jadi seed harus tetap lolos aturan migration terbaru). Data tambahan untuk dev yang sudah berjalan memakai skrip terpisah di luar repo, tidak di-commit.

## Menguji

- **Sebelum PR:** pastikan SQL lolos dijalankan dari nol (CI). Kalau perlu uji cepat di dev **tanpa mengubah data**, pakai blok rollback:
  ```sql
  do $$ begin
    perform set_config('request.jwt.claims', json_build_object('sub', '<uuid user>', 'role', 'authenticated')::text, true);
    set local role authenticated;
    -- ... uji ...
    raise exception 'HASIL: ...';   -- membatalkan semua perubahan
  end $$;
  ```
  lalu `npx supabase db query --linked -f file.sql`.
- Edge functions: `deno check supabase/functions/<nama>/index.ts`.
- Numeric dari PostgREST datang sebagai **number** JSON.

## Struktur

```
supabase/
  migrations/       001 roles/profiles · 002 katalog · 003 projects · 004 RAB · 005 workflow & notifikasi
                    006 audit · 007 chat · 008 storage · 009+ fitur web admin (lihat kepala tiap file)
  functions/
    request-password-reset/   lupa password khusus staff (verify_jwt = false, jawaban selalu sama)
    generate-report/          laporan PDF RAB dari snapshot final (pdf-lib) + skema pembayaran
  templates/        template email Supabase Auth
  seed.sql          data contoh (akun uji, katalog, 15 pesanan di semua status)
docs/               erd, decisions, setup-guide, lupa-password, contract-*.md
types/database.types.ts   hasil `npm run types`
```

Storage: bucket `catalog` (publik), `room-photos`, `reports` (privat, path diawali `<project_id>/`), `branding` (logo studio). Kolom `*_file_id` = path objek; untuk bucket privat tampilkan lewat signed URL.

## Keputusan penting (detail di `docs/decisions.md`)

- Q11 harga produk wajib · Q12 admin hanya menyerahkan pesanan sendiri · Q13 pajak hanya super admin · Q14 akun staff dibuat tim IT, customer daftar sendiri · Q15 katalog Draft/Terbit/Arsip · **Q16 pembayaran = pencatatan, bukan transaksi** (pertama ≥ 30%, maks. 4 kali, wajib sebelum konfirmasi final) · Q17 tarif jasa hanya super admin.
- Masih ditahan: admin membuat pesanan (`admin_create_order`), status "Perlu info", bukti transfer, tahap produksi, field pemesanan tambahan dari Android, revisi RAB setelah konfirmasi (Q10).
