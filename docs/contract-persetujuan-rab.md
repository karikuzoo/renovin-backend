# Kontrak FE: persetujuan RAB & konfirmasi final

Dipakai halaman **detail pesanan** (`renovin-web/components/order-material-detail-page.tsx`), setelah admin menekan "Kirim untuk persetujuan".

Semua pemanggilan memakai client Supabase yang sudah ada (`@/lib/supabase/client`). Tipe TypeScript-nya ada di `types/database.types.ts`.

Kontrak data web admin lainnya: lihat daftar di README repo backend.

## Alur status

```
admin_processing ─► rab_draft ─► pending_approval ──┬─► approved ─► confirmed ─► report_generated ─► completed
      ▲                 ▲          (super admin)    │      (admin)      (snapshot     (PDF, paket B)
      └──── correction ─┘◄──────────────────────────┤                    final)
                                                    └─► rejected (akhir)
```

| Dari | Ke | Siapa | Catatan wajib? | Efek |
|---|---|---|---|---|
| `pending_approval` | `approved` | **super admin** | Tidak (boleh diisi) | Simpan keputusan + salinan RAB ke `approvals`. Notifikasi ke admin penanggung jawab |
| `pending_approval` | `correction` | **super admin** | **Ya** | Sama. Admin bisa mengedit RAB lagi |
| `pending_approval` | `rejected` | **super admin** | **Ya** | Sama. **Status akhir**, tidak bisa dilanjutkan |
| `correction` | `rab_draft` / `admin_processing` | admin, super admin | Tidak | Admin memperbaiki RAB lalu mengirim ulang (`submitForApproval` di `lib/rab.ts` sudah menangani ini) |
| `approved` | `confirmed` | admin, super admin | Tidak | Membuat **snapshot final** RAB (`rab_snapshots`) yang tidak bisa diubah lagi. RAB terkunci |

- Selama `pending_approval`, **super admin masih bisa mengedit RAB** (`can_edit_rab`), misalnya merapikan sedikit sebelum menyetujui. Admin biasa tidak bisa.
- Setelah `approved`, RAB **terkunci untuk semua orang**.

## Contoh pemanggilan

```ts
// Super admin memutuskan
await supabase.rpc("change_project_status", {
  p_project_id: orderId,
  p_to_status: "approved",          // "approved" | "correction" | "rejected"
  p_note: catatan || undefined,     // WAJIB untuk correction & rejected
});

// Admin (atau super admin) konfirmasi final setelah disetujui
await supabase.rpc("change_project_status", { p_project_id: orderId, p_to_status: "confirmed" });
```

Role pengguna untuk menentukan tombol yang tampil: `supabase.rpc("my_role")`.

| Tombol | Tampil kalau |
|---|---|
| Setujui / Minta koreksi / Tolak | `role === "super_admin"` dan `status === "pending_approval"` |
| Konfirmasi final | role admin atau super admin, dan `status === "approved"` |

## Riwayat keputusan

```ts
const { data: approvals } = await supabase
  .from("approvals")
  .select("id, decision, note, decided_at, decided_by_profile:profiles!approvals_decided_by_fkey(full_name)")
  .eq("project_id", orderId)
  .order("decided_at", { ascending: false });
```

| Kolom | Arti |
|---|---|
| `decision` | `approved` / `correction` / `rejected` |
| `note` | Catatan super admin (selalu ada untuk koreksi dan tolak) |
| `decided_at` | Waktu keputusan |
| `decided_by_profile.full_name` | Nama super admin yang memutuskan |
| `rab_data` | Salinan RAB dan baris-barisnya **saat keputusan diambil** (opsional, untuk melihat versi yang disetujui atau ditolak) |

Hanya staff yang bisa membaca `approvals`. Saat status `correction`, tampilkan **catatan keputusan terakhir** dengan jelas ke admin, karena itulah yang harus diperbaiki.

## Pesan error

| Kondisi | `error.message` |
|---|---|
| Admin biasa menekan Setujui/Tolak | Perubahan status pending_approval → approved tidak diizinkan untuk role admin |
| Koreksi/tolak tanpa catatan | Catatan wajib diisi untuk status correction |
| Konfirmasi saat RAB kosong | RAB belum dihitung atau masih kosong |
| Status sudah berubah (misalnya dua orang menekan bersamaan) | Perubahan status … tidak diizinkan untuk role … |

Pesan-pesan ini bisa langsung ditampilkan. Setelah error, muat ulang data pesanan, karena status mungkin sudah diubah orang lain.

## Setelah `confirmed`

Langkah berikutnya, yaitu membuat **laporan PDF** (`report_generated`) lalu **selesai** (`completed`), adalah paket B. Untuk sekarang, tampilkan keterangan "RAB sudah dikonfirmasi final. Laporan PDF menyusul."
