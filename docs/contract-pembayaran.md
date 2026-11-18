# Kontrak FE: skema pembayaran (`payment_plans`, `payment_installments`, `order_payment_summary`)

Dipakai **web admin** (panel "Skema pembayaran" di detail pesanan, kolom Pembayaran di Daftar Pesanan, angka pembayaran di Laporan) dan **aplikasi Android** (klien memilih skema dan melihat jadwal pembayarannya).

**Aplikasi tidak memproses uang.** Tidak ada payment gateway. Yang dicatat hanya skema yang disepakati dan pembayaran mana yang sudah diterima studio. Penandaannya dilakukan admin.

Semua penulisan lewat **RPC**. Tabel hanya bisa dibaca (RLS sama dengan data project). Tipe TypeScript ada di `types/database.types.ts`.

Kontrak data lainnya: lihat daftar di README repo backend.

## Aturan (decisions Q16)

| Skema | `scheme` | Jumlah baris | Aturan |
|---|---|---|---|
| Lunas | `full` | 1 | 100% |
| DP + pelunasan | `dp` | 2 | DP ≥ 30% |
| Termin | `termin` | 2–4 | Pembayaran pertama ≥ 30%. **Setiap baris wajib `due_date`**, urut naik |
| Progress | `progress` | 2–4 | Pembayaran pertama ≥ 30%. **Setiap baris wajib `milestone`** (teks tahap pekerjaan) |

- Total persen semua baris **harus 100**, paling banyak 2 angka di belakang koma.
- **Sebelum konfirmasi final:** yang disimpan hanya persen. Nominal = persen × total RAB terbaru, jadi otomatis ikut berubah kalau RAB dikoreksi.
- **Konfirmasi final (`confirmed`) mewajibkan skema yang valid.** Kalau belum ada, `change_project_status(..., 'confirmed')` gagal dengan pesan "Skema pembayaran belum ditetapkan admin". Saat itu juga skema **dikunci**: `total_amount` dan `amount` tiap baris dibekukan, dibulatkan ke rupiah, dan baris terakhir menampung sisa pembulatan.
- Setelah dikunci, skema **tidak bisa diubah**. Yang bisa diubah hanya tanda sudah dibayar.
- **Tanda "sudah dibayar" hanya setelah dikunci.**

## Alur

1. **Klien (Android)** memilih skema yang diinginkan, opsional dengan catatan: `request_payment_scheme`. Bisa sampai pesanan dikonfirmasi.
2. **Admin (web)** menetapkan skema dan barisnya di detail pesanan: `save_payment_plan`. Bisa sejak pesanan diterima (`admin_processing`) sampai `approved`. Permintaan klien ditampilkan sebagai acuan.
3. **Konfirmasi final** mengunci skema, dan skema ikut tercetak di **laporan PDF**.
4. **Admin** menandai baris yang sudah dibayar: `set_installment_paid`. Klien mendapat notifikasi `payment_recorded`.

Pesanan lama yang sudah melewati konfirmasi sebelum fitur ini ada (`confirmed` / `report_generated` / `completed` tanpa skema): `save_payment_plan` tetap boleh dipanggil, dan skema langsung dikunci dari total RAB.

## Data

### `payment_plans`, satu baris per pesanan (bisa belum ada)

| Kolom | Isi |
|---|---|
| `project_id` | Pesanan |
| `requested_scheme`, `requested_note`, `requested_at` | Permintaan klien |
| `scheme` | Skema yang ditetapkan admin. `null` = belum ditetapkan |
| `total_amount` | Total RAB yang dibekukan. `null` sebelum dikunci |
| `locked_at` | Waktu dikunci (saat konfirmasi final). `null` = belum dikunci |

### `payment_installments`, 1–4 baris per pesanan

| Kolom | Isi |
|---|---|
| `id`, `seq` | Urutan 1–4 |
| `label` | "DP", "Pelunasan", "Termin 2", "Tahap 1", atau label dari admin |
| `percent` | Persen dari total RAB |
| `due_date` | Tanggal jatuh tempo (termin; opsional untuk skema lain) |
| `milestone` | Tahap pekerjaan (progress; opsional untuk skema lain) |
| `amount` | Nominal yang dibekukan. `null` sebelum dikunci, jadi hitung `percent × total RAB` |
| `paid_at` | Tanggal pembayaran diterima. `null` = belum dibayar |
| `paid_note`, `paid_recorded_by`, `paid_recorded_at` | Catatan dan siapa yang mencatat |

### View `order_payment_summary`, satu baris per pesanan

`project_id, requested_scheme, scheme, locked_at, total_amount, installment_count, paid_count, paid_amount, payment_status, next_label, next_due_date`

| `payment_status` | Label web | Arti |
|---|---|---|
| `no_plan` | Belum ada skema | Admin belum menetapkan skema |
| `planned` | Skema disiapkan | Skema ada, belum dikunci |
| `unpaid` | Belum bayar | Sudah dikunci, belum ada yang dibayar |
| `partial` | Sebagian | Sebagian baris sudah dibayar |
| `paid` | Lunas | Semua baris sudah dibayar |

`total_amount` di view: total terkunci, atau total RAB terbaru sebelum dikunci. **Untuk klien** nilainya `null` sebelum dikunci, karena RAB hanya bisa dibaca staff.

## Contoh pemanggilan

```ts
// Klien (Android): minta skema
await supabase.rpc("request_payment_scheme", { p_project_id, p_scheme: "dp", p_note: "DP 30% dulu" });

// Admin: tetapkan skema (mengganti semua baris). Label boleh dikosongkan, nanti diisi otomatis.
const { error } = await supabase.rpc("save_payment_plan", {
  p_project_id,
  p_scheme: "termin",
  p_installments: [
    { percent: 40, due_date: "2026-12-01" },
    { percent: 30, due_date: "2027-01-05" },
    { percent: 30, due_date: "2027-02-05" },
  ],
});
// error.message berisi alasan yang bisa langsung ditampilkan, mis. "Pembayaran pertama minimal 30%"

// Baca skema + baris
const { data: plan } = await supabase.from("payment_plans").select("*").eq("project_id", p_project_id).maybeSingle();
const { data: rows } = await supabase.from("payment_installments").select("*").eq("project_id", p_project_id).order("seq");

// Admin: tandai sudah dibayar (tanggal default hari ini WIB, tidak boleh di masa depan) / batalkan
await supabase.rpc("set_installment_paid", { p_installment_id, p_paid: true, p_paid_at: "2026-11-18", p_note: "Transfer BCA" });
await supabase.rpc("set_installment_paid", { p_installment_id, p_paid: false });

// Ringkasan untuk daftar pesanan / laporan
const { data: summaries } = await supabase.from("order_payment_summary").select("*").in("project_id", ids);
```

## Error

Semua penolakan memakai `error.message` berbahasa Indonesia yang siap ditampilkan:

- `23514`: aturan skema dilanggar
- `42501`: tidak berhak, atau status pesanan tidak mengizinkan
- `P0002`: data tidak ditemukan

## Belum tersedia

- Transaksi atau payment gateway. Memang tidak direncanakan.
- Pembayaran sebagian dalam satu baris. Satu baris dianggap dibayar penuh.
- Tahap produksi terstruktur untuk skema progress. Untuk sekarang teks bebas di `milestone`.
- Mengubah skema setelah konfirmasi final. Ini terkait revisi RAB (Q10).
