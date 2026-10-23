# Kontrak FE: ganti email login

Dipakai halaman **Pengaturan** (`renovin-web/app/workplace/pengaturan`), di kartu **Profil admin** pada isian "Email admin". Nantinya juga bisa dipakai aplikasi Android untuk customer.

Kontrak data web admin lainnya: lihat daftar di README repo backend.

## Alur

```
Pengaturan ─► supabase.auth.updateUser({ email: baru })
                 │  email BELUM berubah; Supabase mengirim email konfirmasi
                 ├─► ke email LAMA  ─ klik link ─┐
                 └─► ke email BARU  ─ klik link ─┤  (keduanya wajib diklik, "Secure email change")
                                                 ▼
         renovin-web /auth/confirm?token_hash=…&type=email_change&next=/workplace/pengaturan
                 │  verifikasi token di server
                 ▼
         auth.users.email berubah ─► trigger database ─► profiles.email ikut berubah
```

- Email login **tidak langsung berubah** setelah `updateUser`. Email baru baru aktif setelah **link di email lama dan email baru sama-sama diklik**. Ini setelan bawaan Supabase ("Secure email change"), supaya orang yang meminjam laptop yang sedang login tidak bisa memindahkan akun ke email miliknya.
- `profiles.email` (yang tampil di halaman Klien, Pesanan, dan Pengaturan) diperbarui **otomatis oleh database**. FE tidak perlu mengubah `profiles`, dan memang tidak bisa, karena kolom `email` dikunci.

## Contoh pemanggilan

```ts
import { createClient } from "@/lib/supabase/client";

const supabase = createClient();

const { error } = await supabase.auth.updateUser({ email: emailBaru.trim() });
if (error) {
  // tampilkan error.message, misalnya email sudah dipakai akun lain
} else {
  // tampilkan: "Link konfirmasi sudah dikirim ke email lama dan email baru.
  //            Email baru aktif setelah kedua link diklik."
}
```

**Menampilkan status "menunggu konfirmasi":** selama belum dikonfirmasi, `user.new_email` berisi email tujuan:

```ts
const { data: { user } } = await supabase.auth.getUser();
if (user?.new_email) {
  // tampilkan: "Menunggu konfirmasi ke {user.new_email}"
}
```

## Setelah link diklik

Link di email mengarah ke `/auth/confirm?token_hash=…&type=email_change&next=/workplace/pengaturan`. Route `app/auth/confirm/route.ts` yang sudah ada **langsung bisa dipakai**: untuk tipe selain `recovery`, ia memverifikasi token lalu mengarahkan ke `next`.

- Link **pertama** yang diklik (lama atau baru) hanya mencatat konfirmasi itu. Email **belum** berubah.
- Link **kedua** yang diklik mengubah email.

Saran tampilan: di halaman Pengaturan, panggil ulang `supabase.auth.getUser()` saat halaman dibuka. Kalau `new_email` sudah kosong dan `email` sudah berganti, berarti perubahan berhasil.

## Validasi di FE (sebelum memanggil)

| Cek | Pesan |
|---|---|
| Format email salah | "Format email tidak valid" |
| Sama dengan email sekarang | "Email baru sama dengan email sekarang" |

Error dari Supabase (misalnya email sudah terdaftar, atau terlalu sering meminta) bisa langsung ditampilkan dari `error.message`.

## Setup (sekali per project Supabase, oleh backend)

1. **Dashboard → Authentication → Emails → Change Email Address**
   - Subject: `Konfirmasi perubahan email akun Renovin`
   - Body: salin seluruh isi `supabase/templates/email_change.html`
2. **Dashboard → Authentication → Providers → Email**: pastikan **Secure email change** aktif (bawaan: aktif).
3. Email dikirim lewat Gmail SMTP yang sama dengan email lupa kata sandi (lihat `docs/lupa-password.md`).

## Cara mengetes tanpa email baru

Gmail mengirim email untuk `nama+apa-saja@gmail.com` ke kotak masuk `nama@gmail.com`. Jadi akun `superadmin.simpen@gmail.com` bisa dites dengan mengganti ke `superadmin.simpen+tes@gmail.com`. Kedua email konfirmasi akan masuk ke kotak masuk yang sama. Setelah tes, ganti kembali ke email semula dengan cara yang sama.

Akun seed `@renovin.test` **tidak bisa** dipakai untuk tes ini, karena domain itu tidak bisa menerima email.
