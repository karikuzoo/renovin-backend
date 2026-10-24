// Membuat laporan PDF RAB dari snapshot final, lalu status pesanan menjadi
// report_generated. Kontrak FE: docs/contract-laporan-pdf.md
//
// Dipanggil web admin (staff yang login):
//   supabase.functions.invoke('generate-report', { body: { project_id } })
//
// Function berjalan dengan JWT pemanggil (bukan service role), jadi semua aturan
// RLS tetap berlaku: hanya staff yang bisa membaca snapshot, mengunggah ke bucket
// `reports`, dan menyimpan baris `reports` untuk pesanan confirmed/report_generated.
//
// Boleh dipanggil ulang saat status report_generated untuk membuat ulang PDF
// (file & baris laporan diganti, status tidak berubah).
//
// Secret: ALLOWED_ORIGINS (sama dengan request-password-reset).
// SUPABASE_URL & SUPABASE_ANON_KEY (atau SUPABASE_PUBLISHABLE_KEY) disediakan otomatis oleh Supabase.
// verify_jwt = false di config.toml: login diverifikasi sendiri lewat auth.getUser().

import { createClient } from 'npm:@supabase/supabase-js@2';
import { buildReportPdf, type SnapshotData, type StudioInfo } from './pdf.ts';

const STAFF_ROLES = ['admin', 'super_admin'];
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

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
  if (origin && allowedOrigins.includes(origin)) headers['Access-Control-Allow-Origin'] = origin;
  return headers;
}

function json(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), 'Content-Type': 'application/json' },
  });
}

// Logo hanya PNG/JPG (format yang bisa ditanam di PDF). SVG/WebP -> pakai nama studio.
async function loadLogo(url: string | null | undefined): Promise<{ bytes: Uint8Array; type: 'png' | 'jpg' } | null> {
  if (!url || !/^https:\/\//.test(url)) return null;
  try {
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return null;
    const type = res.headers.get('content-type') ?? '';
    const kind = type.includes('png') ? 'png' : type.includes('jpeg') || type.includes('jpg') ? 'jpg' : null;
    if (!kind) return null;
    const bytes = new Uint8Array(await res.arrayBuffer());
    return bytes.length <= 2 * 1024 * 1024 ? { bytes, type: kind } : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders(req) });
  if (req.method !== 'POST') return json(req, { error: 'Metode tidak diizinkan' }, 405);

  const authHeader = req.headers.get('Authorization') ?? '';
  if (!authHeader.startsWith('Bearer ')) return json(req, { error: 'Harus login' }, 401);

  let projectId = '';
  try {
    projectId = String((await req.json())?.project_id ?? '');
  } catch {
    return json(req, { error: 'Format permintaan tidak valid' }, 400);
  }
  if (!UUID.test(projectId)) return json(req, { error: 'project_id tidak valid' }, 400);

  // Client dengan JWT pemanggil -> RLS berlaku
  const publicKey = Deno.env.get('SUPABASE_ANON_KEY') || Deno.env.get('SUPABASE_PUBLISHABLE_KEY') || '';
  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, publicKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser(authHeader.slice(7));
  if (userError || !userData.user) return json(req, { error: 'Sesi login tidak valid' }, 401);

  const { data: profile } = await supabase.from('profiles').select('role').eq('id', userData.user.id).single();
  if (!profile || !STAFF_ROLES.includes(profile.role)) {
    return json(req, { error: 'Hanya admin atau super admin yang bisa membuat laporan' }, 403);
  }

  const { data: project, error: projectError } = await supabase
    .from('projects')
    .select('id, code, status, final_snapshot_id')
    .eq('id', projectId)
    .maybeSingle();
  if (projectError) return json(req, { error: projectError.message }, 500);
  if (!project) return json(req, { error: 'Pesanan tidak ditemukan' }, 404);
  if (!['confirmed', 'report_generated'].includes(project.status) || !project.final_snapshot_id) {
    return json(req, { error: 'Laporan hanya bisa dibuat setelah RAB dikonfirmasi final' }, 409);
  }

  const [snapRes, settingsRes] = await Promise.all([
    supabase.from('rab_snapshots').select('id, version, data').eq('id', project.final_snapshot_id).single(),
    supabase.from('app_settings').select('key, value').in('key', ['studio_profile', 'locale']),
  ]);
  if (snapRes.error || !snapRes.data) return json(req, { error: 'Snapshot final tidak ditemukan' }, 500);

  type Settings = { studio_profile?: Partial<StudioInfo> & { logo_url?: string | null }; locale?: { timezone?: string } };
  const settings = Object.fromEntries((settingsRes.data ?? []).map((r) => [r.key, r.value])) as Settings;
  const studioProfile = settings.studio_profile ?? {};
  const studio: StudioInfo = {
    name: studioProfile.name || 'Renovin. Studio Interior',
    address: studioProfile.address,
    phone: studioProfile.phone,
    email: studioProfile.email,
    website: studioProfile.website,
  };

  let pdf: Uint8Array;
  try {
    pdf = await buildReportPdf({
      studio,
      logo: await loadLogo(studioProfile.logo_url),
      snapshot: snapRes.data.data as SnapshotData,
      generatedAt: new Date(),
      timeZone: settings.locale?.timezone || 'Asia/Jakarta',
    });
  } catch (err) {
    console.error('Gagal membuat PDF', err);
    return json(req, { error: 'Gagal membuat PDF' }, 500);
  }

  // <project_id>/... wajib (policy bucket reports). Versi snapshot di nama file.
  const path = `${project.id}/laporan-rab-${project.code}-v${snapRes.data.version}.pdf`;
  const { error: uploadError } = await supabase.storage
    .from('reports')
    .upload(path, pdf, { contentType: 'application/pdf', upsert: true });
  if (uploadError) return json(req, { error: `Gagal menyimpan PDF: ${uploadError.message}` }, 500);

  // Satu laporan per snapshot (reports.snapshot_id unik) -> upsert saat dibuat ulang
  const { data: report, error: reportError } = await supabase
    .from('reports')
    .upsert(
      {
        project_id: project.id,
        snapshot_id: project.final_snapshot_id,
        pdf_file_id: path,
        pdf_url: path,
        generated_by: userData.user.id,
        generated_at: new Date().toISOString(),
      },
      { onConflict: 'snapshot_id' },
    )
    .select('id, pdf_url, generated_at')
    .single();
  if (reportError) return json(req, { error: `Gagal mencatat laporan: ${reportError.message}` }, 500);

  if (project.status === 'confirmed') {
    const { error: statusError } = await supabase.rpc('change_project_status', {
      p_project_id: project.id,
      p_to_status: 'report_generated',
    });
    if (statusError) return json(req, { error: `Laporan tersimpan, tapi status gagal diubah: ${statusError.message}` }, 500);
  }

  const { data: signed } = await supabase.storage.from('reports').createSignedUrl(path, 3600);

  return json(req, {
    report_id: report.id,
    path,
    generated_at: report.generated_at,
    signed_url: signed?.signedUrl ?? null,
    status: 'report_generated',
  });
});
