# Kontrak: ganti email login

Siapa yang boleh mengganti email, dan bagaimana caranya, **berbeda untuk staff dan customer**:

| Akun | Dibuat oleh | Ganti email |
|---|---|---|
| **Super admin & admin** (web admin) | Tim IT, lewat Supabase Dashboard | **Hanya tim IT**, lewat Supabase Dashboard. Di web, email admin **hanya bisa dibaca** |
| **Customer** (aplikasi Android) | Customer sendiri, daftar di aplikasi | Customer sendiri dari aplikasi, dengan konfirmasi email (lihat bawah) |

Kontrak data web admin lainnya: lihat daftar di README repo backend.

## Sinkron otomatis ke `profiles` (berlaku untuk semua akun)

Email login ada di **Supabase Auth** (`auth.users`), sedangkan email yang tampil di web/aplikasi (halaman Klien, Pesanan, Pengaturan) ada di **`profiles.email`**.

Trigger database `on_auth_user_email_changed` (migration 014) menyalin email baru ke `profiles` **setiap kali email login berubah**, dari jalur mana pun: Dashboard, aplikasi, atau API. FE **tidak perlu** dan **tidak bisa** mengubah `profiles.email`, karena kolomnya dikunci.

Setiap perubahan `profiles` juga tercatat di `audit_logs`, berisi nilai lama, nilai baru, dan waktu perubahan.

## Staff: ganti email oleh tim IT

**Kenapa staff tidak bisa mengganti sendiri?** Supaya akun studio tidak bisa dipindahkan ke email pribadi oleh admin yang memegangnya. Konfirmasi dua email dari Supabase tidak mencegah hal ini, karena admin itu sendiri yang memegang email lama.

**Langkah (tim IT):**

1. Supabase Dashboard → project yang sesuai → **Authentication → Users**
2. Cari akun staff, lalu buka detailnya dan ubah email-nya
3. `profiles.email` ikut berubah otomatis. Cek di **Table Editor → `profiles`**

Di web admin (`app/workplace/pengaturan`), isian "Email admin" hanya bisa dibaca, dengan keterangan *"Email dipakai untuk masuk dan dikelola tim IT."*

## Customer: ganti email dari aplikasi Android

> Dipakai saat aplikasi Android dikembangkan. Belum ada di web.

### Alur

```
Aplikasi ─► supabase.auth.updateUser({ email: baru })
               │  email BELUM berubah; Supabase mengirim email konfirmasi
               ├─► ke email LAMA  ─ klik link ─┐
               └─► ke email BARU  ─ klik link ─┤  (keduanya wajib, "Secure email change")
                                               ▼
               link konfirmasi (token_hash, type=email_change)
                                               ▼
       auth.users.email berubah ─► trigger ─► profiles.email ikut berubah
```

Email login **tidak langsung berubah** setelah `updateUser`. Email baru baru aktif setelah link di **email lama dan email baru** sama-sama diklik.

### Contoh pemanggilan

```ts
const { error } = await supabase.auth.updateUser({ email: emailBaru.trim() });
if (!error) {
  // "Link konfirmasi sudah dikirim ke email lama dan email baru.
  //  Email baru aktif setelah kedua link diklik."
}

// Status menunggu konfirmasi
const { data: { user } } = await supabase.auth.getUser();
user?.new_email; // email tujuan selama belum dikonfirmasi, null kalau sudah selesai
```

Validasi sebelum memanggil: format email, dan email baru tidak boleh sama dengan email sekarang. Error dari Supabase (email sudah terdaftar, terlalu sering meminta, dan sebagainya) bisa langsung ditampilkan dari `error.message`.

### ⚠️ Yang perlu disiapkan bersama tim Android

Template email saat ini (`supabase/templates/email_change.html`) mengarahkan link ke **web admin**:

```
{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=email_change&next=/workplace/pengaturan
```

Untuk customer, link ini **perlu diganti** sebelum fitur dipakai di aplikasi. Pilihannya:
- **Deep link** ke aplikasi, misalnya `renovin://auth/confirm?token_hash=…&type=email_change`. Aplikasi memanggil `supabase.auth.verifyOtp({ type: "email_change", token_hash })`
- Atau halaman web publik sederhana, misalnya `/konfirmasi-email`, yang memverifikasi token lalu menampilkan "Email berhasil dikonfirmasi, silakan kembali ke aplikasi"

Karena template berlaku untuk **semua akun**, dan staff memang tidak memakai alur ini lagi, template cukup diubah ke tujuan untuk customer.

## Setup Supabase (sekali per project)

1. **Authentication → Emails → Change Email Address**: subject `Konfirmasi perubahan email akun Renovin`, body dari `supabase/templates/email_change.html`. ✅ Sudah dipasang di `renovin-dev`
2. **Authentication → Providers → Email**:
   - **Secure email change**: aktif (bawaan)
   - **Confirm email**: **aktif**, supaya customer yang mendaftar sendiri harus memverifikasi emailnya. Kalau tidak aktif, orang bisa mendaftar dengan email asal-asalan
3. Email dikirim lewat Gmail SMTP yang sama dengan lupa kata sandi (lihat `docs/lupa-password.md`)

## Cara mengetes

Gmail mengirim email untuk `nama+apa-saja@gmail.com` ke kotak masuk `nama@gmail.com`. Contohnya, akun customer uji dengan email Gmail asli bisa diganti ke `nama+tes@gmail.com`, dan kedua email konfirmasi akan masuk ke kotak masuk yang sama.

Akun seed `@renovin.test` **tidak bisa** dipakai, karena domain itu tidak menerima email.
