# renovin-backend

Konfigurasi Supabase untuk Renovin: migration database, RLS, seed, dan edge functions. Repo ini **tidak berisi server**. Web admin (`renovin-web`) dan aplikasi Android (`renovin-android`) mengakses Supabase langsung, dan RLS di database yang menentukan siapa boleh mengakses data apa.

File (foto, aset katalog, PDF) disimpan di **Supabase Storage** (bucket `catalog`, `room-photos`, `reports`), dengan aturan akses yang sama seperti data (RLS). ImageKit tidak dipakai lagi karena domainnya diblokir di jaringan Telkom Group; lihat [docs/decisions.md](docs/decisions.md) A2.

- Panduan setup proyek (backend + web, pembagian kerja, alur fitur): [docs/setup-guide.md](docs/setup-guide.md)
- Struktur tabel & hak akses: [docs/erd.md](docs/erd.md)
- Asumsi yang masih menunggu konfirmasi client: [docs/decisions.md](docs/decisions.md)
- Lupa password admin (setup Gmail SMTP + kontrak FE): [docs/lupa-password.md](docs/lupa-password.md)
- Kontrak FE web admin (satu file per fitur):
  - Daftar pesanan, view `admin_orders`: [docs/contract-admin-orders.md](docs/contract-admin-orders.md)
  - Ringkasan dashboard, fungsi `dashboard_summary`: [docs/contract-dashboard-summary.md](docs/contract-dashboard-summary.md)
  - Daftar klien, view `admin_clients`: [docs/contract-admin-clients.md](docs/contract-admin-clients.md)
  - Pindah penanggung jawab pesanan, fungsi `assign_project`: [docs/contract-assign-project.md](docs/contract-assign-project.md)
  - Pengaturan studio (profil, lokal, pajak, logo): [docs/contract-pengaturan-studio.md](docs/contract-pengaturan-studio.md)
  - Ganti email login (staff lewat tim IT, customer dari aplikasi, sinkron ke `profiles`): [docs/contract-ganti-email.md](docs/contract-ganti-email.md)
  - Persetujuan RAB & konfirmasi final (super admin): [docs/contract-persetujuan-rab.md](docs/contract-persetujuan-rab.md)
  - Notifikasi dalam aplikasi (lonceng, realtime): [docs/contract-notifikasi.md](docs/contract-notifikasi.md)
  - Laporan PDF RAB & selesaikan pesanan (edge function `generate-report`): [docs/contract-laporan-pdf.md](docs/contract-laporan-pdf.md)

## Struktur

```
supabase/
├── config.toml
├── migrations/             satu file per perubahan — JANGAN edit file yang sudah di-push
│   ├── ..._init_roles_profiles.sql   role, profiles, helper RLS
│   ├── ..._catalog.sql               produk, harga internal, tarif jasa, pajak
│   ├── ..._projects.sql              project, foto, wall paint, furnitur, ukuran
│   ├── ..._rab.sql                   RAB, perhitungan, snapshot final, laporan
│   ├── ..._project_workflow.sql      aturan status, approval, notifikasi
│   ├── ..._audit_logs.sql            audit trail
│   ├── ..._chat.sql                  chat customer ↔ admin
│   └── ..._storage.sql               bucket penyimpanan file + aturan akses
├── seed.sql                akun uji & data contoh (HANYA lokal/dev)
├── templates/
│   └── recovery.html       email reset password (bahasa Indonesia)
└── functions/
    └── request-password-reset/   reset password khusus admin & super admin
docs/
types/database.types.ts     hasil `npm run types`
```

## Setup (tanpa Docker)

Prasyarat: Node.js LTS, akses ke project Supabase `renovin-dev`.

```bash
npm install
npx supabase login
npx supabase link --project-ref <ref-renovin-dev>
```

`supabase link` akan meminta password database. Simpan juga di `.env` (lihat `.env.example`).

### Pertama kali: terapkan migration + seed ke renovin-dev

```bash
npx supabase db push --dry-run
npm run push:dev:seed
```

Cek dulu dengan `--dry-run`. **`--include-seed` hanya untuk dev**: seed membuat akun dengan password yang diketahui semua orang.

## Akun uji (seed)

Password semua akun ada di komentar paling atas `supabase/seed.sql`.

| Email | Role | Data |
|---|---|---|
| `superadmin@renovin.test` | super_admin | — |
| `admin@renovin.test` | admin | — |
| `customer1@renovin.test` | customer | P1 `draft`, P2 `sent_to_admin`, P3 `rab_draft` |
| `customer2@renovin.test` | customer | P4 `pending_approval`, P5 `approved` |
| `admin2@renovin.test` | admin | Nadia Anggraini, penanggung jawab P10, P11, P13, P15 |
| `customer3@renovin.test` | customer | Sarah Wijaya: P9 `correction`, P11 `report_generated` |
| `customer4@renovin.test` | customer | Ari Wibowo: P10 `confirmed`, P13 `completed` |
| `customer5@renovin.test` | customer | Dimas Putra: P6 `sent_to_admin`, P14 `rejected` |
| `customer6@renovin.test` | customer | Maya Lestari: P7 `sent_to_admin`, P15 `admin_processing` |
| `customer7@renovin.test` | customer | Rina Kusuma: P12 `completed` |
| `customer8@renovin.test` | customer | Hendra Gunawan: P8 `ready_to_submit` (belum pernah mengirim pesanan) |

Total 15 project yang mencakup semua status. Rinciannya ada di komentar `supabase/seed.sql`.

## Alur kerja perubahan database

```bash
git checkout development && git pull
git checkout -b feature/<nama-fitur>
npm run migration:new -- <nama_perubahan>    # isi SQL di file baru
npx supabase db push --dry-run               # cek migration yang akan diterapkan
```

Buka PR ke `development`. Setelah direview dan di-merge:

```bash
npm run push:dev       # terapkan ke renovin-dev
npm run types          # generate ulang tipe, bagikan ke renovin-web / renovin-android
```

Aturan:
1. Semua perubahan database lewat migration. Tidak ada perubahan langsung di dashboard.
2. Migration yang sudah di-push tidak diedit. Perbaikan dibuat sebagai migration baru.
3. Perubahan harus backward compatible: tambah kolom boleh, hapus atau ganti nama kolom menunggu Android versi lama tidak dipakai.
4. RLS aktif di semua tabel baru, dengan policy select/insert/update/delete sesuai role.

> Tanpa Docker, migration tidak bisa dites di database lokal sebelum di-push. Review SQL di PR harus teliti. Kalau nanti ada yang memasang Docker: `npx supabase start` lalu `npx supabase db reset` untuk mengetes dari nol.

## Environment variable

| Variabel | Lokasi | Keterangan |
|---|---|---|
| `SUPABASE_ACCESS_TOKEN` | `.env`, secret CI | Dari dashboard → Account → Access Tokens |
| `SUPABASE_DB_PASSWORD` | `.env`, secret CI | Password database project |
| `SUPABASE_DEV_PROJECT_REF` / `SUPABASE_PROD_PROJECT_REF` | `.env`, secret CI | ID project |
| `ALLOWED_ORIGINS` | `supabase/functions/.env`, `supabase secrets` | Origin web admin yang boleh memanggil edge function, dipisah koma |

Secret key / `service_role` **tidak pernah** dipakai di `renovin-web` atau `renovin-android`.
