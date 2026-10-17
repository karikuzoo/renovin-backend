# Kontrak FE: pindah penanggung jawab pesanan (`assign_project`)

Dipakai di halaman **detail pesanan** (bagian "Diterima …" pada kartu klien) dan nantinya halaman **Tim**.

Semua pemanggilan memakai client Supabase yang sudah ada (`@/lib/supabase/client`). Tipe TypeScript-nya ada di `types/database.types.ts`. Salin ulang file itu dari repo backend setiap kali kontrak ini berubah.

Kontrak data web admin lainnya: lihat daftar di README repo backend.

## Aturan

| Siapa | Boleh |
|---|---|
| `super_admin` | Memindahkan **semua** pesanan ke admin/super admin mana pun |
| `admin` | Hanya **menyerahkan pesanan yang sedang ia tangani** (`assigned_admin_id` = dirinya) |
| `customer` / belum login | Tidak boleh |

- Admin tujuan harus berrole `admin` atau `super_admin`.
- Tidak berlaku untuk pesanan yang **belum dikirim** (`draft`, `ready_to_submit`) maupun yang **sudah selesai atau ditolak** (`completed`, `rejected`).
- **Status pesanan tidak berubah.** Pesanan baru (`sent_to_admin`) yang ditunjuk ke seorang admin tetap ada di tab "Baru" sampai diterima.
- Setiap perpindahan dicatat di `audit_logs`, dan admin tujuan menerima notifikasi `project_assigned` ("Pesanan dialihkan ke Anda"), kecuali kalau ia menunjuk dirinya sendiri.

Aturan ini masih **asumsi** (lihat `docs/decisions.md` Q12). Kalau tim ingin admin biasa juga bisa mengambil alih pesanan admin lain, cukup backend yang diubah.

## Contoh pemanggilan

```ts
import { createClient } from "@/lib/supabase/client";

const supabase = createClient();

// 1. Daftar pilihan admin untuk dropdown
const { data: staff } = await supabase
  .from("profiles")
  .select("id, full_name, role")
  .in("role", ["admin", "super_admin"])
  .order("full_name");

// 2. Pindahkan penanggung jawab
const { data: project, error } = await supabase.rpc("assign_project", {
  p_project_id: orderId,
  p_admin_id: selectedAdminId,
});
if (error) {
  // tampilkan error.message ke admin (pesannya sudah berbahasa Indonesia)
}
```

Fungsi ini mengembalikan baris `projects` yang sudah diperbarui. Setelah berhasil, muat ulang data dari `admin_orders`, karena `assigned_admin_name` sudah ikut berubah.

## Kapan tombol "Ganti penanggung jawab" ditampilkan

Supaya admin tidak menekan tombol yang pasti ditolak, tampilkan tombol hanya jika:

```ts
const role = (await supabase.rpc("my_role")).data; // "admin" | "super_admin" | "customer"
const statusBoleh = !["draft", "ready_to_submit", "completed", "rejected"].includes(order.status);
const bolehPindah =
  statusBoleh &&
  (role === "super_admin" || (role === "admin" && order.assigned_admin_id === currentUserId));
```

Pengecekan ini hanya untuk tampilan. Keputusan akhirnya tetap di backend.

## Pesan error

| Kondisi | `error.message` | `error.code` |
|---|---|---|
| Belum login | Harus login | `28000` |
| Bukan admin/super admin | Hanya admin atau super admin yang boleh memindahkan penanggung jawab | `42501` |
| Admin memindahkan pesanan orang lain | Admin hanya bisa menyerahkan pesanan yang sedang ia tangani | `42501` |
| Tujuan bukan admin | Penanggung jawab baru harus akun admin atau super admin | `23514` |
| Pesanan draft | Pesanan belum dikirim klien | `23514` |
| Pesanan selesai/ditolak | Penanggung jawab tidak bisa diubah untuk pesanan yang sudah selesai atau ditolak | `23514` |
| ID pesanan salah | Project tidak ditemukan | `P0002` |

Memilih admin yang sama dengan penanggung jawab sekarang **bukan error**. Fungsi langsung mengembalikan data tanpa perubahan.
