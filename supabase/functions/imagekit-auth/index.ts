// Memberikan parameter autentikasi upload ImageKit (token, expire, signature)
// hanya kepada user yang sudah login. Dipanggil dari web & android:
//   supabase.functions.invoke('imagekit-auth')
//
// Secret yang dibutuhkan (supabase secrets set / supabase/functions/.env):
//   IMAGEKIT_PUBLIC_KEY, IMAGEKIT_PRIVATE_KEY, IMAGEKIT_URL_ENDPOINT
//   ALLOWED_ORIGINS   daftar origin web dipisah koma, contoh:
//                     http://localhost:3000,https://admin.renovin.id
//   IMAGEKIT_ROOT_FOLDER (opsional, default "/renovin")

import { createClient } from 'npm:@supabase/supabase-js@2';

const TOKEN_TTL_SECONDS = 30 * 60; // ImageKit mensyaratkan expire < 1 jam

const allowedOrigins = (Deno.env.get('ALLOWED_ORIGINS') ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

function corsHeaders(req: Request): HeadersInit {
  const origin = req.headers.get('Origin');
  const headers: Record<string, string> = {
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
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

async function hmacSha1Hex(key: string, message: string): Promise<string> {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    enc.encode(key),
    { name: 'HMAC', hash: 'SHA-1' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', cryptoKey, enc.encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders(req) });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json(req, { error: 'Harus login' }, 401);
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data: { user }, error: userError } = await supabase.auth.getUser();
  if (userError || !user) {
    return json(req, { error: 'Sesi tidak valid' }, 401);
  }

  const publicKey = Deno.env.get('IMAGEKIT_PUBLIC_KEY');
  const privateKey = Deno.env.get('IMAGEKIT_PRIVATE_KEY');
  const urlEndpoint = Deno.env.get('IMAGEKIT_URL_ENDPOINT');
  if (!publicKey || !privateKey || !urlEndpoint) {
    console.error('Secret ImageKit belum diset');
    return json(req, { error: 'Konfigurasi server belum lengkap' }, 500);
  }

  const token = crypto.randomUUID();
  const expire = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;
  const signature = await hmacSha1Hex(privateKey, token + expire);

  const rootFolder = (Deno.env.get('IMAGEKIT_ROOT_FOLDER') ?? '/renovin').replace(/\/+$/, '');

  // Folder yang disarankan per jenis file. Catatan: ImageKit tidak memaksa
  // folder lewat token, jadi ini konvensi, bukan batasan keamanan.
  const folders = {
    catalog: `${rootFolder}/catalog`, // gambar & aset produk (web admin)
    reports: `${rootFolder}/reports`, // PDF laporan final (web admin)
    user: `${rootFolder}/users/${user.id}`, // file milik user ini, mis. foto ruangan (android)
  };

  return json(req, {
    token,
    expire,
    signature,
    publicKey,
    urlEndpoint,
    folders,
    folder: folders.user, // dipertahankan untuk kompatibilitas
  });
});
