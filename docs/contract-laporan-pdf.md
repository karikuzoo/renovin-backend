# Kontrak FE: laporan PDF RAB & selesaikan pesanan

Dipakai halaman **detail pesanan** setelah RAB **dikonfirmasi final** (lanjutan dari `contract-persetujuan-rab.md`). Laporan PDF yang sama nantinya diunduh customer di aplikasi Android.

Kontrak data web admin lainnya: lihat daftar di README repo backend.

## Alur

```
confirmed ──[Buat laporan PDF]──► report_generated ──[Tandai selesai]──► completed
             edge function            │  ▲
             generate-report          └──┘ [Buat ulang PDF] (status tetap)
```

| Langkah | Siapa | Panggilan | Hasil |
|---|---|---|---|
| Buat laporan PDF | admin, super admin | `functions.invoke('generate-report', { body: { project_id } })` | PDF dibuat dari **snapshot final**, disimpan di bucket `reports`, dicatat di tabel `reports`, lalu status menjadi `report_generated`. Customer mendapat notifikasi `report_ready` |
| Buat ulang PDF | admin, super admin | Sama, saat status `report_generated` | PDF lama diganti (misalnya setelah logo atau alamat studio berubah). Status tetap |
| Tandai selesai | admin, super admin | `rpc('change_project_status', { p_project_id, p_to_status: 'completed' })` | Status menjadi `completed`. Pesanan pindah ke tab "Selesai" |

## Isi PDF

- **Kop:** logo studio (PNG/JPG; kalau SVG atau tidak ada, dipakai nama studio), alamat, telepon, email, dan situs web dari Pengaturan
- **Judul:** "Rencana Anggaran Biaya (RAB)", nomor pesanan, versi snapshot, dan tanggal konfirmasi
- **Klien:** nama, telepon, email. **Proyek:** judul, jenis ruangan, luas terukur
- **Tabel:** bahan & furnitur, lalu jasa. Kolomnya jumlah, satuan, harga satuan, dan subtotal
- **Ringkasan:** total bahan, total jasa, penyesuaian (beserta alasannya), pajak, dan **TOTAL**
- Nomor halaman dan waktu pembuatan (zona waktu dari Pengaturan)

**Hanya harga customer** yang ditampilkan. Harga internal dan catatan internal admin (`rabs.notes`) **tidak pernah** masuk ke PDF.

Isi PDF selalu diambil dari **snapshot final**, bukan dari RAB yang sedang berjalan. Jadi PDF yang dibuat ulang tetap sama angkanya. Yang bisa berbeda hanya kop studio.

## Contoh pemanggilan

```ts
// Buat / buat ulang laporan
const { data, error } = await supabase.functions.invoke("generate-report", {
  body: { project_id: orderId },
});
// data: { report_id, path, generated_at, signed_url, status: "report_generated" }
// signed_url berlaku 1 jam, bisa langsung dibuka: window.open(data.signed_url)

// Laporan yang sudah ada (untuk tombol "Unduh PDF")
const { data: report } = await supabase
  .from("reports")
  .select("id, pdf_url, generated_at")
  .eq("project_id", orderId)
  .order("generated_at", { ascending: false })
  .limit(1)
  .maybeSingle();

const { data: signed } = await supabase.storage
  .from("reports")
  .createSignedUrl(report.pdf_url, 60 * 60, { download: `RAB-${orderCode}.pdf` });
// signed.signedUrl -> unduh

// Tandai selesai
await supabase.rpc("change_project_status", { p_project_id: orderId, p_to_status: "completed" });
```

`pdf_url` berisi **path** di bucket privat `reports` (`<project_id>/laporan-rab-<kode>-v<versi>.pdf`), bukan URL. Selalu buat signed URL saat mau dibuka.

**Error dari `functions.invoke`:** pesan dari function ada di `error.context`. Cara membacanya:

```ts
if (error) {
  const body = await error.context?.json?.().catch(() => null);
  const pesan = body?.error ?? error.message;
}
```

## Kapan tombol tampil

| Tombol | Status | Role |
|---|---|---|
| Buat laporan PDF | `confirmed` | admin, super admin |
| Unduh PDF, Buat ulang PDF, Tandai selesai | `report_generated` | admin, super admin |
| Unduh PDF | `completed` | admin, super admin |

## Pesan error (`error`)

| Kondisi | Pesan | HTTP |
|---|---|---|
| Belum login / sesi habis | Harus login / Sesi login tidak valid | 401 |
| Bukan staff | Hanya admin atau super admin yang bisa membuat laporan | 403 |
| ID salah / pesanan tidak ada | project_id tidak valid / Pesanan tidak ditemukan | 400 / 404 |
| Status belum `confirmed` | Laporan hanya bisa dibuat setelah RAB dikonfirmasi final | 409 |
| Gagal simpan file / catat | Gagal menyimpan PDF: … / Gagal mencatat laporan: … | 500 |

## Setup (backend)

- Deploy: `npm run functions:deploy` (men-deploy semua function, termasuk `generate-report`)
- Secret `ALLOWED_ORIGINS` sama dengan yang sudah ada untuk `request-password-reset`
- `verify_jwt = false` di `supabase/config.toml`, karena function memverifikasi login sendiri lewat `auth.getUser()`
