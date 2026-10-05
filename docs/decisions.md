# Keputusan & Asumsi Backend

Dokumen PRD/FSD v0.1 masih menyisakan beberapa pertanyaan. Supaya pengembangan bisa jalan, backend memakai **asumsi** di bawah ini. Setiap asumsi yang berubah setelah dikonfirmasi client **dibuat sebagai migration baru**. Migration lama tidak diedit.

Status: ⏳ = menunggu konfirmasi client, ✅ = sudah disepakati.

## Arsitektur

| # | Keputusan | Status |
|---|---|---|
| A1 | Backend = Supabase saja (migration, RLS, seed, edge functions). Server Express dihapus. | ✅ |
| A2 | File (foto, aset katalog, PDF) disimpan di **ImageKit**. Database hanya menyimpan `file_id` dan URL. | ✅ |
| A3 | Token upload ImageKit diberikan oleh edge function `imagekit-auth`, hanya untuk user yang login. | ✅ |

## Asumsi yang menunggu konfirmasi

| # | Topik | Asumsi yang dipakai | Lokasi di kode | Status |
|---|---|---|---|---|
| Q1 | Urutan status | Mengikuti FSD §3: `admin_processing → rab_draft → pending_approval → approved/correction/rejected → confirmed → report_generated → completed` | `project_status_transitions` (migration 005) | ⏳ |
| Q2 | Siapa yang Confirm Final | **Admin** (dan super admin) boleh `approved → confirmed` | `project_status_transitions` | ⏳ |
| Q3 | Setelah `correction` | Kembali ke `admin_processing` atau `rab_draft`, lalu diajukan ulang ke super admin | `project_status_transitions` | ⏳ |
| Q3b | Setelah `rejected` | Status akhir, tidak ada transisi keluar | `project_status_transitions` | ⏳ |
| Q4 | Rumus luas | `luas = panjang × lebar` (PRD §8). Untuk dinding kemungkinan seharusnya `lebar × tinggi` | `room_measurements.area` (generated column, migration 003) | ⏳ |
| Q5 | Furnitur di RAB | Masuk RAB, 1 unit per penempatan × harga katalog | `private.calculate_rab` (migration 004) | ⏳ |
| Q6 | Jasa | Dua jenis: `per_m2` (luas × tarif, untuk tipe produk tertentu) dan `flat` (1 paket) | `service_rates`, `calculate_rab` | ⏳ |
| Q6b | Pajak | Persentase dari (material + jasa + adjustment), default **11%**, bisa diubah di `app_settings` | `app_settings` key `tax`, `private.rabs_compute_totals` | ⏳ |
| Q6c | Adjustment | Hanya memengaruhi total **customer**. Total internal = material internal | `private.rabs_compute_totals` | ⏳ |
| Q7 | Chat & WhatsApp | Chat in-app (Supabase Realtime). Customer membuka chat dengan nomor pesanan = `projects.code`. Pengiriman WhatsApp **belum dibuat**, menunggu pilihan provider | migration 007 | ⏳ |
| Q8 | Kapan RAB boleh diedit | Staff: `admin_processing`, `rab_draft`, `correction`. Super admin juga saat `pending_approval`. Terkunci setelah `approved` | `public.can_edit_rab` | ⏳ |
| Q9 | Data minimum submit | Minimal 1 foto ruangan. Ukuran opsional (PRD: "input ukuran opsional") | `change_project_status` | ⏳ |
| Q10 | Revisi setelah confirmed | Belum ada. Kolom `rab_snapshots.version` sudah disiapkan untuk revisi nanti | — | ⏳ |

## Catatan keamanan

- **RAB dan snapshot hanya bisa dibaca staff**, karena berisi harga internal. Customer menerima hasil akhir lewat PDF (`reports`).
- **Status project tidak bisa diubah langsung.** Kolom `status` tidak di-grant ke client, jadi semua perubahan lewat `change_project_status()`, yang mengecek role, transisi, dan data minimum, lalu mencatat riwayat.
- **Role user tidak bisa diubah sendiri.** Perubahan role lewat `set_user_role()` (khusus super admin).
- **Foto di ImageKit belum mengikuti RLS.** Saat ini URL ImageKit bersifat publik bagi siapa pun yang tahu URL-nya. PRD meminta URL aset mengikuti kontrol akses, jadi **TODO**: upload foto customer sebagai *private file* dan buat edge function `imagekit-signed-url` yang mengecek `can_read_project()` sebelum memberi signed URL.
- **Token upload ImageKit tidak membatasi folder.** Field `folder` dari `imagekit-auth` hanya konvensi.
