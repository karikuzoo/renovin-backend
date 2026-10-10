// Permintaan reset password KHUSUS admin & super admin (web admin).
//
// Fitur bawaan Supabase (auth.resetPasswordForEmail) mengirim email ke siapa pun
// yang terdaftar. Function ini menjadi penjaga: email hanya dikirim kalau
// profiles.role = 'admin' / 'super_admin'.
//
// Dipanggil dari web TANPA login (user lupa password):
//   POST /functions/v1/request-password-reset   body: { "email": "..." }
//   supabase.functions.invoke('request-password-reset', { body: { email } })
//
// Jawaban SELALU sama untuk email terdaftar maupun tidak, supaya orang luar
// tidak bisa menebak email mana yang merupakan akun admin.
//
// Secret (supabase secrets set / supabase/functions/.env):
//   ALLOWED_ORIGINS  origin web admin dipisah koma, contoh:
//                    http://localhost:3000,https://admin.renovin.id
// SUPABASE_URL & SUPABASE_SERVICE_ROLE_KEY disediakan otomatis oleh Supabase.

import { createClient } from 'npm:@supabase/supabase-js@2';

const STAFF_ROLES = ['admin', 'super_admin'];
const GENERIC_MESSAGE =
  'Jika email terdaftar sebagai admin, link untuk mengatur ulang kata sandi akan dikirim ke email tersebut.';
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// Semua jawaban ditahan minimal selama ini, supaya lama proses tidak membocorkan
// apakah email tersebut akun admin (jalur admin lebih lama karena mengirim email).
const MIN_RESPONSE_MS = 1500;

const allowedOrigins = (Deno.env.get('ALLOWED_ORIGINS') ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

function corsHeaders(req: Request): HeadersInit {
  const origin = req.headers.get('Origin');
  const headers: Record<string, string> = {
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    Vary: 'Origin',
  };
  if (origin && allowedOrigins.includes(origin)) {
    headers['Access-Control-Allow-Origin'] = origin;
  }
  return headers;
}

function json(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders(req) });
  }
  if (req.method !== 'POST') {
    return json(req, { error: 'Metode tidak diizinkan' }, 405);
  }

  let email = '';
  try {
    const body = await req.json();
    email = String(body?.email ?? '').trim().toLowerCase();
  } catch {
    return json(req, { error: 'Format permintaan tidak valid' }, 400);
  }

  if (!EMAIL_PATTERN.test(email) || email.length > 254) {
    return json(req, { error: 'Format email tidak valid' }, 400);
  }

  const startedAt = Date.now();

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );

  try {
    // Email di auth & profiles disimpan huruf kecil, jadi cukup pencocokan persis.
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('role')
      .eq('email', email)
      .maybeSingle();

    if (profileError) {
      console.error('Gagal membaca profil:', profileError.message);
    } else if (profile && STAFF_ROLES.includes(profile.role)) {
      // Link di email dibangun dari template "Reset Password" (Site URL + token_hash).
      const { error: resetError } = await supabase.auth.resetPasswordForEmail(email);
      if (resetError) {
        // Contoh: batas kirim email tercapai. Tetap jawab umum ke pengguna.
        console.error('Gagal mengirim email reset:', resetError.message);
      }
    }
  } catch (err) {
    console.error('Kesalahan tak terduga:', err instanceof Error ? err.message : err);
  }

  const elapsed = Date.now() - startedAt;
  if (elapsed < MIN_RESPONSE_MS) {
    await new Promise((resolve) => setTimeout(resolve, MIN_RESPONSE_MS - elapsed));
  }

  return json(req, { message: GENERIC_MESSAGE });
});
