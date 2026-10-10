# Lupa password (admin web)

Fitur ini memungkinkan **admin dan super admin** mengatur ulang kata sandinya dari web admin. Email selain admin/super admin **tidak pernah** dikirimi link dari web admin.

## Alur

```
renovin-web /lupa-password ──email──► edge function request-password-reset
                                        │ cek profiles.role
                                        ├─ admin / super_admin ─► Supabase Auth kirim email (Gmail SMTP)
                                        └─ lainnya / tidak terdaftar ─► tidak kirim apa pun
                                        └─ jawaban SELALU sama, ditahan ±1,5 detik

Email ─► renovin-web /auth/confirm?token_hash=…&type=recovery&next=/reset-password
           │ verifikasi token di server, sesi dibuat
           ▼
         /reset-password ─► updateUser({ password }) ─► logout ─► halaman login
```

**Kenapa jawabannya selalu sama?** Kalau web menampilkan "email ini bukan admin", orang luar bisa menebak email mana yang merupakan akun admin. Dengan jawaban yang sama (dan waktu proses yang sama), hal itu tidak bisa dibedakan.

## Bagian backend (repo ini)

| File | Isi |
|---|---|
| `supabase/functions/request-password-reset/index.ts` | Edge function penjaga: hanya mengirim email reset untuk role `admin`/`super_admin` |
| `supabase/templates/recovery.html` | Template email berbahasa Indonesia (link memakai `token_hash`) |
| `supabase/config.toml` | `verify_jwt = false` untuk function ini (dipanggil tanpa login), template lokal, `site_url` lokal |
| `supabase/functions/.env.example` | Daftar secret function (`ALLOWED_ORIGINS`) |

## Setup (sekali per project Supabase)

### 1. Gmail App Password

Disarankan memakai **akun Gmail khusus** (misalnya untuk notifikasi Renovin), bukan email pribadi.

1. Akun Google → **Keamanan** → aktifkan **Verifikasi 2 Langkah** (wajib untuk App Password).
2. Akun Google → **Keamanan** → **Sandi aplikasi** (App passwords) → buat baru, beri nama `Supabase Renovin`.
3. Simpan 16 karakter sandi aplikasi itu di **Bitwarden**. Ini bukan password Gmail biasa.

Batas Gmail sekitar 500 email per hari, jadi cukup untuk email reset password admin.

### 2. Dashboard Supabase → Authentication

**URL Configuration**

| Isian | renovin-dev |
|---|---|
| Site URL | `http://localhost:3000` (ganti ke URL web admin dev setelah di-deploy) |
| Redirect URLs | `http://localhost:3000/**` (+ URL web admin dev/prod nanti) |

**Emails → SMTP Settings** → aktifkan *Enable custom SMTP*:

| Isian | Nilai |
|---|---|
| Sender email | Alamat Gmail tadi |
| Sender name | `Renovin` |
| Host | `smtp.gmail.com` |
| Port | `465` |
| Username | Alamat Gmail tadi |
| Password | Sandi aplikasi 16 karakter |

**Emails → Templates → Reset Password**

- Subject: `Atur ulang kata sandi Renovin`
- Body: salin seluruh isi `supabase/templates/recovery.html`

### 3. Deploy function

Isi `supabase/functions/.env` dari `.env.example`, lalu:

```bash
npm run secrets:set
npm run functions:deploy
```

`ALLOWED_ORIGINS` berisi origin web admin, dipisah koma (contoh: `http://localhost:3000,https://admin.renovin.id`). Kalau domain web bertambah, cukup ubah `.env` lalu `npm run secrets:set`. Tidak perlu deploy ulang.

## Cara mengetes

1. Pastikan ada akun **admin/super admin dengan email sungguhan** (akun `@renovin.test` tidak bisa menerima email).
2. Panggil function (atau lewat halaman `/lupa-password` setelah FE jadi):

   ```bash
   curl -X POST https://<project-ref>.supabase.co/functions/v1/request-password-reset -H "Content-Type: application/json" -d "{\"email\":\"email-admin@gmail.com\"}"
   ```

3. Hasil yang benar:
   - Email admin → email "Atur ulang kata sandi Renovin" masuk (cek juga folder Spam).
   - Email customer atau tidak terdaftar → jawaban sama, **tidak ada email**.
4. Kalau email tidak masuk: Dashboard → **Logs → Auth** dan **Edge Functions → request-password-reset → Logs**.

## Kontrak untuk renovin-web (dikerjakan FE)

| Yang dibuat di web | Keterangan |
|---|---|
| Link "Lupa kata sandi?" di halaman login | `href="/lupa-password"` |
| `app/lupa-password/page.tsx` | Form email → `supabase.functions.invoke('request-password-reset', { body: { email } })` → tampilkan `data.message` apa adanya |
| `app/auth/confirm/route.ts` | Verifikasi `token_hash` dari email dengan `verifyOtp`, lalu redirect ke `next` |
| `app/reset-password/page.tsx` | Form kata sandi baru → `updateUser({ password })` → `signOut()` → ke halaman login |

Jawaban function:

| Kondisi | HTTP | Body |
|---|---|---|
| Email valid (admin, bukan admin, atau tidak terdaftar) | 200 | `{ "message": "Jika email terdaftar sebagai admin, …" }` |
| Format email salah | 400 | `{ "error": "Format email tidak valid" }` |
| Body bukan JSON | 400 | `{ "error": "Format permintaan tidak valid" }` |

Contoh kode di bawah **sudah dites** di salinan `renovin-web` (commit `a2e66dd`): lint, `tsc`, dan build lolos; `/auth/confirm` dengan token salah diarahkan ke `/lupa-password?error=link-tidak-valid`, dan `next` ke situs luar ditolak. Tampilannya sengaja polos; silakan disesuaikan dengan desain.

### `app/auth/confirm/route.ts`

```ts
import { type EmailOtpType } from "@supabase/supabase-js";
import { redirect } from "next/navigation";
import { type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

// Link di email reset password mengarah ke sini:
//   /auth/confirm?token_hash=...&type=recovery&next=/reset-password
// Token diverifikasi di server, sesi login dibuat (cookie), lalu diarahkan ke `next`.
export async function GET(request: NextRequest) {
  const { searchParams } = request.nextUrl;
  const tokenHash = searchParams.get("token_hash");
  const type = searchParams.get("type") as EmailOtpType | null;
  const next = searchParams.get("next") ?? "/";
  // Hanya izinkan path internal, supaya link tidak bisa dipakai mengarahkan ke situs lain
  const safeNext = next.startsWith("/") && !next.startsWith("//") ? next : "/";

  if (tokenHash && type) {
    const supabase = await createClient();
    const { error } = await supabase.auth.verifyOtp({ type, token_hash: tokenHash });
    if (!error) redirect(safeNext);
  }

  redirect("/lupa-password?error=link-tidak-valid");
}
```

### `app/lupa-password/page.tsx`

```tsx
"use client";

import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

// Halaman minta link reset. Hanya email admin / super admin yang benar-benar
// dikirimi email (dicek oleh edge function request-password-reset), tapi
// pesannya selalu sama supaya email admin tidak bisa ditebak.
export default function LupaPasswordPage() {
  const [email, setEmail] = useState("");
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setMessage("");
    setError("");

    const supabase = createClient();
    const { data, error } = await supabase.functions.invoke("request-password-reset", {
      body: { email },
    });

    if (error) {
      setError("Permintaan gagal. Periksa format email lalu coba lagi.");
    } else {
      setMessage(data.message);
    }
    setLoading(false);
  };

  return (
    <form onSubmit={handleSubmit} className="mx-auto mt-24 max-w-sm space-y-4 p-6">
      <h1 className="text-2xl font-bold">Lupa kata sandi</h1>
      <input
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email admin"
        className="w-full rounded-md border px-3 py-2"
      />
      <button type="submit" disabled={loading} className="w-full rounded-md bg-[#2C4A3B] px-4 py-2 text-white disabled:opacity-70">
        {loading ? "Memproses..." : "Kirim link atur ulang"}
      </button>
      {message && <p className="text-sm text-green-700">{message}</p>}
      {error && <p className="text-sm text-red-600">{error}</p>}
    </form>
  );
}
```

### `app/reset-password/page.tsx`

```tsx
"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";

// Dibuka dari link email (lewat /auth/confirm yang sudah membuat sesi).
export default function ResetPasswordPage() {
  const router = useRouter();
  const [ready, setReady] = useState<boolean | null>(null);
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    createClient()
      .auth.getUser()
      .then(({ data }) => setReady(!!data.user));
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    if (password.length < 8) return setError("Kata sandi minimal 8 karakter.");
    if (password !== confirm) return setError("Konfirmasi kata sandi tidak sama.");

    setLoading(true);
    const supabase = createClient();
    const { error } = await supabase.auth.updateUser({ password });
    if (error) {
      setError("Gagal menyimpan kata sandi: " + error.message);
      setLoading(false);
      return;
    }

    // Keluar, lalu minta login ulang dengan kata sandi baru
    await supabase.auth.signOut();
    router.replace("/?reset=berhasil");
    router.refresh();
  };

  if (ready === null) return <p className="mt-24 text-center">Memuat...</p>;
  if (!ready) {
    return (
      <p className="mt-24 text-center">
        Link tidak valid atau sudah kedaluwarsa. <a href="/lupa-password" className="underline">Minta link baru</a>.
      </p>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="mx-auto mt-24 max-w-sm space-y-4 p-6">
      <h1 className="text-2xl font-bold">Atur kata sandi baru</h1>
      <input type="password" required value={password} onChange={(e) => setPassword(e.target.value)}
        placeholder="Kata sandi baru" className="w-full rounded-md border px-3 py-2" />
      <input type="password" required value={confirm} onChange={(e) => setConfirm(e.target.value)}
        placeholder="Ulangi kata sandi baru" className="w-full rounded-md border px-3 py-2" />
      <button type="submit" disabled={loading} className="w-full rounded-md bg-[#2C4A3B] px-4 py-2 text-white disabled:opacity-70">
        {loading ? "Menyimpan..." : "Simpan kata sandi"}
      </button>
      {error && <p className="text-sm text-red-600">{error}</p>}
    </form>
  );
}
```

Catatan untuk halaman login: tampilkan pesan "Kata sandi berhasil diubah, silakan masuk" kalau URL berisi `?reset=berhasil`.
