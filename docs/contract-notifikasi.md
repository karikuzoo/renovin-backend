# Kontrak FE: notifikasi dalam aplikasi (`notifications`)

Dipakai **ikon lonceng** di header web admin (`renovin-web/app/workplace/layout.tsx`), dan nantinya aplikasi Android untuk customer.

Semua pemanggilan memakai client Supabase yang sudah ada (`@/lib/supabase/client`). Tipe TypeScript-nya ada di `types/database.types.ts`.

Kontrak data web admin lainnya: lihat daftar di README repo backend.

## Data

Tabel `notifications` berisi satu baris per notifikasi **per penerima**.

| Kolom | Arti |
|---|---|
| `id` | number |
| `user_id` | Penerima. Selalu akun yang sedang login, karena RLS membatasinya |
| `project_id` | Pesanan terkait (bisa `null`). Dipakai untuk link ke detail pesanan |
| `type` | Jenis notifikasi (lihat tabel di bawah) |
| `title` | Judul singkat, sudah berbahasa Indonesia |
| `body` | Keterangan, biasanya "`RNV-…` — judul pesanan", atau catatan super admin |
| `read_at` | `null` = **belum dibaca** |
| `created_at` | Waktu dibuat |

**Hak akses:**
- Pengguna hanya bisa **membaca notifikasi miliknya sendiri**.
- Hanya kolom **`read_at`** yang boleh diubah, untuk menandai sudah dibaca.
- Notifikasi **tidak bisa dibuat atau dihapus dari web/aplikasi**. Notifikasi selalu dibuat otomatis oleh database.

## Kapan notifikasi dibuat

| `type` | Penerima | Kapan |
|---|---|---|
| `project_submitted` | Semua **admin** (role `admin`) | Customer mengirim pesanan baru |
| `approval_requested` | Semua **super admin** | Admin mengirim RAB untuk persetujuan |
| `approval_approved` | Admin penanggung jawab (atau semua admin kalau belum ada) | Super admin menyetujui RAB |
| `approval_correction` | Sama | Super admin meminta koreksi. `body` berisi catatannya |
| `approval_rejected` | Sama | Super admin menolak RAB. `body` berisi alasannya |
| `project_assigned` | Admin tujuan | Penanggung jawab pesanan dipindahkan ke dia |
| `chat_opened` | Semua admin | Customer membuka chat baru |
| `report_ready` | **Customer** | Laporan PDF pesanannya siap (untuk Android) |
| `chat_reply` | **Customer** | Admin membalas chat (untuk Android) |

Tipe baru bisa bertambah nanti. FE sebaiknya menampilkan `title` dan `body` apa adanya, dan memakai `type` **hanya untuk memilih ikon atau warna**, dengan ikon umum sebagai cadangan.

## Contoh pemanggilan

```ts
import { createClient } from "@/lib/supabase/client";
const supabase = createClient();

// 20 notifikasi terbaru
const { data } = await supabase
  .from("notifications")
  .select("id, project_id, type, title, body, read_at, created_at")
  .order("created_at", { ascending: false })
  .limit(20);

// Jumlah belum dibaca (untuk titik/angka di lonceng)
const { count } = await supabase
  .from("notifications")
  .select("id", { count: "exact", head: true })
  .is("read_at", null);

// Tandai satu sudah dibaca
await supabase.from("notifications").update({ read_at: new Date().toISOString() }).eq("id", id);

// Tandai semua sudah dibaca
await supabase.from("notifications").update({ read_at: new Date().toISOString() }).is("read_at", null);
```

Tidak perlu filter `user_id`, karena RLS hanya mengembalikan notifikasi milik pengguna yang login.

## Realtime (muncul tanpa refresh)

Tabel ini sudah termasuk publikasi `supabase_realtime`. Supaya notifikasi baru langsung tampil:

```ts
const channel = supabase
  .channel(`notifikasi-${userId}`)
  .on(
    "postgres_changes",
    { event: "INSERT", schema: "public", table: "notifications", filter: `user_id=eq.${userId}` },
    (payload) => {
      // payload.new = baris notifikasi baru
    },
  )
  .subscribe();

// saat komponen dilepas
supabase.removeChannel(channel);
```

RLS juga berlaku untuk Realtime, jadi pengguna hanya menerima notifikasinya sendiri.

## Klik notifikasi

Kalau `project_id` terisi, arahkan ke detail pesanan `/workplace/pesanan/{project_id}`, lalu tandai notifikasi itu sudah dibaca.

## Belum tersedia

- **Preferensi notifikasi** (memilih jenis notifikasi yang ingin diterima): menyusul
- **Notifikasi email / WhatsApp**: belum. Saat ini notifikasi hanya ada di dalam aplikasi
