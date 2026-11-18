# Kontrak FE: tarif jasa (`service_rates`)

Dipakai tab **"Harga & pajak"** di halaman **Pengaturan** (`renovin-web/app/workplace/pengaturan`), bersama isian pajak (`contract-pengaturan-studio.md`).

Semua pemanggilan memakai client Supabase yang sudah ada (`@/lib/supabase/client`). Tipe TypeScript-nya ada di `types/database.types.ts`.

Kontrak data web admin lainnya: lihat daftar di README repo backend.

## Data

Tabel `service_rates`, satu baris per jenis jasa:

| Kolom | Isi |
|---|---|
| `id` | UUID |
| `code` | Kode unik, disimpan huruf besar (contoh `JASA-CAT`). Duplikat → error `23505` |
| `name` | Nama jasa yang tampil di RAB dan PDF (contoh "Jasa pengecatan") |
| `calc_type` | `per_m2`: luas × tarif. `flat`: 1 paket × tarif |
| `applies_to` | Khusus `per_m2`: luas diambil dari item RAB dengan tipe produk ini (`paint` / `furniture` / `material` / `other`). **Wajib** untuk `per_m2`, otomatis `null` untuk `flat` |
| `rate` | Tarif (rupiah), ≥ 0 |
| `active` | `false` = tidak dipakai lagi untuk RAB baru. **Tarif tidak bisa dihapus**, cukup dinonaktifkan |

## Cara dipakai di RAB

`calculate_rab` membuat **baris jasa otomatis** dari semua tarif yang **aktif**:

- `flat`: ditambahkan sekali, asalkan RAB punya minimal satu item.
- `per_m2`: kuantitas = total luas item bertipe `applies_to`. Ditambahkan hanya kalau item bertipe itu ada.

Perubahan tarif **hanya berlaku untuk RAB yang dihitung setelahnya**. RAB yang sudah ada tidak berubah sampai admin menekan "Hitung dari desain" lagi. RAB yang sudah dikonfirmasi final tidak berubah sama sekali.

## Siapa boleh apa (Q17)

| | Customer | Admin | Super admin |
|---|---|---|---|
| Baca | Hanya yang aktif | Semua | Semua |
| Tambah / ubah / nonaktifkan | — | — | ✓ |
| Hapus | — | — | — (nonaktifkan) |

Kalau admin mencoba `update`, Supabase **tidak mengembalikan error**, tapi tidak ada baris yang berubah. Pakai `.select()` lalu cek hasilnya kosong. Sembunyikan atau nonaktifkan isian untuk admin biasa.

## Contoh pemanggilan

```ts
const { data: rates } = await supabase
  .from("service_rates")
  .select("id, code, name, calc_type, applies_to, rate, active")
  .order("active", { ascending: false })
  .order("name");

// Tambah (super admin)
await supabase.from("service_rates").insert({
  code: "JASA-BONGKAR", name: "Jasa bongkar", calc_type: "flat", rate: 300000,
});

// Ubah tarif / nonaktifkan (super admin)
const { data, error } = await supabase
  .from("service_rates").update({ rate: 27500 }).eq("id", id).select("id");
if (!error && data?.length === 0) { /* bukan super admin */ }
```

## Error

| Kode | Penyebab |
|---|---|
| `23505` | Kode sudah dipakai |
| `23514` | Nama/kode kosong, tarif negatif, atau `per_m2` tanpa `applies_to` |
| `42501` | Bukan super admin (insert) |
