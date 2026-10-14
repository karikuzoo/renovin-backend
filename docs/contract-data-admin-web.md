# Data untuk web admin (kontrak FE)

Dokumen ini menjelaskan **data siap pakai** dari backend untuk halaman-halaman di `renovin-web/app/workplace`. Isinya per halaman: apa yang dipanggil, arti tiap kolom, dan contoh hasilnya.

Semua pemanggilan memakai client Supabase yang sudah ada (`@/lib/supabase/client` atau `@/lib/supabase/server`). Tipe TypeScript-nya ada di `types/database.types.ts`. Salin ulang file itu dari repo backend setiap kali dokumen ini berubah.

| Halaman | Sumber data | Status |
|---|---|---|
| Dashboard, Pesanan, Pesanan Baru | view `admin_orders` | ✅ Tersedia |
| Ringkasan angka dashboard | fungsi `dashboard_summary` | ✅ Tersedia |
| Klien | — | ⏳ Menyusul |
| Pembayaran, tukang, tahap produksi/instalasi, progres % | — | 🔒 Menunggu keputusan client. Tetap pakai data contoh dulu |

---

## `admin_orders` — daftar pesanan

Satu baris = satu project yang **sudah dikirim** customer. Project `draft` dan `ready_to_submit` tidak pernah muncul.

**Siapa yang bisa membaca:** hanya `admin` dan `super_admin`. Customer yang memanggil view ini selalu mendapat **daftar kosong** (bukan error). Pengguna yang belum login mendapat error `permission denied`.

### Contoh pemanggilan

```ts
import { createClient } from "@/lib/supabase/client";

const supabase = createClient();

// Tab "Baru" di halaman Pesanan / halaman Pesanan Baru
const { data, error } = await supabase
  .from("admin_orders")
  .select("*")
  .eq("status_group", "new")
  .order("submitted_at", { ascending: false });

// Tab "Dikerjakan", 10 per halaman, dengan total untuk pagination
const { data: rows, count } = await supabase
  .from("admin_orders")
  .select("*", { count: "exact" })
  .eq("status_group", "in_progress")
  .order("submitted_at", { ascending: false })
  .range(0, 9);

// Pencarian nomor pesanan / judul / nama klien
const keyword = "budi";
await supabase
  .from("admin_orders")
  .select("*")
  .or(`code.ilike.%${keyword}%,title.ilike.%${keyword}%,customer_name.ilike.%${keyword}%`);

// Detail satu pesanan
await supabase.from("admin_orders").select("*").eq("id", projectId).single();
```

### Kolom

| Kolom | Tipe | Arti |
|---|---|---|
| `id` | uuid | ID project. Dipakai untuk link detail, chat, dan `change_project_status` |
| `code` | text | Nomor pesanan, format `RNV-YYMM-00001`. Tampilkan apa adanya |
| `title` | text | Judul project dari customer |
| `room_type` | text \| null | Jenis ruangan, teks bebas (misalnya "Ruang tamu") |
| `notes` | text \| null | Catatan project |
| `status` | `project_status` | Status detail (12 nilai, lihat tabel di bawah) |
| `status_group` | `order_status_group` | Kelompok tab: `new`, `in_progress`, `done`, `rejected` |
| `submitted_at` | timestamptz | Waktu customer mengirim pesanan (dipakai sebagai "Tanggal masuk") |
| `updated_at` | timestamptz | Terakhir project berubah |
| `customer_id` | uuid | ID customer |
| `customer_name` | text \| null | Nama customer |
| `customer_email` | text \| null | Email customer |
| `customer_phone` | text \| null | Nomor HP customer |
| `assigned_admin_id` | uuid \| null | Admin penanggung jawab. `null` = belum diambil admin |
| `assigned_admin_name` | text \| null | Nama admin penanggung jawab |
| `order_value` | numeric \| null | **Nilai pesanan** (total RAB untuk customer, sudah termasuk jasa dan pajak). `null` = RAB belum dihitung. Tampilkan "Belum dihitung", **bukan** `Rp 0` |
| `rab_calculated_at` | timestamptz \| null | Kapan RAB terakhir dihitung |
| `total_area` | numeric | Total luas dari semua ukuran (m²). `0` = belum ada ukuran |
| `measurement_count` | number | Jumlah ukuran yang diinput |
| `cover_photo_path` | text \| null | Foto pertama project (lihat cara menampilkan di bawah). `null` = belum ada foto |
| `photo_count` | number | Jumlah foto ruangan |

> **Format rupiah:** `order_value` dan `total_area` datang sebagai number (misalnya `6210450` atau `2180572.8`). Format dengan `new Intl.NumberFormat("id-ID", { style: "currency", currency: "IDR", maximumFractionDigits: 0 }).format(row.order_value)`.
>
> **Semua kolom view bertipe `… | null` di TypeScript.** Ini aturan umum Supabase untuk view, bukan berarti datanya kosong. Kolom yang **benar-benar** bisa `null` hanya yang ditandai di tabel di atas. Untuk kolom lain, aman memakai `row.code!` atau memberi nilai cadangan.

### Kelompok status (tab)

| `status_group` | Label tab yang disarankan | Status yang termasuk |
|---|---|---|
| `new` | Baru | `sent_to_admin` |
| `in_progress` | Dikerjakan | `admin_processing`, `rab_draft`, `pending_approval`, `approved`, `correction`, `confirmed`, `report_generated` |
| `done` | Selesai | `completed` |
| `rejected` | Ditolak | `rejected` (ditolak super admin) |

Label badge untuk `status` detail (disarankan):

| `status` | Label |
|---|---|
| `sent_to_admin` | Pesanan masuk |
| `admin_processing` | Diproses admin |
| `rab_draft` | Draft RAB |
| `pending_approval` | Menunggu persetujuan |
| `approved` | Disetujui |
| `correction` | Perlu koreksi |
| `rejected` | Ditolak |
| `confirmed` | Dikonfirmasi |
| `report_generated` | Laporan dibuat |
| `completed` | Selesai |

### Menampilkan foto sampul

Foto ruangan disimpan di bucket **privat** `room-photos`, jadi `cover_photo_path` berisi **path**, bukan URL. Ubah dulu menjadi signed URL:

```ts
function isUrl(v: string) {
  return v.startsWith("http://") || v.startsWith("https://");
}

const path = row.cover_photo_path;
let src: string | null = null;
if (path) {
  if (isUrl(path)) {
    src = path; // data seed memakai URL placeholder
  } else {
    const { data } = await supabase.storage.from("room-photos").createSignedUrl(path, 60 * 60);
    src = data?.signedUrl ?? null;
  }
}
```

Untuk banyak foto sekaligus, pakai `createSignedUrls(paths, 3600)` supaya cukup satu request.

### Aksi dari daftar pesanan

| Tombol | Panggilan |
|---|---|
| "Terima pesanan" (status `sent_to_admin`) | `supabase.rpc("change_project_status", { p_project_id: id, p_to_status: "admin_processing" })`. Admin yang menekan otomatis menjadi penanggung jawab |
| "Hubungi klien" | Chat: tabel `conversations` dan `messages` |

### Contoh hasil

```json
{
  "id": "…",
  "code": "RNV-2610-00003",
  "title": "Ruang keluarga minimalis",
  "room_type": "Ruang keluarga",
  "notes": null,
  "status": "rab_draft",
  "status_group": "in_progress",
  "submitted_at": "2026-10-12T03:15:00+00:00",
  "updated_at": "2026-10-12T05:40:00+00:00",
  "customer_id": "…",
  "customer_name": "Budi Santoso",
  "customer_email": "customer1@renovin.test",
  "customer_phone": "081200000003",
  "assigned_admin_id": "…",
  "assigned_admin_name": "Admin Renovin",
  "order_value": 6210450,
  "rab_calculated_at": "2026-10-12T05:40:00+00:00",
  "total_area": 15,
  "measurement_count": 1,
  "cover_photo_path": "https://placehold.co/1200x800/png?text=Ruang+Keluarga+-+Asli",
  "photo_count": 1
}
```

### Belum tersedia di `admin_orders`

Bagian di desain web berikut **belum ada datanya**. Tetap pakai data contoh atau sembunyikan dulu:

- Kolom pembayaran, uang diterima/sisa, jadwal pembayaran 🔒
- Tahap Brief → Desain → Produksi → Instalasi, progres %, target selesai 🔒
- Alamat/kota klien, jenis properti (Hunian/Apartemen/Komersial), cakupan renovasi, target mulai, file denah. Kolomnya akan ditambahkan, dan nantinya diisi dari aplikasi Android
- Mengganti admin penanggung jawab (fungsi menyusul)

---

## `dashboard_summary` — angka ringkasan dashboard

Satu panggilan mengembalikan semua angka untuk kartu **"Ringkasan studio"** di Dashboard. Angkanya dihitung dari `admin_orders`, jadi selalu cocok dengan isi tab di halaman Pesanan.

**Siapa yang bisa memanggil:** hanya `admin` dan `super_admin`. Selain itu akan mendapat error (kode `42501`).

### Contoh pemanggilan

```ts
// Semua pesanan sejak awal
const { data: summary, error } = await supabase.rpc("dashboard_summary").single();

// Periode tertentu (berdasarkan tanggal pesanan masuk), misalnya Oktober 2026 (WIB)
await supabase
  .rpc("dashboard_summary", {
    p_from: "2026-10-01T00:00:00+07:00",
    p_to: "2026-11-01T00:00:00+07:00", // batas akhir tidak ikut dihitung
  })
  .single();
```

Fungsi ini selalu mengembalikan **tepat satu baris**, jadi pakai `.single()` supaya `data` berupa objek, bukan array.

### Kolom

| Kolom | Tipe | Arti | Dipakai di kartu |
|---|---|---|---|
| `total_orders` | number | Jumlah pesanan **tanpa** yang ditolak (`new` + `in_progress` + `done`) | "Total pesanan" |
| `new_orders` | number | Pesanan baru yang belum diterima admin | "… pesanan baru menunggu konfirmasi" |
| `in_progress_orders` | number | Pesanan yang sedang dikerjakan | "Proyek dikerjakan" |
| `done_orders` | number | Pesanan selesai | "Proyek selesai" |
| `rejected_orders` | number | Pesanan yang ditolak super admin | (opsional) |
| `in_progress_by_status` | object | Rincian `in_progress` per status detail, misalnya `{ "rab_draft": 1, "approved": 1 }`. Status dengan jumlah 0 tidak muncul | Teks kecil di bawah "Proyek dikerjakan" |
| `total_order_value` | number | Jumlah nilai RAB dari `total_orders`. Pesanan yang belum punya RAB dihitung 0 | "Nilai pesanan" |
| `valued_orders` | number | Berapa pesanan yang sudah punya nilai RAB | "Total nilai dari … pesanan" |
| `last_completed_at` | timestamptz \| null | Kapan pesanan terakhir selesai. `null` = belum ada yang selesai | "Serah terima pada …" |
| `generated_at` | timestamptz | Waktu angka ini dihitung | "Terakhir diperbarui …" |

Untuk teks di bawah "Proyek dikerjakan", pakai label status dari tabel di bagian `admin_orders`. Contohnya `{ "rab_draft": 1, "approved": 1 }` menjadi "1 Draft RAB · 1 Disetujui".

> **Rp 485 jt:** untuk format singkat, pakai `new Intl.NumberFormat("id-ID", { notation: "compact", maximumFractionDigits: 1 }).format(v)`. Hasilnya misalnya "8,4 jt", lalu tambahkan "Rp " di depannya.

### Contoh hasil

```json
{
  "total_orders": 3,
  "new_orders": 1,
  "in_progress_orders": 1,
  "done_orders": 1,
  "rejected_orders": 1,
  "in_progress_by_status": { "rab_draft": 1 },
  "total_order_value": 8391022.8,
  "valued_orders": 2,
  "last_completed_at": "2026-10-01T03:00:00+00:00",
  "generated_at": "2026-10-14T16:52:32.849+00:00"
}
```

### Belum tersedia

- Rincian "1 desain · 1 produksi · 1 instalasi" 🔒. Tahap produksi dan instalasi belum ada di alur. Untuk sementara pakai rincian `in_progress_by_status`
- Angka keuangan (uang diterima, sisa, realisasi) 🔒
