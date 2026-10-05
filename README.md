# renovin-backend

Konfigurasi Supabase untuk Renovin: migration database, RLS, seed, dan edge functions. Repo ini **tidak berisi server**. Web admin (`renovin-web`) dan aplikasi Android (`renovin-android`) mengakses Supabase langsung, dan RLS di database yang menentukan siapa boleh mengakses data apa.

File (foto, aset katalog, PDF) disimpan di **ImageKit**, dengan token upload dari edge function `imagekit-auth`.

- Struktur tabel & hak akses: [docs/erd.md](docs/erd.md)
- Asumsi yang masih menunggu konfirmasi client: [docs/decisions.md](docs/decisions.md)

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
│   └── ..._chat.sql                  chat customer ↔ admin
├── seed.sql                akun uji & data contoh (HANYA lokal/dev)
└── functions/
    └── imagekit-auth/      token upload ImageKit untuk user yang login
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

### Edge function ImageKit

```bash
cp supabase/functions/.env.example supabase/functions/.env   # isi key ImageKit
npm run secrets:set
npm run functions:deploy
```

## Akun uji (seed)

Password semua akun ada di komentar paling atas `supabase/seed.sql`.

| Email | Role | Data |
|---|---|---|
| `superadmin@renovin.test` | super_admin | — |
| `admin@renovin.test` | admin | — |
| `customer1@renovin.test` | customer | P1 `draft`, P2 `sent_to_admin`, P3 `rab_draft` |
| `customer2@renovin.test` | customer | P4 `pending_approval`, P5 `approved` |

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
| `IMAGEKIT_PUBLIC_KEY`, `IMAGEKIT_PRIVATE_KEY`, `IMAGEKIT_URL_ENDPOINT` | `supabase/functions/.env`, `supabase secrets` | Dari dashboard ImageKit |
| `ALLOWED_ORIGINS` | `supabase/functions/.env`, `supabase secrets` | Origin web admin, dipisah koma |

Secret key / `service_role` **tidak pernah** dipakai di `renovin-web` atau `renovin-android`.
