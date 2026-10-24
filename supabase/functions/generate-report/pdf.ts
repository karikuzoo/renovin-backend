// Pembuat PDF laporan RAB dari snapshot final (rab_snapshots.data).
// Dipisah dari index.ts supaya bisa dites tanpa Supabase.
//
// PENTING: laporan ini untuk CUSTOMER. Hanya harga customer yang ditampilkan;
// harga internal (unit_price_internal, subtotal_internal, *_internal) TIDAK
// pernah dibaca di file ini.

import { PDFDocument, type PDFFont, type PDFImage, type PDFPage, rgb, StandardFonts } from 'npm:pdf-lib@1.17.1';

export interface StudioInfo {
  name: string;
  address?: string | null;
  phone?: string | null;
  email?: string | null;
  website?: string | null;
}

export interface SnapshotLineItem {
  item_type: string;
  description: string;
  quantity: number | string;
  unit: string;
  unit_price_customer: number | string;
  subtotal_customer: number | string | null;
  sort_order?: number;
}

export interface SnapshotData {
  version: number;
  confirmed_at: string;
  project: { code: string; title: string; room_type?: string | null };
  customer: { full_name?: string | null; email?: string | null; phone?: string | null };
  measurements?: { area?: number | string | null }[];
  rab: {
    material_total_customer: number | string;
    service_total: number | string;
    adjustment: number | string;
    adjustment_note?: string | null;
    tax_percent: number | string;
    tax_amount: number | string;
    grand_total_customer: number | string;
  };
  rab_line_items: SnapshotLineItem[];
}

export interface ReportInput {
  studio: StudioInfo;
  logo?: { bytes: Uint8Array; type: 'png' | 'jpg' } | null;
  snapshot: SnapshotData;
  generatedAt: Date;
  timeZone?: string;
}

// ---------------------------------------------------------------------------
// Format
// ---------------------------------------------------------------------------
const num = (v: number | string | null | undefined) => Number(v ?? 0);
const rupiah = (v: number | string | null | undefined) =>
  'Rp ' + new Intl.NumberFormat('id-ID', { maximumFractionDigits: 0 }).format(Math.round(num(v)));
const angka = (v: number | string | null | undefined, max = 3) =>
  new Intl.NumberFormat('id-ID', { maximumFractionDigits: max }).format(num(v));

function tanggal(iso: string | Date, timeZone: string, withTime = false) {
  const d = typeof iso === 'string' ? new Date(iso) : iso;
  const date = new Intl.DateTimeFormat('id-ID', { day: 'numeric', month: 'long', year: 'numeric', timeZone }).format(d);
  if (!withTime) return date;
  const time = new Intl.DateTimeFormat('id-ID', { hour: '2-digit', minute: '2-digit', timeZone }).format(d);
  return `${date}, ${time}`;
}

// Font standar PDF (WinAnsi) tidak bisa menampilkan semua karakter Unicode.
// Karakter di luar Latin-1 + tanda baca umum diganti supaya PDF tetap jadi.
const WINANSI_EXTRA = new Set('€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ'.split(''));
function safe(text: string | null | undefined): string {
  return Array.from(text ?? '')
    .map((ch) => {
      const code = ch.codePointAt(0) ?? 0;
      if (ch === '\n' || ch === '\t') return ' ';
      if ((code >= 0x20 && code <= 0x7e) || (code >= 0xa0 && code <= 0xff) || WINANSI_EXTRA.has(ch)) return ch;
      return '?';
    })
    .join('');
}

function wrap(text: string, font: PDFFont, size: number, maxWidth: number): string[] {
  const words = safe(text).split(/\s+/).filter(Boolean);
  const lines: string[] = [];
  let line = '';
  for (const word of words) {
    const candidate = line ? `${line} ${word}` : word;
    if (font.widthOfTextAtSize(candidate, size) <= maxWidth) {
      line = candidate;
      continue;
    }
    if (line) lines.push(line);
    // kata yang terlalu panjang dipotong paksa
    let rest = word;
    while (font.widthOfTextAtSize(rest, size) > maxWidth && rest.length > 1) {
      let cut = rest.length - 1;
      while (cut > 1 && font.widthOfTextAtSize(rest.slice(0, cut), size) > maxWidth) cut--;
      lines.push(rest.slice(0, cut));
      rest = rest.slice(cut);
    }
    line = rest;
  }
  if (line) lines.push(line);
  return lines.length ? lines : [''];
}

// ---------------------------------------------------------------------------
// Tata letak
// ---------------------------------------------------------------------------
const A4: [number, number] = [595.28, 841.89];
const M = 48; // margin
const GREEN = rgb(0.173, 0.29, 0.231); // #2C4A3B
const TEXT = rgb(0.094, 0.094, 0.106);
const MUTED = rgb(0.42, 0.42, 0.45);
const LINE = rgb(0.88, 0.87, 0.85);
const SOFT = rgb(0.957, 0.945, 0.929); // #F4F1ED

// Kolom tabel: No, Uraian, Jumlah, Satuan, Harga satuan, Subtotal
const COLS = [
  { key: 'no', w: 22, align: 'left' },
  { key: 'desc', w: 205, align: 'left' },
  { key: 'qty', w: 50, align: 'right' },
  { key: 'unit', w: 44, align: 'left' },
  { key: 'price', w: 84, align: 'right' },
  { key: 'sub', w: 94, align: 'right' },
] as const;
const HEADERS = ['No', 'Uraian', 'Jumlah', 'Satuan', 'Harga satuan', 'Subtotal'];

export async function buildReportPdf(input: ReportInput): Promise<Uint8Array> {
  const tz = input.timeZone || 'Asia/Jakarta';
  const { snapshot, studio } = input;
  const doc = await PDFDocument.create();
  doc.setTitle(safe(`RAB ${snapshot.project.code} - ${snapshot.project.title}`));
  doc.setAuthor(safe(studio.name));
  doc.setCreator('Renovin');

  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);

  let logo: PDFImage | null = null;
  if (input.logo) {
    try {
      logo = input.logo.type === 'png' ? await doc.embedPng(input.logo.bytes) : await doc.embedJpg(input.logo.bytes);
    } catch {
      logo = null; // logo rusak / format tidak didukung -> pakai nama studio
    }
  }

  const pages: PDFPage[] = [];
  let page!: PDFPage;
  let y = 0;
  const width = A4[0] - 2 * M;

  const text = (t: string, x: number, yy: number, size = 9, f = font, color = TEXT) =>
    page.drawText(safe(t), { x, y: yy, size, font: f, color });
  const textRight = (t: string, right: number, yy: number, size = 9, f = font, color = TEXT) =>
    text(t, right - f.widthOfTextAtSize(safe(t), size), yy, size, f, color);
  const hline = (yy: number, color = LINE, thickness = 0.6) =>
    page.drawLine({ start: { x: M, y: yy }, end: { x: A4[0] - M, y: yy }, thickness, color });

  const newPage = () => {
    page = doc.addPage(A4);
    pages.push(page);
    y = A4[1] - M;
    if (pages.length > 1) {
      // kepala halaman lanjutan
      text(`${snapshot.project.code} · Rencana Anggaran Biaya (lanjutan)`, M, y - 4, 8, font, MUTED);
      y -= 22;
    }
  };

  const ensure = (needed: number, onBreak?: () => void) => {
    if (y - needed < M + 24) {
      newPage();
      onBreak?.();
    }
  };

  // ---- Halaman 1: kop ------------------------------------------------------
  newPage();
  if (logo) {
    const h = 40;
    const w = Math.min((logo.width / logo.height) * h, 160);
    page.drawImage(logo, { x: M, y: y - h, width: w, height: (w / logo.width) * logo.height });
  } else {
    text(studio.name || 'Renovin.', M, y - 22, 20, bold, GREEN);
  }
  const contact = [studio.address, [studio.phone, studio.email].filter(Boolean).join(' · '), studio.website]
    .filter((v): v is string => !!v && !!v.trim());
  // Nama studio di kanan hanya kalau kiri berisi logo (supaya tidak dobel)
  let cy = y - 8;
  if (logo) textRight(studio.name || 'Renovin.', A4[0] - M, cy, 10, bold);
  else cy += 6;
  cy -= 3;
  for (const c of contact) {
    for (const ln of wrap(c, font, 8, 230)) {
      cy -= 11;
      textRight(ln, A4[0] - M, cy, 8, font, MUTED);
    }
  }
  y = Math.min(y - 52, cy - 14);
  page.drawRectangle({ x: M, y: y - 2, width, height: 2, color: GREEN });
  y -= 30;

  // ---- Judul ---------------------------------------------------------------
  text('RENCANA ANGGARAN BIAYA (RAB)', M, y, 15, bold, GREEN);
  y -= 16;
  text(
    `${snapshot.project.code}  ·  Versi ${snapshot.version}  ·  Dikonfirmasi ${tanggal(snapshot.confirmed_at, tz)}`,
    M, y, 9, font, MUTED,
  );
  y -= 26;

  // ---- Info klien & proyek (dua kolom) -------------------------------------
  const totalArea = (snapshot.measurements ?? []).reduce((s, m) => s + num(m.area), 0);
  const colW = width / 2 - 10;
  const left: [string, string][] = [
    ['Klien', snapshot.customer.full_name || '-'],
    ['Telepon', snapshot.customer.phone || '-'],
    ['Email', snapshot.customer.email || '-'],
  ];
  const right: [string, string][] = [
    ['Proyek', snapshot.project.title],
    ['Jenis ruangan', snapshot.project.room_type || '-'],
    ['Luas terukur', totalArea > 0 ? `${angka(totalArea)} m²` : '-'],
  ];
  // Tinggi kotak dihitung dulu, lalu latar digambar sebelum teks
  const blockHeight = (rows: [string, string][]) =>
    rows.reduce((h, [, v]) => h + 10 + wrap(v, bold, 9.5, colW - 20).length * 12 + 4, 0);
  const boxTop = y + 10;
  const boxBottom = y - 4 - Math.max(blockHeight(left), blockHeight(right)) + 4;
  page.drawRectangle({ x: M, y: boxBottom, width, height: boxTop - boxBottom, color: SOFT });
  const drawBlock = (rows: [string, string][], x: number) => {
    let yy = y - 4;
    for (const [k, v] of rows) {
      text(k, x, yy, 7.5, font, MUTED);
      yy -= 10;
      for (const ln of wrap(v, bold, 9.5, colW - 20)) {
        text(ln, x, yy, 9.5, bold);
        yy -= 12;
      }
      yy -= 4;
    }
  };
  drawBlock(left, M + 10);
  drawBlock(right, M + width / 2 + 10);
  y = boxBottom - 26;

  // ---- Tabel ---------------------------------------------------------------
  const colX: number[] = [];
  COLS.reduce((x, c) => (colX.push(x), x + c.w), M);
  const cellRight = (i: number) => colX[i] + COLS[i].w - 6;

  const drawHeader = () => {
    page.drawRectangle({ x: M, y: y - 6, width, height: 18, color: GREEN });
    HEADERS.forEach((h, i) => {
      if (COLS[i].align === 'right') textRight(h, cellRight(i), y, 8, bold, rgb(1, 1, 1));
      else text(h, colX[i] + 6, y, 8, bold, rgb(1, 1, 1));
    });
    y -= 22;
  };

  const items = [...snapshot.rab_line_items].sort((a, b) => num(a.sort_order) - num(b.sort_order));
  const groups: [string, SnapshotLineItem[]][] = [
    ['Bahan & furnitur', items.filter((i) => i.item_type !== 'service')],
    ['Jasa', items.filter((i) => i.item_type === 'service')],
  ];

  ensure(60);
  drawHeader();
  let no = 0;
  for (const [title, rows] of groups) {
    if (!rows.length) continue;
    ensure(30, drawHeader);
    text(title, M + 6, y, 8.5, bold, GREEN);
    y -= 14;
    for (const it of rows) {
      no += 1;
      const descLines = wrap(it.description, font, 8.5, COLS[1].w - 12);
      const h = descLines.length * 11 + 6;
      ensure(h + 4, drawHeader);
      text(String(no), colX[0] + 6, y, 8.5, font, MUTED);
      descLines.forEach((ln, i) => text(ln, colX[1] + 6, y - i * 11, 8.5));
      textRight(angka(it.quantity), cellRight(2), y, 8.5);
      text(it.unit, colX[3] + 6, y, 8.5);
      textRight(rupiah(it.unit_price_customer), cellRight(4), y, 8.5);
      textRight(rupiah(it.subtotal_customer ?? num(it.quantity) * num(it.unit_price_customer)), cellRight(5), y, 8.5, bold);
      y -= h;
      hline(y + 8);
    }
    y -= 6;
  }

  // ---- Ringkasan -----------------------------------------------------------
  const rab = snapshot.rab;
  const summary: [string, string, boolean][] = [
    ['Total bahan & furnitur', rupiah(rab.material_total_customer), false],
    ['Total jasa', rupiah(rab.service_total), false],
  ];
  if (num(rab.adjustment) !== 0) {
    const note = rab.adjustment_note ? ` (${rab.adjustment_note})` : '';
    summary.push([`Penyesuaian${note}`, (num(rab.adjustment) < 0 ? '- ' : '') + rupiah(Math.abs(num(rab.adjustment))), false]);
  }
  summary.push([`Pajak ${angka(rab.tax_percent, 2)}%`, rupiah(rab.tax_amount), false]);

  ensure(summary.length * 16 + 50);
  y -= 6;
  const sumX = M + width - 250;
  for (const [label, value] of summary) {
    const lines = wrap(label, font, 9, 150);
    lines.forEach((ln, i) => text(ln, sumX, y - i * 11, 9, font, MUTED));
    textRight(value, A4[0] - M - 6, y, 9);
    y -= Math.max(16, lines.length * 11 + 5);
  }
  y -= 10;
  page.drawRectangle({ x: sumX - 8, y: y - 10, width: A4[0] - M - sumX + 8, height: 26, color: GREEN });
  text('TOTAL', sumX, y, 10, bold, rgb(1, 1, 1));
  textRight(rupiah(rab.grand_total_customer), A4[0] - M - 6, y, 11, bold, rgb(1, 1, 1));
  y -= 40;

  // ---- Catatan -------------------------------------------------------------
  ensure(40);
  const notes = [
    'Harga sudah termasuk pajak sesuai rincian di atas.',
    'Dokumen ini dibuat dari RAB yang telah disetujui dan dikonfirmasi final oleh studio.',
  ];
  for (const n of notes) {
    for (const ln of wrap(`• ${n}`, font, 8, width)) { text(ln, M, y, 8, font, MUTED); y -= 11; }
  }

  // ---- Kaki halaman --------------------------------------------------------
  const footer = `${studio.name || 'Renovin'} · Dibuat ${tanggal(input.generatedAt, tz, true)} WIB`;
  pages.forEach((p, i) => {
    page = p;
    hline(M + 6);
    text(footer, M, M - 6, 7.5, font, MUTED);
    textRight(`Halaman ${i + 1} dari ${pages.length}`, A4[0] - M, M - 6, 7.5, font, MUTED);
  });

  return await doc.save();
}
