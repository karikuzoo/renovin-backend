# Kontrak FE: ringkasan dashboard (`dashboard_summary`)

Dipakai kartu **"Ringkasan studio"** di halaman **Dashboard** (`renovin-web/app/workplace/dashboard`).

Semua pemanggilan memakai client Supabase yang sudah ada (`@/lib/supabase/client` atau `@/lib/supabase/server`). Tipe TypeScript-nya ada di `types/database.types.ts`. Salin ulang file itu dari repo backend setiap kali kontrak ini berubah.

Kontrak data web admin lainnya: lihat daftar di README repo backend.

Satu panggilan mengembalikan semua angka untuk kartu **"Ringkasan studio"** di Dashboard. Angkanya dihitung dari `admin_orders`, jadi selalu cocok dengan isi tab di halaman Pesanan.

**Siapa yang bisa memanggil:** hanya `admin` dan `super_admin`. Selain itu akan mendapat error (kode `42501`).

## Contoh pemanggilan

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

> **Perhatikan `last_completed_at`:** di `database.types.ts` kolom ini tertulis `string`, padahal nilainya **bisa `null`** (belum ada pesanan selesai). Ini keterbatasan generator tipe Supabase untuk fungsi. Tetap cek dulu, misalnya `summary.last_completed_at ? formatTanggal(summary.last_completed_at) : "Belum ada serah terima"`.

## Kolom

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

Untuk teks di bawah "Proyek dikerjakan", pakai label status dari [contract-admin-orders.md](contract-admin-orders.md#kelompok-status-tab). Contohnya `{ "rab_draft": 1, "approved": 1 }` menjadi "1 Draft RAB · 1 Disetujui".

> **Rp 485 jt:** untuk format singkat, pakai `new Intl.NumberFormat("id-ID", { notation: "compact", maximumFractionDigits: 1 }).format(v)`. Hasilnya misalnya "8,4 jt", lalu tambahkan "Rp " di depannya.

## Contoh hasil

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

## Belum tersedia

- Rincian "1 desain · 1 produksi · 1 instalasi" 🔒. Tahap produksi dan instalasi belum ada di alur. Untuk sementara pakai rincian `in_progress_by_status`
- Angka keuangan (uang diterima, sisa, realisasi) 🔒
