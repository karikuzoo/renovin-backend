# Kontrak FE: katalog bahan (`products`, `product_categories`, `product_internal_prices`, bucket `catalog`)

Dipakai halaman **Katalog** (`renovin-web/app/workplace/katalog`): daftar bahan, ringkasan, cari, filter, serta form tambah, edit, dan duplikat bahan. Aplikasi Android membaca tabel yang sama untuk pilihan cat dan furnitur.

Semua pemanggilan memakai client Supabase yang sudah ada (`@/lib/supabase/client`). Tipe TypeScript-nya ada di `types/database.types.ts`. Salin ulang file itu dari repo backend setiap kali kontrak ini berubah.

Kontrak data web admin lainnya: lihat daftar di README repo backend.

## Data

### `products`, satu baris per bahan

| Kolom | Isi |
|---|---|
| `id` | UUID. Boleh dibuat di web (`crypto.randomUUID()`) supaya gambar bisa diupload sebelum baris disimpan |
| `sku` | Kode bahan, unik. Disimpan **huruf besar** tanpa spasi di awal/akhir (trigger). Duplikat SKU → error `23505` |
| `name` | Nama bahan, wajib |
| `category_id` | Kategori (`product_categories`) |
| `type` | `paint` / `furniture` / `material` / `other`. **Harus sama dengan `type` kategorinya**, kalau beda → error `23514`. Isi dari kategori yang dipilih |
| `brand` | Merek, opsional (≤ 80 karakter) |
| `spec` | Spesifikasi singkat satu baris, opsional (≤ 120), contoh `9 mm · 120 × 240 cm` |
| `description` | Keterangan lebih panjang, opsional |
| `unit` | Satuan: `m2`, `pcs`, `lembar`, `sak`, `batang`, … |
| `price_customer` | Harga katalog untuk customer, **wajib** (Q11). Ditampilkan di halaman Katalog |
| `color_name`, `color_hex` | Warna (`#RRGGBB`). **Wajib untuk `paint`**. Satu produk cat = satu warna |
| `width_cm`, `depth_cm`, `height_cm` | Ukuran (cm), > 0. Dipakai furnitur untuk skala di preview Android |
| `image_url`, `image_file_id` | Gambar katalog (lihat bagian Gambar) |
| `asset_url`, `asset_file_id` | PNG transparan untuk compositing furnitur di Android. Opsional di web |
| `status` | `draft` / `published` / `archived` (lihat di bawah) |
| `availability` | `available` (Tersedia) / `indent` (Indent) / `out_of_stock` (Habis) |
| `availability_note` | Catatan ketersediaan, contoh `3–5 hari`. Otomatis dikosongkan kalau `available` |
| `active` | **Jangan diubah.** Turunan dari `status` (= `status = 'published'`), diisi trigger |
| `created_by`, `created_at`, `updated_at` | Diisi otomatis |

### Status

| `status` | Label web | Tampil di aplikasi customer | Arti |
|---|---|---|---|
| `draft` | Draft | Tidak | Sedang disiapkan admin |
| `published` | Terbit | Ya | Bisa dipilih customer |
| `archived` | Arsip | Tidak | Tidak ditawarkan lagi. Pesanan lama yang memakainya tetap utuh |

- Bahan **tidak bisa dihapus**. Pakai `archived`.
- Bahan arsip bisa diterbitkan lagi.
- Bahan yang sudah dipakai di pesanan tetap aman diarsipkan. RAB dan laporan lama tidak berubah.

### `product_categories`

`id, name, slug, type, sort_order, active`. Isi pilihan kategori di form dan filter. Staff boleh menambah kategori, tapi halaman ini cukup **membaca** saja dulu.

### `product_internal_prices`, harga internal (rahasia)

`product_id` (primary key), `price_internal`. **Hanya staff yang bisa membaca.** Customer tidak bisa melihat tabel ini sama sekali. Dipakai `calculate_rab` untuk RAB internal. Tampilkan di form edit, jangan di kartu katalog.

## Siapa boleh apa

| | Customer (Android) | Admin & super admin |
|---|---|---|
| Baca `products` | Hanya `published` | Semua status |
| Tambah / ubah `products` | — | Ya |
| Hapus `products` | — | — (arsipkan) |
| Baca / ubah harga internal | — | Ya |
| Upload gambar bucket `catalog` | — | Ya |

Kalau pengguna tidak berhak, `update` **tidak error** tapi tidak ada baris yang berubah. Pakai `.select()` lalu cek hasilnya kosong.

## Contoh pemanggilan

```ts
import { createClient } from "@/lib/supabase/client";

const supabase = createClient();

// Daftar semua bahan + kategori + harga internal (staff)
const { data: products } = await supabase
  .from("products")
  .select("*, product_categories(name, type), product_internal_prices(price_internal)")
  .order("updated_at", { ascending: false });
// product_internal_prices: objek { price_internal } atau null (relasi satu-satu)

const { data: categories } = await supabase
  .from("product_categories")
  .select("id, name, type")
  .order("sort_order");

// Tambah bahan (status awal draft)
const id = crypto.randomUUID();
const { error } = await supabase.from("products").insert({
  id, sku: "MAT-010", name: "Papan Gypsum 12 mm", category_id, type: "material",
  brand: "Jayaboard", spec: "12 mm · 120 × 240 cm", unit: "lembar",
  price_customer: 98000, status: "draft", availability: "available",
});

// Harga internal: upsert (tambah atau ganti)
await supabase.from("product_internal_prices")
  .upsert({ product_id: id, price_internal: 70000 }, { onConflict: "product_id" });

// Terbitkan / arsipkan
await supabase.from("products").update({ status: "published" }).eq("id", id).select("id");
```

**Duplikat bahan:** buka form tambah dengan isi bahan asal, kecuali `id` (buat baru), `sku` (minta SKU baru), `status` (`draft`), dan gambar (boleh memakai `image_url` yang sama).

## Gambar

- Bucket **`catalog`** (publik), path **`products/<product_id>/<nama-file>`**. JPEG/PNG/WebP, maksimal **5 MB**. Kompres dulu di browser (≤ 1600 px).
- Setelah upload, simpan `image_file_id` = path objek dan `image_url` = URL publik (`storage.from("catalog").getPublicUrl(path)`).
- Ganti gambar: upload file baru, lalu simpan URL baru. Web **tidak** menghapus file lama, karena hasil duplikat bisa memakai file yang sama.
- Kalau simpan bahan gagal setelah upload (misalnya SKU dobel), hapus file yang baru diupload supaya tidak jadi file yatim.

## Error yang perlu ditangani

| Kode | Penyebab | Pesan untuk pengguna |
|---|---|---|
| `23505` | SKU sudah dipakai | "Kode bahan sudah dipakai" |
| `23514` | Nama/SKU kosong, tipe beda dengan kategori, cat tanpa warna, harga/ukuran negatif | Tampilkan `error.message` |

## Belum tersedia

- Banyak varian warna dalam satu produk (sekarang satu warna per produk cat).
- Riwayat harga. Perubahan tercatat di `audit_logs`, tapi belum ada tampilan.
- Stok berupa angka. Untuk sekarang hanya status ketersediaan.
