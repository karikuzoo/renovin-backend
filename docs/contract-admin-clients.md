# Kontrak FE: daftar klien (`admin_clients`)

Dipakai halaman **Klien** (`renovin-web/app/workplace/klien`): kartu ringkasan, tab Semua / Aktif / Baru, tabel daftar klien, dan panel "Profil klien" + "Proyek terkait".

Semua pemanggilan memakai client Supabase yang sudah ada (`@/lib/supabase/client` atau `@/lib/supabase/server`). Tipe TypeScript-nya ada di `types/database.types.ts`. Salin ulang file itu dari repo backend setiap kali kontrak ini berubah.

Kontrak data web admin lainnya: lihat daftar di README repo backend.

Satu baris = satu customer yang **pernah mengirim pesanan**. Customer yang baru mendaftar atau hanya punya draft belum dianggap klien, jadi tidak muncul.

Angka-angkanya dihitung dari [`admin_orders`](contract-admin-orders.md), jadi selalu cocok dengan halaman Pesanan.

**Siapa yang bisa membaca:** hanya `admin` dan `super_admin`. Customer yang memanggil view ini selalu mendapat **daftar kosong** (bukan error). Pengguna yang belum login mendapat error `permission denied`.

## Contoh pemanggilan

```ts
import { createClient } from "@/lib/supabase/client";

const supabase = createClient();

// Tab "Semua", klien dengan pesanan terbaru di atas
const { data, count } = await supabase
  .from("admin_clients")
  .select("*", { count: "exact" })
  .order("last_order_at", { ascending: false });

// Tab "Aktif" / "Baru"
await supabase.from("admin_clients").select("*").eq("client_status", "active");
await supabase.from("admin_clients").select("*").eq("client_status", "new");

// Pencarian "Cari nama atau kontak"
const keyword = "budi";
await supabase
  .from("admin_clients")
  .select("*")
  .or(`full_name.ilike.%${keyword}%,email.ilike.%${keyword}%,phone.ilike.%${keyword}%`);

// Panel profil satu klien
await supabase.from("admin_clients").select("*").eq("id", customerId).single();

// Semua pesanan milik klien ini (riwayat proyek)
await supabase
  .from("admin_orders")
  .select("*")
  .eq("customer_id", customerId)
  .order("submitted_at", { ascending: false });
```

## Kolom

| Kolom | Tipe | Arti |
|---|---|---|
| `id` | uuid | ID customer (= `profiles.id`). Sama dengan `customer_id` di `admin_orders` |
| `full_name` | text \| null | Nama klien |
| `email` | text \| null | Email klien |
| `phone` | text \| null | Nomor HP klien |
| `registered_at` | timestamptz | Kapan akun dibuat di aplikasi |
| `client_since` | timestamptz | Kapan pesanan **pertama** dikirim. Dipakai untuk "Klien sejak …" |
| `client_status` | `client_status` | `active`, `new`, `done`, `inactive` (lihat tabel di bawah) |
| `order_count` | number | Jumlah pesanan **tanpa** yang ditolak |
| `active_order_count` | number | Pesanan yang sedang dikerjakan |
| `new_order_count` | number | Pesanan baru yang belum diambil admin |
| `done_order_count` | number | Pesanan selesai |
| `rejected_order_count` | number | Pesanan yang ditolak super admin |
| `total_order_value` | number | Jumlah nilai RAB dari `order_count`. Pesanan yang belum punya RAB dihitung 0 |
| `last_order_at` | timestamptz | Kapan pesanan terakhir dikirim |
| `related_order_id` | uuid | Pesanan untuk kolom/kartu **"Proyek terkait"** (lihat aturan di bawah) |
| `related_order_code` | text | Nomor pesanan, misalnya `RNV-2610-00003` |
| `related_order_title` | text | Judul proyek |
| `related_order_status` | `project_status` | Status detail. Label badge-nya ada di [contract-admin-orders.md](contract-admin-orders.md#kelompok-status-tab) |
| `related_order_status_group` | `order_status_group` | `new` / `in_progress` / `done` / `rejected` |
| `related_order_value` | number \| null | Nilai RAB proyek itu. `null` = belum dihitung |
| `related_order_admin_name` | text \| null | Admin penanggung jawab. `null` = belum diambil admin |

> **Semua kolom view bertipe `… | null` di TypeScript.** Ini aturan umum Supabase untuk view. Kolom yang benar-benar bisa `null` hanya yang ditandai di tabel di atas.

### Status klien

| `client_status` | Label yang disarankan | Artinya |
|---|---|---|
| `active` | Proyek aktif | Punya minimal satu pesanan yang sedang dikerjakan |
| `new` | Klien baru | Punya pesanan baru yang belum diambil admin, dan **tidak ada** yang sedang dikerjakan |
| `done` | Selesai | Semua pesanannya (selain yang ditolak) sudah selesai |
| `inactive` | Tidak aktif | Semua pesanannya ditolak |

Urutan pengecekannya dari atas: klien yang punya pesanan dikerjakan **dan** pesanan baru tetap dihitung `active`.

### Proyek terkait

`related_order_*` berisi **satu** pesanan yang paling relevan untuk klien itu. Prioritasnya: dikerjakan → baru → selesai → ditolak. Kalau ada beberapa dalam kelompok yang sama, diambil yang paling akhir dikirim. Jadi klien yang aktif selalu menampilkan proyek aktifnya, bukan pesanan baru yang belum diproses.

## Kartu ringkasan di halaman Klien

Data klien saat ini masih sedikit, jadi kartu bisa dihitung dari hasil daftar (`data`) di sisi FE:

| Kartu | Hitungan |
|---|---|
| Total klien | `data.length` (atau `count`) |
| Klien proyek aktif | `data.filter(c => c.client_status === "active")`, nama-namanya dari `full_name` |
| Klien baru | `data.filter(c => c.client_status === "new")` |
| Nilai hubungan klien | jumlah `total_order_value` semua klien. Hasilnya sama dengan `total_order_value` di [`dashboard_summary`](contract-dashboard-summary.md) |

## Aksi

| Tombol | Panggilan |
|---|---|
| "Hubungi klien" | Chat: tabel `conversations` dan `messages` |
| "Ubah profil" | ❌ Belum tersedia. Admin belum boleh mengubah profil customer (menunggu keputusan tim: data apa saja yang boleh diubah admin). Sembunyikan atau nonaktifkan tombolnya dulu |
| "Ekspor data" | Bisa dibuat di FE dari hasil daftar, misalnya diekspor ke CSV |

## Contoh hasil

```json
{
  "id": "00000000-0000-4000-a000-000000000003",
  "full_name": "Budi Santoso",
  "email": "customer1@renovin.test",
  "phone": "081200000003",
  "registered_at": "2026-10-05T10:00:00+00:00",
  "client_since": "2026-10-11T03:15:00+00:00",
  "client_status": "active",
  "order_count": 2,
  "active_order_count": 1,
  "new_order_count": 1,
  "done_order_count": 0,
  "rejected_order_count": 0,
  "total_order_value": 6210450,
  "last_order_at": "2026-10-13T03:15:00+00:00",
  "related_order_id": "…",
  "related_order_code": "RNV-2610-00003",
  "related_order_title": "Ruang keluarga minimalis",
  "related_order_status": "rab_draft",
  "related_order_status_group": "in_progress",
  "related_order_value": 6210450,
  "related_order_admin_name": "Admin Renovin"
}
```

## Belum tersedia

Bagian di desain halaman Klien berikut **belum ada datanya**. Tetap pakai data contoh atau sembunyikan dulu:

- Kota/alamat klien ("Jakarta Selatan", "Cipete, Jakarta Selatan"). Kolomnya akan ditambahkan bersama data pesanan, dan nantinya diisi dari aplikasi Android
- Jenis klien perorangan/perusahaan ("5 perorangan · 1 perusahaan") 🔒
- "Preferensi & catatan" klien
- Progres % dan target selesai di "Proyek terkait" 🔒
- Status pembayaran ("DP 50%") 🔒
- "Ubah profil" oleh admin
