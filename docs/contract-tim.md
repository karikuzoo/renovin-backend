# Kontrak FE: tim studio (`profiles` + `admin_orders`)

Dipakai halaman **Tim** (`renovin-web/app/workplace/tim`): daftar admin dan super admin, berapa pesanan yang sedang mereka tangani, dan pesanan aktif per penanggung jawab.

**Tidak ada tabel atau view baru.** Halaman ini cukup menggabungkan dua sumber yang sudah ada. Semua pemanggilan memakai client Supabase yang sudah ada (`@/lib/supabase/client`).

Kontrak data web admin lainnya: lihat daftar di README repo backend.

## Batasan

- **Hanya akun staff** (`profiles.role` = `admin` / `super_admin`). Pekerja lapangan (tukang, teknisi) belum ada di database dan masih ditahan.
- **Akun dibuat dan dikelola tim IT** lewat Supabase Dashboard (Q14). Web tidak punya tombol "Tambah anggota", "Nonaktifkan", atau "Ubah peran".
- **Penanggung jawab dipindah dari detail pesanan** (tombol *Ganti*, fungsi `assign_project`, Q12). Halaman Tim hanya menampilkan.
- Belum ada data jabatan, keahlian, jadwal, atau persentase alokasi.

## Data

### Anggota: `profiles`

```ts
const { data: staff } = await supabase
  .from("profiles")
  .select("id, full_name, email, phone, role, created_at")
  .in("role", ["admin", "super_admin"])
  .order("full_name");
```

Staff bisa membaca semua `profiles` (RLS). Customer hanya bisa membaca profilnya sendiri, jadi query ini mengembalikan 0 baris untuk customer.

### Beban kerja: `admin_orders`

```ts
const { data: orders } = await supabase
  .from("admin_orders")
  .select("id, code, title, status, status_group, assigned_admin_id, customer_name, order_value, updated_at");
```

Staff bisa melihat **semua** pesanan, termasuk yang ditangani admin lain. Hitung per anggota di web:

| Angka | Rumus |
|---|---|
| Pesanan aktif | `status_group = 'in_progress'` dan `assigned_admin_id = anggota` |
| Perlu tindakan admin | aktif dengan `status` `admin_processing`, `rab_draft`, `correction`, `approved`, `confirmed`, atau `report_generated` |
| Menunggu super admin | aktif dengan `status = 'pending_approval'` |
| Selesai | `status_group = 'done'` dan `assigned_admin_id = anggota` |
| Terakhir aktif | `updated_at` terbaru dari pesanan anggota (perkiraan, bukan waktu login) |

Pesanan `new` (`sent_to_admin`) belum punya penanggung jawab. Admin yang menerima pesanan otomatis menjadi penanggung jawabnya.

Jumlah pesanan masih kecil, jadi semua baris diambil sekaligus. Kalau nanti lebih dari ~1.000 pesanan, backend akan menambah view ringkasan per admin.
