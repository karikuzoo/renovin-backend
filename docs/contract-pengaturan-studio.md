# Kontrak FE: pengaturan studio (`app_settings` + bucket `branding`)

Dipakai halaman **Pengaturan** (`renovin-web/app/workplace/pengaturan`): bagian profil studio, logo, zona waktu, dan mata uang. Juga bisa dipakai di tempat lain yang menampilkan nama atau logo studio (header laporan, footer).

Semua pemanggilan memakai client Supabase yang sudah ada (`@/lib/supabase/client`). Tipe TypeScript-nya ada di `types/database.types.ts`. Salin ulang file itu dari repo backend setiap kali kontrak ini berubah.

Kontrak data web admin lainnya: lihat daftar di README repo backend.

## Data

Tabel `app_settings` berisi satu baris per pengaturan (`key`), dan isinya ada di kolom `value` (JSON).

| `key` | Isi `value` | Siapa yang boleh mengubah |
|---|---|---|
| `studio_profile` | `{ name, email, phone, website, address, logo_url }`. Semua teks atau `null`. `name` wajib diisi | admin, super admin |
| `locale` | `{ timezone, currency, language }`, misalnya `{ "timezone": "Asia/Jakarta", "currency": "IDR", "language": "id" }` | admin, super admin |
| `tax` | `{ tax_percent }`, angka 0–100. Dipakai `calculate_rab` untuk RAB yang dihitung **setelah** perubahan | **hanya super admin** |

- **Semua pengguna yang login bisa membaca.** Datanya tidak rahasia, jadi aplikasi Android juga bisa menampilkan nama studio.
- Tidak bisa menambah atau menghapus `key`, karena kunci baru hanya dibuat lewat migration. Yang bisa diubah hanya kolom `value`.
- `value` **diganti utuh**. Kirim objek lengkap, bukan sebagian.

## Contoh pemanggilan

```ts
import { createClient } from "@/lib/supabase/client";

const supabase = createClient();

// Baca semua pengaturan sekaligus
const { data: rows } = await supabase.from("app_settings").select("key, value, updated_at");
const settings = Object.fromEntries((rows ?? []).map((r) => [r.key, r.value]));
const profile = settings.studio_profile as {
  name: string; email: string | null; phone: string | null;
  website: string | null; address: string | null; logo_url: string | null;
};

// Simpan profil studio (kirim objek lengkap)
const { error } = await supabase
  .from("app_settings")
  .update({ value: { ...profile, name: "Renovin Studio", phone: "021 7500 2600" } })
  .eq("key", "studio_profile");

// Pajak (khusus super admin)
await supabase.from("app_settings").update({ value: { tax_percent: 11 } }).eq("key", "tax");
```

**Cek hasil update:** kalau pengguna tidak berhak (misalnya admin mengubah `tax`), Supabase **tidak mengembalikan error**, tapi tidak ada baris yang berubah. Supaya terdeteksi, tambahkan `.select()` lalu cek apakah hasilnya kosong:

```ts
const { data, error } = await supabase
  .from("app_settings").update({ value: { tax_percent: 12 } }).eq("key", "tax").select();
if (!error && data?.length === 0) {
  // tampilkan: "Hanya super admin yang bisa mengubah pajak"
}
```

Sembunyikan atau nonaktifkan isian pajak untuk admin biasa. Role pengguna bisa dicek dengan `supabase.rpc("my_role")`.

## Logo studio

Logo diunggah ke bucket **publik** `branding`, dengan path **`studio/<nama-file>`**. Ketentuannya: maksimal **2 MB**, format PNG, JPEG, WebP, atau **SVG**. Hanya admin dan super admin yang bisa mengunggah.

```ts
const path = `studio/logo-${Date.now()}.${file.name.split(".").pop()}`;
const { error: upErr } = await supabase.storage.from("branding").upload(path, file, { contentType: file.type });
const logoUrl = supabase.storage.from("branding").getPublicUrl(path).data.publicUrl;

await supabase.from("app_settings")
  .update({ value: { ...profile, logo_url: logoUrl } })
  .eq("key", "studio_profile");
```

`lib/storage.ts` saat ini hanya mengenal bucket `catalog`, `room-photos`, dan `reports`. Tambahkan `'branding'` ke tipe `Bucket` dan aturannya (`types: ['image/png','image/jpeg','image/webp','image/svg+xml'], maxMb: 2`). Untuk bucket publik, `url` = URL publik, sama seperti `catalog`.

Tampilkan logo dengan `<img src={logo_url}>`, **jangan** dengan `dangerouslySetInnerHTML`. SVG di `<img>` tidak bisa menjalankan script.

## Pesan error (dari validasi database)

| Kondisi | `error.message` |
|---|---|
| Nama studio kosong | Nama studio wajib diisi |
| Email salah format | Format email studio tidak valid |
| Isian bukan teks | Kolom phone pada profil studio harus teks |
| Kolom yang tidak dikenal | Kolom tidak dikenal pada pengaturan studio_profile: … |
| Lokal kosong | Kolom timezone pada pengaturan lokal wajib diisi |
| Pajak di luar 0–100 | Pajak harus angka 0–100 |

Semua error ini memakai kode `23514`, dan pesannya bisa langsung ditampilkan.

## Belum tersedia di halaman Pengaturan

- **Profil admin yang login** (nama, email): nama bisa diubah lewat `profiles` (kolom `full_name`, `phone`, hanya baris milik sendiri). Sinkronisasi email menyusul di poin 6.
- **Preferensi notifikasi**: menyusul.
- **Ganti kata sandi**: pakai `supabase.auth.updateUser({ password })`, tanpa perlu backend tambahan.
