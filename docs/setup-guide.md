# Renovin — Panduan Setup Proyek

Disusun dari PRD v0.1, FSD v0.1, *Stack - 3 Repo*, dan *Tech Stack Renovin-web* (Oktober 2026), lalu disesuaikan dengan keputusan tim.

Dokumen terkait di repo ini:
- [README.md](../README.md): perintah sehari-hari untuk backend
- [erd.md](erd.md): tabel, hak akses, dan fungsi RPC
- [decisions.md](decisions.md): keputusan arsitektur dan asumsi yang menunggu konfirmasi client

---

## Daftar Isi

1. [Gambaran & pembagian kerja](#1-gambaran--pembagian-kerja)
2. [Status saat ini](#2-status-saat-ini)
3. [Tools di laptop](#3-tools-di-laptop-windows)
4. [Akun & akses](#4-akun--akses)
5. [Repo & konvensi Git](#5-repo--konvensi-git)
6. [Backend (`renovin-backend`)](#6-backend-renovin-backend)
7. [Web admin (`renovin-web`)](#7-web-admin-renovin-web)
8. [Alur kerja per fitur](#8-alur-kerja-per-fitur)
9. [Urutan pengerjaan fitur web admin](#9-urutan-pengerjaan-fitur-web-admin)
10. [CI/CD](#10-cicd-github-actions)
11. [Catatan teknis & batasan](#11-catatan-teknis--batasan)
12. [Checklist](#12-checklist)

---

## 1. Gambaran & pembagian kerja

```
renovin-web (Next.js) ─┐                      ┌─► Postgres + RLS (22 tabel)
                       ├─► Supabase renovin-dev├─► Auth
renovin-android ───────┘   (Singapore)        ├─► Realtime (notifikasi, chat)
                                              └─► Storage (foto, aset, PDF)
```

- **Tidak ada server sendiri.** Web dan Android mengakses Supabase langsung. Hak akses dijaga **RLS** di database.
- **File disimpan di Supabase Storage** dengan aturan akses (RLS) yang sama seperti data. Database menyimpan path dan URL-nya. ImageKit tidak dipakai lagi karena domain `ik.imagekit.io` diblokir di jaringan Telkom Group ([decisions.md](decisions.md) A2).

| Repo | Penanggung jawab | Isi |
|---|---|---|
| `renovin-backend` | **Ihsan** | Migration, RLS, fungsi RPC, seed, edge functions, secret |
| `renovin-web` | **Rivaldy** | Dashboard admin & super admin (Next.js) |
| `renovin-android` | belum ditentukan | Aplikasi customer, dikerjakan belakangan |

**Aturan utama:** hanya pemilik backend yang menulis migration dan menjalankan `supabase db push`. Kebutuhan data baru dari web diajukan lewat issue (lihat [§8](#8-alur-kerja-per-fitur)).

---

## 2. Status saat ini

| Item | Status |
|---|---|
| Supabase `renovin-dev` (Singapore, ref `yblaopjkopdrrnwrxgqt`) | ✅ Dibuat |
| 7 migration + seed diterapkan ke `renovin-dev` | ✅ PR [karikuzoo/renovin-backend#1](https://github.com/karikuzoo/renovin-backend/pull/1) |
| `types/database.types.ts` ter-generate | ✅ |
| Server Express lama dihapus | ✅ |
| Supabase Storage: bucket `catalog`, `room-photos`, `reports` + aturan akses | ✅ Live di `renovin-dev` (10 Okt 2026). Domain storage dites bisa diakses di by.U |
| Foto customer & PDF privat (signed URL) | ✅ Tercakup oleh bucket privat + RLS |
| Notifikasi WhatsApp | ⏳ Menunggu pilihan provider |
| Konfirmasi asumsi ke client ([decisions.md](decisions.md)) | ⏳ |
| Supabase `renovin-prod` | ⏳ Dibuat menjelang rilis |
| `renovin-web` | ⏳ Belum dimulai |

---

## 3. Tools di laptop (Windows)

| Tool | Siapa | Install |
|---|---|---|
| **Git** | Semua | `winget install Git.Git` |
| **Node.js LTS** (v24+) | Semua | `winget install OpenJS.NodeJS.LTS` |
| **VS Code** | Semua | `winget install Microsoft.VisualStudioCode` |
| **GitHub CLI** (opsional) | Semua | `winget install GitHub.cli` |
| **Docker Desktop** (opsional) | Backend | Hanya kalau ingin menjalankan Supabase lokal (`supabase start`). Butuh WSL 2 dan RAM ≥ 8 GB. |
| **Android Studio + JDK 17** | Android | Nanti, saat fase mobile |

**Supabase CLI** tidak di-install global. CLI sudah menjadi dev dependency di `renovin-backend`, jadi cukup `npm install` lalu `npx supabase ...`.

Extension VS Code: ESLint, Prettier, Tailwind CSS IntelliSense, Supabase, PostgreSQL / SQLTools, GitLens (opsional).

Konfigurasi Git (sekali per laptop):

```bash
git config --global user.name "Nama Kamu"
git config --global user.email "email@kantor.com"
git config --global core.autocrlf true
```

---

## 4. Akun & akses

| Akun | Detail | Siapa yang punya akses |
|---|---|---|
| **GitHub** | `karikuzoo` (repo backend, web, android) | Ihsan, Rivaldy |
| **Supabase** | Org *Swandaa Org* (Free) → project `renovin-dev` | Ihsan (owner). Rivaldy opsional, role *Read-only* / *Developer* |
| **ImageKit** | Tidak dipakai lagi (diblokir di jaringan Telkom Group). Akun ID `msyhbdl24` bisa ditutup setelah migrasi selesai | Ihsan |
| **Hosting web** | Vercel / Netlify / Cloudflare (belum dipilih) | Rivaldy |

### Apa yang dibagikan ke siapa

| Data | Backend (Ihsan) | Web (Rivaldy) | Disimpan di |
|---|---|---|---|
| Project URL | ✅ | ✅ | `.env.local` web, boleh dibagikan |
| Publishable / anon key | ✅ | ✅ | `.env.local` web, aman di client karena dibatasi RLS |
| Password database | ✅ | ❌ | Password manager |
| Secret key / `service_role` | ✅ (edge function, CI) | ❌ **jangan pernah** | Supabase secrets, GitHub secrets |
| Supabase access token | ✅ (pribadi) | ❌ | Laptop masing-masing (`supabase login`) |

Password dan key **tidak dikirim lewat chat atau WhatsApp**. Pakai password manager tim.

---

## 5. Repo & konvensi Git

### Branch (sama di ketiga repo)

| Branch | Fungsi | Diterapkan ke |
|---|---|---|
| `main` | Kode yang sudah rilis | Production |
| `development` | Kode yang sudah di-review, siap QA | `renovin-dev` |
| `feature/<nama>` | Fitur baru, dibuat dari `development` | — |
| `fix/<nama>` | Perbaikan bug | — |
| `hotfix/<nama>` | Perbaikan darurat production, dibuat dari `main` | Production |

Branch protection di `main` dan `development`: wajib PR dan **minimal 1 approval** dari orang lain. Pembuat PR tidak bisa meng-approve PR-nya sendiri, jadi Ihsan dan Rivaldy saling me-review.

### Commit

Format Conventional Commits. Baris pertama **maksimal ±72 karakter** (kalau lebih panjang, GitHub memotong judul PR), dan detailnya ditulis di baris berikutnya:

```bash
git commit -m "feat: tambah kolom diskon di rab_line_items" -m "- Kolom discount_percent, default 0" -m "- calculate_rab memperhitungkan diskon"
```

Prefix yang dipakai: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`.

### Pull request

- Base `development`, **jangan langsung ke `main`**.
- Deskripsi berisi: tiket, ringkasan, cara mengetes, dan PR terkait di repo lain (contoh: `Related: karikuzoo/renovin-backend#1`).
- Sebelum stage, cek `git status --ignored`: `.env`, `supabase/.temp/`, dan `local.properties` harus berada di *Ignored files*.

### Folder lokal yang disarankan

```
Documents\Project\Desain Interior\
├── renovin-backend\
├── renovin-web\
└── renovin-android\
```

---

## 6. Backend (`renovin-backend`)

Perintah lengkap ada di [README.md](../README.md). Ringkasannya:

### Setup pertama di laptop baru

```bash
npm install
npx supabase login
npx supabase link --project-ref yblaopjkopdrrnwrxgqt
```

### Isi database

| Migration | Isi |
|---|---|
| `init_roles_profiles` | Role (`customer`, `admin`, `super_admin`), `profiles`, helper RLS, `set_user_role()` |
| `catalog` | Kategori, produk (harga customer), harga internal (khusus staff), tarif jasa, pajak |
| `projects` | Project, foto, wall paint, penempatan furnitur, ukuran manual |
| `rab` | RAB, baris RAB, `calculate_rab()`, snapshot final (terkunci), laporan PDF |
| `project_workflow` | Aturan transisi status, `change_project_status()`, approval, notifikasi |
| `audit_logs` | Jejak perubahan RAB, snapshot, katalog, tarif, dan profil |
| `chat` | Percakapan & pesan customer ↔ admin (Realtime) |

Detail tabel dan hak akses: [erd.md](erd.md).

### Alur perubahan database (tanpa Docker)

```bash
git checkout development
git pull
git checkout -b feature/<nama-fitur>
npm run migration:new -- <nama_perubahan>
npx supabase db push --dry-run
```

Buka PR, tunggu review, lalu merge. Setelah merge:

```bash
npm run push:dev
npm run types
```

Setelah itu kabari Rivaldy bahwa tipe baru sudah ada.

Karena migration tidak bisa dites di database lokal sebelum di-push, **review SQL di PR harus teliti**. Kalau nanti Docker dipasang, tambahkan `npx supabase start` dan `npx supabase db reset` sebelum membuka PR.

Aturan migration:
1. Semua perubahan lewat migration. **Tidak ada edit tabel di dashboard.**
2. Migration yang sudah di-push **tidak diedit**. Perbaikan dibuat sebagai migration baru.
3. Perubahan harus **backward compatible**. Tambah kolom boleh, hapus atau ganti nama kolom menunggu Android versi lama tidak dipakai.
4. **RLS aktif** di setiap tabel baru, dengan policy select/insert/update/delete sesuai role.

### Penyimpanan file (Supabase Storage)

Dibuat oleh migration `..._storage.sql`. Detail bucket, path, dan hak akses ada di [erd.md](erd.md#penyimpanan-file-supabase-storage).

| Bucket | Akses | Path |
|---|---|---|
| `catalog` | Publik untuk dilihat, tulis hanya staff | `products/<product_id>/<file>` |
| `room-photos` | Privat: pemilik project + staff | `<project_id>/<file>` |
| `reports` | Privat: pemilik project + staff, tidak bisa dihapus | `<project_id>/<file>` |

- **Kuota Supabase Free: 1 GB.** Kompres foto di aplikasi sebelum upload (≤ 1600 px sisi terpanjang, JPEG/WebP).
- **Tes sebelum dipakai customer:** buka `https://yblaopjkopdrrnwrxgqt.supabase.co/storage/v1/version` di jaringan Telkomsel/by.U/IndiHome. Kalau muncul halaman "Internet Baik", domain Supabase juga diblokir dan perlu domain sendiri.

### Akun uji (seed, khusus dev)

| Email | Role |
|---|---|
| `superadmin@renovin.test` | super_admin |
| `admin@renovin.test` | admin |
| `customer1@renovin.test` | customer (P1 `draft`, P2 `sent_to_admin`, P3 `rab_draft`) |
| `customer2@renovin.test` | customer (P4 `pending_approval`, P5 `approved`) |

Password ada di komentar paling atas `supabase/seed.sql`. **Seed tidak pernah dijalankan di prod.**

---

## 7. Web admin (`renovin-web`)

### 7.1 Buat project

```bash
npx create-next-app@latest . --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
npm i @supabase/supabase-js @supabase/ssr
npx shadcn@latest init
npx shadcn@latest add button input label card table dialog dropdown-menu select badge tabs sonner form sheet separator skeleton
npm i lucide-react react-hook-form zod @hookform/resolvers @tanstack/react-table date-fns @react-pdf/renderer
```

| Library | Untuk |
|---|---|
| `@supabase/ssr` | Login dan sesi via cookie di App Router |
| shadcn `table` + `@tanstack/react-table` | Daftar project, katalog, baris RAB |
| `react-hook-form` + `zod` | Form katalog, tarif, edit RAB |
| `@react-pdf/renderer` | Generate PDF laporan di server (Route Handler) |
| `sonner` | Toast |

Acuan tampilan: folder `Ruang-Web-Admin-Figma`.

### 7.2 Environment variable

`.env.example` (di-commit):

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=
```

`.env.local` (tidak di-commit):

```
NEXT_PUBLIC_SUPABASE_URL=https://yblaopjkopdrrnwrxgqt.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=<dari Ihsan / Dashboard → Project Settings → API Keys>
```

Tidak ada secret key di repo web, termasuk di variabel tanpa `NEXT_PUBLIC_`.

### 7.3 Tipe database

Salin `types/database.types.ts` dari repo backend ke `src/types/database.types.ts` setiap kali backend memberi kabar ada migration baru.

```ts
import { createBrowserClient } from '@supabase/ssr'
import type { Database } from '@/types/database.types'

export const createClient = () =>
  createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!,
  )
```

### 7.4 Supabase client & login

Ikuti panduan resmi **Supabase Auth → Server-Side Rendering → Next.js**:

```
src/lib/supabase/client.ts   createBrowserClient (Client Component)
src/lib/supabase/server.ts   createServerClient + cookies() (Server Component / Route Handler)
src/proxy.ts                 refresh sesi & redirect ke /login
                             (Next.js 16+; versi lama: middleware.ts)
```

Setelah login, panggil `supabase.rpc('my_role')`. Kalau hasilnya `customer`, langsung sign out dan tampilkan "Akun tidak memiliki akses admin". Keamanan sebenarnya tetap di RLS. Pengecekan ini hanya supaya UI-nya benar.

### 7.5 Cara web berinteraksi dengan backend

| Kebutuhan | Cara |
|---|---|
| Baca/tulis data | Query tabel langsung (`supabase.from('products')...`). RLS yang membatasi |
| Ubah status project | `supabase.rpc('change_project_status', { p_project_id, p_to_status, p_note })`. Kolom `status` tidak bisa di-`update` langsung |
| Tombol aksi yang tersedia | Baca tabel `project_status_transitions` (filter `from_status` + role user) |
| Hitung RAB | `supabase.rpc('calculate_rab', { p_project_id })`. Baris manual admin tidak hilang |
| Koreksi RAB | `update` kolom `adjustment`, `adjustment_note`, `notes` di `rabs`, atau insert/update/delete `rab_line_items`. Total dihitung otomatis oleh database |
| Ubah role user | `supabase.rpc('set_user_role', { p_user_id, p_role })` (khusus super admin) |
| Notifikasi & chat realtime | `supabase.channel(...).on('postgres_changes', { table: 'notifications' \| 'messages' })` |
| Upload file | `uploadFile(file, bucket, folder)` di `lib/storage.ts` → simpan `path` ke kolom `*_file_id` dan `url` ke kolom `*_url` |
| Tampilkan file privat | `getFileUrl(bucket, path)` → signed URL yang kedaluwarsa (default 1 jam) |
| Laporan PDF | Route Handler membaca `rab_snapshots.data`, membuat PDF, upload ke bucket `reports` (`<project_id>/...`), lalu upsert `reports` (`on conflict snapshot_id`), dan terakhir `change_project_status(..., 'report_generated')` |

Helper upload ada di `renovin-web/lib/storage.ts`. Contoh pemakaian:

```ts
import { uploadFile, getFileUrl } from '@/lib/storage'

// Gambar katalog (bucket publik): url langsung bisa dipakai di <Image>
const { path, url } = await uploadFile(file, 'catalog', `products/${productId}`)
await supabase.from('products').update({ image_file_id: path, image_url: url }).eq('id', productId)

// Foto ruangan / PDF (bucket privat): url = path, tampilkan lewat signed URL
const foto = await uploadFile(file, 'room-photos', projectId)
const linkSementara = await getFileUrl('room-photos', foto.path)
```

| Bucket | Folder | Tipe & batas |
|---|---|---|
| `catalog` | `products/<product_id>` | JPEG/PNG/WebP, 5 MB |
| `room-photos` | `<project_id>` | JPEG/PNG/WebP, 10 MB |
| `reports` | `<project_id>` | PDF, 10 MB |

- Upload ditolak (pesan `new row violates row-level security policy`) kalau user tidak berhak, misalnya customer menulis ke project orang lain, atau path tidak diawali `project_id`.
- Signed URL kedaluwarsa, jadi **jangan disimpan ke database**. Simpan path-nya, dan buat signed URL baru setiap kali ditampilkan.

Error dari RPC berupa pesan bahasa Indonesia (misalnya "RAB belum dihitung atau masih kosong"), jadi bisa langsung ditampilkan di toast.

### 7.6 Struktur halaman (FSD §10.2 & §10.3)

```
src/app/
├── (auth)/login/page.tsx                    Login admin
├── (dashboard)/layout.tsx                   Sidebar + cek sesi & role
├── (dashboard)/page.tsx                     Ringkasan jumlah project per status
├── (dashboard)/projects/page.tsx            Daftar project + filter status        FSD 10.2
├── (dashboard)/projects/[id]/page.tsx       Before/after, wall paint, furnitur,   FS-08
│                                            ukuran, timeline status
├── (dashboard)/projects/[id]/rab/page.tsx   RAB draft & koreksi                   FS-09, FS-11
├── (dashboard)/approvals/page.tsx           Antrean pending_approval              FS-10
├── (dashboard)/catalog/page.tsx             Kelola produk + harga internal        FS-15
├── (dashboard)/catalog/[id]/page.tsx
├── (dashboard)/settings/rates/page.tsx      Tarif jasa & pajak
├── (dashboard)/chat/page.tsx                Chat dengan customer                  FS-14
├── (dashboard)/reports/page.tsx             Daftar PDF final
└── api/reports/[projectId]/route.ts         Generate PDF                          FS-13
```

### 7.7 Yang perlu dikabarkan Rivaldy ke backend

- URL web dev (`http://localhost:3000`) dan production, untuk `ALLOWED_ORIGINS`.
- Kebutuhan kolom, tabel, atau RPC baru, lewat issue di repo backend.

---

## 8. Alur kerja per fitur

```
Issue fitur ──► Backend: migration → PR → review → merge → db push dev → npm run types
                                                                      │
                                    kabari web ◄──────────────────────┘
                                         │
                Web: salin tipe → halaman → tes ke renovin-dev → PR (Related: backend#..) → review → merge
                                         │
                                QA di dev ──► tiket selesai
```

1. Buat **issue** berisi deskripsi dan acceptance criteria. Satu issue menjadi induk semua PR terkait.
2. **Backend duluan.** Web baru mulai setelah perubahan database ada di `renovin-dev`.
3. Kalau **web hanya memakai tabel yang sudah ada**, langsung kerjakan tanpa menunggu backend.
4. QA memakai akun uji: login sebagai admin, super admin, customer1, dan customer2. Pastikan customer1 tidak melihat data customer2.

---

## 9. Urutan pengerjaan fitur web admin

| # | Fitur | Backend | Web | Ref FSD |
|---|---|---|---|---|
| 1 | Login & layout | ✅ siap | Login, proxy, layout, tolak customer | §5 |
| 2 | Katalog | ✅ data + upload gambar (bucket `catalog`) | CRUD produk, harga internal, aktif/nonaktif | FS-15 |
| 3 | Tarif & pajak | ✅ | Halaman pengaturan | §7 |
| 4 | Daftar & detail project | ✅ (seed P1–P5) | Daftar per status, before/after, timeline | FS-08 |
| 5 | Workflow status | ✅ `change_project_status` + notifikasi | Tombol aksi sesuai status & role | §8 |
| 6 | RAB draft & koreksi | ✅ `calculate_rab` + audit | Halaman RAB, edit baris, adjustment | FS-09, FS-11 |
| 7 | Approval super admin | ✅ | Antrean + Approve/Correction/Reject (catatan wajib) | FS-10 |
| 8 | Confirm final & PDF | ✅ snapshot + upload PDF (bucket `reports`) | Confirm, generate PDF, download | FS-12, FS-13 |
| 9 | Chat | ✅ in-app · ⏳ WhatsApp | Daftar percakapan + pesan realtime | FS-14 |

---

## 10. CI/CD (GitHub Actions)

### Backend: sudah terpasang

File: [`.github/workflows/ci.yml`](../.github/workflows/ci.yml). Workflow ini berjalan di setiap PR ke `development`/`main`, setiap push ke `development`, dan bisa dijalankan manual dari tab **Actions**.

| Job | Yang dicek |
|---|---|
| **Migration & seed** | Supabase lokal dinyalakan di runner GitHub (yang punya Docker), lalu **semua migration + `seed.sql` dijalankan dari nol** dan database di-lint (`supabase db lint`, gagal kalau ada error). |
| **Edge functions type-check** | `deno check` untuk semua `supabase/functions/*/index.ts` |

- Workflow ini **tidak menyentuh** `renovin-dev`/`renovin-prod` dan tidak memakai secret.
- Ini menutup kelemahan alur tanpa Docker: SQL yang error ketahuan di PR, **sebelum** `db push` ke dev.
- Kalau job merah, buka tab **Actions** → run yang gagal → step yang merah untuk melihat pesan error-nya.

**Jadikan wajib lolos** (dilakukan pemilik repo, setelah workflow pernah jalan minimal sekali): Settings → Branches → rule `development` (dan `main`) → ✅ *Require status checks to pass before merging* → tambahkan **Migration & seed** dan **Edge functions type-check**.

### Web: rekomendasi untuk `renovin-web`

Lint, cek tipe, dan build di setiap PR:

```yaml
name: CI
on:
  pull_request:
    branches: [development, main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 24, cache: npm }
      - run: npm ci
      - run: npm run lint
      - run: npx tsc --noEmit
      - run: npm run build
        env:
          NEXT_PUBLIC_SUPABASE_URL: ${{ secrets.DEV_SUPABASE_URL }}
          NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: ${{ secrets.DEV_SUPABASE_PUBLISHABLE_KEY }}
```

Deploy ke prod tetap **manual**, mengikuti urutan rilis di dokumen Stack: backend → web → android.

---

## 11. Catatan teknis & batasan

- **Supabase Free:**
  - maksimal 2 project gratis (cukup untuk dev + prod),
  - project **di-pause setelah 7 hari tidak aktif** (buka dashboard untuk mengaktifkan lagi),
  - tidak ada backup otomatis yang bisa diunduh. Untuk prod, rencanakan backup manual atau upgrade.
- **Label `main PRODUCTION`** di dashboard Supabase berasal dari fitur Branching, dan bisa diabaikan. Pemisahan dev/prod kita memakai project terpisah.
- **Vercel Hobby melarang penggunaan komersial.** Untuk project client pilih Vercel Pro, Netlify, atau Cloudflare.
- **ImageKit diblokir di jaringan Telkom Group.** Domain bersama `ik.imagekit.io` diblokir "Internet Baik" (dites 10 Okt 2026: by.U diblokir, XL bisa). Karena itu file dipindah ke Supabase Storage. Pelajaran: layanan yang menyajikan file lewat **domain bersama** berisiko ikut terblokir karena pengguna lain.
- **AI segmentasi (SAM)** tidak bisa jalan di edge function. Ini hanya untuk alur Android, dan harus diputuskan sebelum fase mobile: on-device, API pihak ketiga, atau service Python terpisah.
- **Dokumen Stack lama** masih memakai nama `namaapp-frontend` / `namaapp-mobile`, `src/pages/`, dan branch `develop`. Yang berlaku adalah panduan ini.

---

## 12. Checklist

**Akun & akses**
- [x] Supabase `renovin-dev` (Singapore)
- [x] Repo `renovin-backend` + branch `development` + branch protection
- [ ] Rivaldy mendapat Project URL + publishable key
- [ ] Rivaldy diundang ke Supabase org (opsional, role terbatas)
- [ ] Password DB tersimpan di password manager
- [ ] Hosting web dipilih

**Backend**
- [x] Migration + seed di `renovin-dev`
- [x] Tipe database ter-generate
- [x] Migration storage di-push ke `renovin-dev`
- [x] Domain Supabase dites di jaringan Telkomsel/by.U
- [x] CI migration di GitHub Actions
- [ ] CI dijadikan *required status check* di branch protection
- [ ] Signed URL foto private

**Web**
- [ ] Next.js + shadcn jalan di `localhost:3000`
- [ ] Login admin berhasil, customer ditolak
- [ ] Tipe database disalin dari backend
- [ ] Upload gambar katalog ke bucket `catalog` berhasil (tes pertama dengan user login)
- [ ] CI build

**Keputusan**
- [ ] Asumsi di [decisions.md](decisions.md) dikonfirmasi client
- [ ] Siapa yang mengerjakan `renovin-android`
- [ ] Kepemilikan akun (Supabase, GitHub, domain, Play Console)
