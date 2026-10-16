-- =============================================================================
-- Seed data — HANYA untuk lokal & renovin-dev. JANGAN dijalankan di prod.
--
-- Akun uji (password sama untuk semua): Renovin#Dev2026
--   superadmin@renovin.test   super_admin
--   admin@renovin.test        admin
--   customer1@renovin.test    customer  (punya project P1, P2, P3)
--   customer2@renovin.test    customer  (punya project P4, P5)
--   admin2@renovin.test       admin     Nadia Anggraini
--   customer3@renovin.test    customer  Sarah Wijaya   (P9, P11)
--   customer4@renovin.test    customer  Ari Wibowo     (P10, P13)
--   customer5@renovin.test    customer  Dimas Putra    (P6, P14)
--   customer6@renovin.test    customer  Maya Lestari   (P7, P15)
--   customer7@renovin.test    customer  Rina Kusuma    (P12)
--   customer8@renovin.test    customer  Hendra Gunawan (P8, belum dikirim)
--
-- Ringkasan project P1–P15: 1 draft, 1 ready_to_submit, 3 baru,
-- 7 dikerjakan (semua tahap), 2 selesai, 1 ditolak.
--
-- Foto memakai placeholder PNG dari placehold.co (bukan file di Supabase Storage).
-- Format PNG wajib: next/image di renovin-web menolak SVG.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Akun
-- -----------------------------------------------------------------------------
with seed_users (id, email, full_name) as (
  values
    ('00000000-0000-4000-a000-000000000001'::uuid, 'superadmin@renovin.test', 'Super Admin Renovin'),
    ('00000000-0000-4000-a000-000000000002'::uuid, 'admin@renovin.test',      'Admin Renovin'),
    ('00000000-0000-4000-a000-000000000003'::uuid, 'customer1@renovin.test',  'Budi Santoso'),
    ('00000000-0000-4000-a000-000000000004'::uuid, 'customer2@renovin.test',  'Siti Rahma'),
    ('00000000-0000-4000-a000-000000000005'::uuid, 'admin2@renovin.test',     'Nadia Anggraini'),
    ('00000000-0000-4000-a000-000000000006'::uuid, 'customer3@renovin.test',  'Sarah Wijaya'),
    ('00000000-0000-4000-a000-000000000007'::uuid, 'customer4@renovin.test',  'Ari Wibowo'),
    ('00000000-0000-4000-a000-000000000008'::uuid, 'customer5@renovin.test',  'Dimas Putra'),
    ('00000000-0000-4000-a000-000000000009'::uuid, 'customer6@renovin.test',  'Maya Lestari'),
    ('00000000-0000-4000-a000-000000000010'::uuid, 'customer7@renovin.test',  'Rina Kusuma'),
    ('00000000-0000-4000-a000-000000000011'::uuid, 'customer8@renovin.test',  'Hendra Gunawan')
)
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email,
  extensions.crypt('Renovin#Dev2026', extensions.gen_salt('bf')), now(),
  '{"provider": "email", "providers": ["email"]}',
  jsonb_build_object('full_name', full_name), now(), now(),
  '', '', '', ''
from seed_users;

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
select
  gen_random_uuid(), u.id, u.id::text,
  jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
  'email', now(), now(), now()
from auth.users u
where u.email like '%@renovin.test';

-- Profile sudah dibuat oleh trigger; set role & nomor HP.
update public.profiles set role = 'super_admin', phone = '081200000001' where id = '00000000-0000-4000-a000-000000000001';
update public.profiles set role = 'admin',       phone = '081200000002' where id = '00000000-0000-4000-a000-000000000002';
update public.profiles set                       phone = '081200000003' where id = '00000000-0000-4000-a000-000000000003';
update public.profiles set                       phone = '081200000004' where id = '00000000-0000-4000-a000-000000000004';
update public.profiles set role = 'admin',       phone = '081200000005' where id = '00000000-0000-4000-a000-000000000005';
update public.profiles set phone = '0812000000' || right(id::text, 2)
where id between '00000000-0000-4000-a000-000000000006' and '00000000-0000-4000-a000-000000000011';

-- -----------------------------------------------------------------------------
-- Katalog
-- -----------------------------------------------------------------------------
insert into public.product_categories (id, name, slug, type, sort_order) values
  ('10000000-0000-4000-a000-000000000001', 'Cat Dinding Interior', 'cat-interior', 'paint',     1),
  ('10000000-0000-4000-a000-000000000002', 'Sofa',                 'sofa',         'furniture', 2),
  ('10000000-0000-4000-a000-000000000003', 'Meja',                 'meja',         'furniture', 3),
  ('10000000-0000-4000-a000-000000000004', 'Lemari & Rak',         'lemari-rak',   'furniture', 4),
  ('10000000-0000-4000-a000-000000000005', 'Kursi',                'kursi',        'furniture', 5),
  ('10000000-0000-4000-a000-000000000006', 'Material Bangunan',    'material',     'material',  6);

insert into public.products (
  id, category_id, type, sku, name, unit, price_customer, color_name, color_hex,
  width_cm, depth_cm, height_cm, image_url, asset_url, active, created_by
) values
  -- Cat (harga per m2)
  ('20000000-0000-4000-a000-000000000001', '10000000-0000-4000-a000-000000000001', 'paint', 'CAT-001',
   'Cat Interior Putih Gading', 'm2', 35000, 'Putih Gading', '#F3EBDD', null, null, null,
   'https://placehold.co/400x400/F3EBDD/333/png?text=Putih+Gading', null, true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000002', '10000000-0000-4000-a000-000000000001', 'paint', 'CAT-002',
   'Cat Interior Sage Green', 'm2', 38000, 'Sage Green', '#A3B18A', null, null, null,
   'https://placehold.co/400x400/A3B18A/fff/png?text=Sage+Green', null, true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000003', '10000000-0000-4000-a000-000000000001', 'paint', 'CAT-003',
   'Cat Interior Abu Hangat', 'm2', 36000, 'Abu Hangat', '#B8B0A6', null, null, null,
   'https://placehold.co/400x400/B8B0A6/fff/png?text=Abu+Hangat', null, true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000004', '10000000-0000-4000-a000-000000000001', 'paint', 'CAT-004',
   'Cat Interior Terracotta (nonaktif)', 'm2', 40000, 'Terracotta', '#C2703D', null, null, null,
   'https://placehold.co/400x400/C2703D/fff/png?text=Terracotta', null, false, '00000000-0000-4000-a000-000000000002'),
  -- Furnitur (harga per unit)
  ('20000000-0000-4000-a000-000000000011', '10000000-0000-4000-a000-000000000002', 'furniture', 'SOFA-001',
   'Sofa 3 Dudukan Linen Abu', 'pcs', 4500000, null, null, 200, 85, 80,
   'https://placehold.co/400x300/png?text=Sofa+3+Dudukan', 'https://placehold.co/800x400/png?text=Sofa+Asset', true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000012', '10000000-0000-4000-a000-000000000003', 'furniture', 'MEJA-001',
   'Meja Kopi Kayu Jati', 'pcs', 1750000, null, null, 100, 55, 45,
   'https://placehold.co/400x300/png?text=Meja+Kopi', 'https://placehold.co/800x400/png?text=Meja+Asset', true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000013', '10000000-0000-4000-a000-000000000004', 'furniture', 'RAK-001',
   'Rak Buku Minimalis 5 Susun', 'pcs', 1250000, null, null, 80, 30, 180,
   'https://placehold.co/400x300/png?text=Rak+Buku', 'https://placehold.co/800x400/png?text=Rak+Asset', true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000014', '10000000-0000-4000-a000-000000000004', 'furniture', 'LMR-001',
   'Lemari Pakaian 3 Pintu Oak', 'pcs', 6500000, null, null, 150, 60, 200,
   'https://placehold.co/400x300/png?text=Lemari+Pakaian', 'https://placehold.co/800x400/png?text=Lemari+Asset', true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000015', '10000000-0000-4000-a000-000000000005', 'furniture', 'KRS-001',
   'Kursi Kafe Rotan', 'pcs', 950000, null, null, 50, 52, 80,
   'https://placehold.co/400x300/png?text=Kursi+Rotan', 'https://placehold.co/800x400/png?text=Kursi+Asset', true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000016', '10000000-0000-4000-a000-000000000003', 'furniture', 'MEJA-002',
   'Meja Kerja Kayu Solid 140 cm', 'pcs', 3200000, null, null, 140, 70, 75,
   'https://placehold.co/400x300/png?text=Meja+Kerja', 'https://placehold.co/800x400/png?text=Meja+Kerja+Asset', true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000017', '10000000-0000-4000-a000-000000000002', 'furniture', 'SOFA-002',
   'Sofa L Modular Krem', 'pcs', 9800000, null, null, 280, 180, 82,
   'https://placehold.co/400x300/png?text=Sofa+L', 'https://placehold.co/800x400/png?text=Sofa+L+Asset', true, '00000000-0000-4000-a000-000000000002'),
  -- Material bangunan (tampil di katalog; belum otomatis masuk RAB)
  ('20000000-0000-4000-a000-000000000021', '10000000-0000-4000-a000-000000000006', 'material', 'MAT-001',
   'Papan Gypsum 9 mm', 'lembar', 85000, null, null, 120, null, 240,
   'https://placehold.co/400x300/png?text=Papan+Gypsum', null, true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000022', '10000000-0000-4000-a000-000000000006', 'material', 'MAT-002',
   'Keramik Lantai 60x60 Krem', 'm2', 145000, 'Krem', '#E8DCC4', 60, 60, null,
   'https://placehold.co/400x300/E8DCC4/333/png?text=Keramik+60x60', null, true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000023', '10000000-0000-4000-a000-000000000006', 'material', 'MAT-003',
   'Semen Instan Perekat Keramik 25 kg', 'sak', 95000, null, null, null, null, null,
   'https://placehold.co/400x300/png?text=Semen+Instan', null, true, '00000000-0000-4000-a000-000000000002');

insert into public.product_internal_prices (product_id, price_internal, updated_by) values
  ('20000000-0000-4000-a000-000000000001',   22000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000002',   24000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000003',   23000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000004',   26000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000011', 3200000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000012', 1100000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000013',  800000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000014', 4800000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000015',  650000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000016', 2300000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000017', 7200000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000021',   60000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000022',  105000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000023',   70000, '00000000-0000-4000-a000-000000000002');

insert into public.service_rates (code, name, calc_type, applies_to, rate) values
  ('JASA-CAT',   'Jasa pengecatan',                 'per_m2', 'paint', 25000),
  ('JASA-ANTAR', 'Jasa pengiriman & pemasangan',    'flat',   null,    150000);

-- -----------------------------------------------------------------------------
-- Project contoh
--   P1 draft             — customer1, belum ada foto
--   P2 sent_to_admin     — customer1, siap diproses admin
--   P3 rab_draft         — customer1, RAB sudah dihitung
--   P4 pending_approval  — customer2, menunggu super admin
--   P5 approved          — customer2, siap confirm final & generate PDF
-- -----------------------------------------------------------------------------
insert into public.projects (id, code, customer_id, title, room_type, notes, status, assigned_admin_id, submitted_at) values
  ('30000000-0000-4000-a000-000000000001', 'RNV-2610-00001', '00000000-0000-4000-a000-000000000003',
   'Kamar Tidur Utama', 'kamar tidur', null, 'draft', null, null),
  ('30000000-0000-4000-a000-000000000002', 'RNV-2610-00002', '00000000-0000-4000-a000-000000000003',
   'Ruang Tamu', 'ruang tamu', 'Ingin suasana lebih terang', 'sent_to_admin', null, now() - interval '1 day'),
  ('30000000-0000-4000-a000-000000000003', 'RNV-2610-00003', '00000000-0000-4000-a000-000000000003',
   'Ruang Keluarga', 'ruang keluarga', null, 'admin_processing', '00000000-0000-4000-a000-000000000002', now() - interval '3 days'),
  ('30000000-0000-4000-a000-000000000004', 'RNV-2610-00004', '00000000-0000-4000-a000-000000000004',
   'Kamar Anak', 'kamar tidur', 'Warna lembut untuk anak', 'admin_processing', '00000000-0000-4000-a000-000000000002', now() - interval '5 days'),
  ('30000000-0000-4000-a000-000000000005', 'RNV-2610-00005', '00000000-0000-4000-a000-000000000004',
   'Ruang Kerja', 'ruang kerja', null, 'admin_processing', '00000000-0000-4000-a000-000000000002', now() - interval '7 days');

-- Nomor project berikutnya mulai setelah data seed
select setval('public.project_code_seq', 100);

-- Foto (P2–P5)
insert into public.room_photos (id, project_id, original_url, processed_url, width, height) values
  ('40000000-0000-4000-a000-000000000002', '30000000-0000-4000-a000-000000000002',
   'https://placehold.co/1200x800/png?text=Ruang+Tamu+-+Asli', 'https://placehold.co/1200x800/F3EBDD/333/png?text=Ruang+Tamu+-+Desain', 1200, 800),
  ('40000000-0000-4000-a000-000000000003', '30000000-0000-4000-a000-000000000003',
   'https://placehold.co/1200x800/png?text=Ruang+Keluarga+-+Asli', 'https://placehold.co/1200x800/A3B18A/fff/png?text=Ruang+Keluarga+-+Desain', 1200, 800),
  ('40000000-0000-4000-a000-000000000004', '30000000-0000-4000-a000-000000000004',
   'https://placehold.co/1200x800/png?text=Kamar+Anak+-+Asli', 'https://placehold.co/1200x800/B8B0A6/fff/png?text=Kamar+Anak+-+Desain', 1200, 800),
  ('40000000-0000-4000-a000-000000000005', '30000000-0000-4000-a000-000000000005',
   'https://placehold.co/1200x800/png?text=Ruang+Kerja+-+Asli', 'https://placehold.co/1200x800/A3B18A/fff/png?text=Ruang+Kerja+-+Desain', 1200, 800);

-- Wall paint
insert into public.wall_paints (id, project_id, photo_id, label, product_id, color_name, color_hex) values
  ('50000000-0000-4000-a000-000000000021', '30000000-0000-4000-a000-000000000002', '40000000-0000-4000-a000-000000000002',
   'Dinding utama', '20000000-0000-4000-a000-000000000001', 'Putih Gading', '#F3EBDD'),
  ('50000000-0000-4000-a000-000000000022', '30000000-0000-4000-a000-000000000002', '40000000-0000-4000-a000-000000000002',
   'Dinding samping', '20000000-0000-4000-a000-000000000003', 'Abu Hangat', '#B8B0A6'),
  ('50000000-0000-4000-a000-000000000031', '30000000-0000-4000-a000-000000000003', '40000000-0000-4000-a000-000000000003',
   'Dinding TV', '20000000-0000-4000-a000-000000000002', 'Sage Green', '#A3B18A'),
  ('50000000-0000-4000-a000-000000000041', '30000000-0000-4000-a000-000000000004', '40000000-0000-4000-a000-000000000004',
   'Semua dinding', '20000000-0000-4000-a000-000000000003', 'Abu Hangat', '#B8B0A6'),
  ('50000000-0000-4000-a000-000000000051', '30000000-0000-4000-a000-000000000005', '40000000-0000-4000-a000-000000000005',
   'Dinding belakang meja', '20000000-0000-4000-a000-000000000002', 'Sage Green', '#A3B18A');

-- Ukuran (luas = panjang × lebar)
insert into public.room_measurements (project_id, wall_paint_id, area_type, label, length, width, height, created_by) values
  ('30000000-0000-4000-a000-000000000002', '50000000-0000-4000-a000-000000000021', 'wall', 'Dinding utama',   4.0, 2.8, null, '00000000-0000-4000-a000-000000000003'),
  ('30000000-0000-4000-a000-000000000002', '50000000-0000-4000-a000-000000000022', 'wall', 'Dinding samping', 3.5, 2.8, null, '00000000-0000-4000-a000-000000000003'),
  ('30000000-0000-4000-a000-000000000003', '50000000-0000-4000-a000-000000000031', 'wall', 'Dinding TV',      5.0, 3.0, null, '00000000-0000-4000-a000-000000000003'),
  ('30000000-0000-4000-a000-000000000004', '50000000-0000-4000-a000-000000000041', 'wall', 'Dinding kiri',    3.0, 2.7, null, '00000000-0000-4000-a000-000000000004'),
  ('30000000-0000-4000-a000-000000000004', '50000000-0000-4000-a000-000000000041', 'wall', 'Dinding kanan',   3.0, 2.7, null, '00000000-0000-4000-a000-000000000004'),
  ('30000000-0000-4000-a000-000000000005', '50000000-0000-4000-a000-000000000051', 'wall', 'Dinding belakang',3.2, 2.8, null, '00000000-0000-4000-a000-000000000004');

-- Furnitur
insert into public.furniture_placements (project_id, photo_id, product_id, x, y, scale, rotation) values
  ('30000000-0000-4000-a000-000000000002', '40000000-0000-4000-a000-000000000002', '20000000-0000-4000-a000-000000000011', 0.30, 0.65, 1.0, 0),
  ('30000000-0000-4000-a000-000000000002', '40000000-0000-4000-a000-000000000002', '20000000-0000-4000-a000-000000000012', 0.45, 0.80, 0.8, 0),
  ('30000000-0000-4000-a000-000000000003', '40000000-0000-4000-a000-000000000003', '20000000-0000-4000-a000-000000000011', 0.50, 0.70, 1.1, 0),
  ('30000000-0000-4000-a000-000000000005', '40000000-0000-4000-a000-000000000005', '20000000-0000-4000-a000-000000000013', 0.70, 0.55, 0.9, 0);

-- -----------------------------------------------------------------------------
-- Hitung RAB untuk P3–P5, lalu pindahkan ke status akhirnya
-- -----------------------------------------------------------------------------
select private.calculate_rab('30000000-0000-4000-a000-000000000003', '00000000-0000-4000-a000-000000000002');
select private.calculate_rab('30000000-0000-4000-a000-000000000004', '00000000-0000-4000-a000-000000000002');
select private.calculate_rab('30000000-0000-4000-a000-000000000005', '00000000-0000-4000-a000-000000000002');

update public.projects set status = 'rab_draft'        where id = '30000000-0000-4000-a000-000000000003';
update public.projects set status = 'pending_approval' where id = '30000000-0000-4000-a000-000000000004';
update public.projects set status = 'approved'         where id = '30000000-0000-4000-a000-000000000005';

insert into public.approvals (project_id, rab_id, decision, note, decided_by)
select p.id, r.id, 'approved', 'RAB sesuai, silakan lanjut.', '00000000-0000-4000-a000-000000000001'
from public.projects p join public.rabs r on r.project_id = p.id
where p.id = '30000000-0000-4000-a000-000000000005';

-- Riwayat status agar timeline di web admin terisi
insert into public.project_status_history (project_id, from_status, to_status, changed_by, changed_at) values
  ('30000000-0000-4000-a000-000000000002', 'draft',            'sent_to_admin',    '00000000-0000-4000-a000-000000000003', now() - interval '1 day'),
  ('30000000-0000-4000-a000-000000000003', 'draft',            'sent_to_admin',    '00000000-0000-4000-a000-000000000003', now() - interval '3 days'),
  ('30000000-0000-4000-a000-000000000003', 'sent_to_admin',    'admin_processing', '00000000-0000-4000-a000-000000000002', now() - interval '2 days'),
  ('30000000-0000-4000-a000-000000000003', 'admin_processing', 'rab_draft',        '00000000-0000-4000-a000-000000000002', now() - interval '1 day'),
  ('30000000-0000-4000-a000-000000000004', 'draft',            'sent_to_admin',    '00000000-0000-4000-a000-000000000004', now() - interval '5 days'),
  ('30000000-0000-4000-a000-000000000004', 'sent_to_admin',    'admin_processing', '00000000-0000-4000-a000-000000000002', now() - interval '4 days'),
  ('30000000-0000-4000-a000-000000000004', 'admin_processing', 'rab_draft',        '00000000-0000-4000-a000-000000000002', now() - interval '3 days'),
  ('30000000-0000-4000-a000-000000000004', 'rab_draft',        'pending_approval', '00000000-0000-4000-a000-000000000002', now() - interval '2 days'),
  ('30000000-0000-4000-a000-000000000005', 'draft',            'sent_to_admin',    '00000000-0000-4000-a000-000000000004', now() - interval '7 days'),
  ('30000000-0000-4000-a000-000000000005', 'sent_to_admin',    'admin_processing', '00000000-0000-4000-a000-000000000002', now() - interval '6 days'),
  ('30000000-0000-4000-a000-000000000005', 'admin_processing', 'rab_draft',        '00000000-0000-4000-a000-000000000002', now() - interval '5 days'),
  ('30000000-0000-4000-a000-000000000005', 'rab_draft',        'pending_approval', '00000000-0000-4000-a000-000000000002', now() - interval '4 days'),
  ('30000000-0000-4000-a000-000000000005', 'pending_approval', 'approved',         '00000000-0000-4000-a000-000000000001', now() - interval '3 days');

-- -----------------------------------------------------------------------------
-- Data tambahan untuk web admin (Dashboard, Pesanan, Klien, Laporan)
-- Supaya setiap tab punya isi: pesanan baru, dikerjakan (semua tahap),
-- selesai (dengan snapshot final & laporan), dan ditolak.
--
--   P6  sent_to_admin     Dimas  (3 jam lalu)
--   P7  sent_to_admin     Maya
--   P8  ready_to_submit   Hendra (belum dikirim -> belum dianggap klien)
--   P9  correction        Sarah  (super admin minta koreksi)
--   P10 confirmed         Ari    (snapshot final)
--   P11 report_generated  Sarah  (snapshot + laporan)
--   P12 completed         Rina
--   P13 completed         Ari
--   P14 rejected          Dimas
--   P15 admin_processing  Maya   (ditangani Nadia, RAB belum dihitung)
-- -----------------------------------------------------------------------------
insert into public.projects (id, code, customer_id, title, room_type, notes, status, assigned_admin_id, submitted_at) values
  ('30000000-0000-4000-a000-000000000006', 'RNV-2610-00006', '00000000-0000-4000-a000-000000000008',
   'Rumah Tebet - Ruang Tamu', 'ruang tamu', 'Ingin nuansa hangat dan banyak penyimpanan', 'sent_to_admin', null, now() - interval '3 hours'),
  ('30000000-0000-4000-a000-000000000007', 'RNV-2610-00007', '00000000-0000-4000-a000-000000000009',
   'Kamar Tidur Utama', 'kamar tidur', null, 'sent_to_admin', null, now() - interval '2 days'),
  ('30000000-0000-4000-a000-000000000008', 'RNV-2610-00008', '00000000-0000-4000-a000-000000000011',
   'Ruang Makan', 'ruang makan', null, 'ready_to_submit', null, null),
  ('30000000-0000-4000-a000-000000000009', 'RNV-2610-00009', '00000000-0000-4000-a000-000000000006',
   'Apartemen Senopati - Ruang Keluarga', 'ruang keluarga', 'Gaya japandi, dominan kayu terang', 'admin_processing', '00000000-0000-4000-a000-000000000002', now() - interval '9 days'),
  ('30000000-0000-4000-a000-000000000010', 'RNV-2610-00010', '00000000-0000-4000-a000-000000000007',
   'Kafe Kala - Area Duduk', 'area komersial', 'Butuh banyak tempat duduk untuk 24 tamu', 'admin_processing', '00000000-0000-4000-a000-000000000005', now() - interval '12 days'),
  ('30000000-0000-4000-a000-000000000011', 'RNV-2610-00011', '00000000-0000-4000-a000-000000000006',
   'Apartemen Senopati - Kamar Tamu', 'kamar tidur', null, 'admin_processing', '00000000-0000-4000-a000-000000000005', now() - interval '15 days'),
  ('30000000-0000-4000-a000-000000000012', 'RNV-2610-00012', '00000000-0000-4000-a000-000000000010',
   'Ruang Kerja Rumah', 'ruang kerja', 'Fokus pencahayaan dan meja yang lega', 'admin_processing', '00000000-0000-4000-a000-000000000002', now() - interval '30 days'),
  ('30000000-0000-4000-a000-000000000013', 'RNV-2610-00013', '00000000-0000-4000-a000-000000000007',
   'Kafe Kala - Ruang Staf', 'area komersial', null, 'admin_processing', '00000000-0000-4000-a000-000000000005', now() - interval '40 days'),
  ('30000000-0000-4000-a000-000000000014', 'RNV-2610-00014', '00000000-0000-4000-a000-000000000008',
   'Garasi jadi Studio', 'studio', 'Anggaran terbatas', 'admin_processing', '00000000-0000-4000-a000-000000000002', now() - interval '20 days'),
  ('30000000-0000-4000-a000-000000000015', 'RNV-2610-00015', '00000000-0000-4000-a000-000000000009',
   'Ruang Tamu', 'ruang tamu', 'Sofa lama diganti', 'admin_processing', '00000000-0000-4000-a000-000000000005', now() - interval '4 days');

-- Foto, satu per project (P6–P15)
insert into public.room_photos (id, project_id, original_url, processed_url, width, height)
select
  ('40000000-0000-4000-a000-0000000000' || lpad(n::text, 2, '0'))::uuid,
  p.id,
  'https://placehold.co/1200x800/png?text=' || replace(p.title, ' ', '+') || '+-+Asli',
  'https://placehold.co/1200x800/' || (array['F3EBDD', 'A3B18A', 'B8B0A6'])[1 + n % 3] || '/333/png?text='
    || replace(p.title, ' ', '+') || '+-+Desain',
  1200, 800
from generate_series(6, 15) n
join public.projects p on p.id = ('30000000-0000-4000-a000-0000000000' || lpad(n::text, 2, '0'))::uuid;

-- Wall paint, satu per project (P6–P15). Cat dipilih bergantian.
insert into public.wall_paints (id, project_id, photo_id, label, product_id, color_name, color_hex)
select
  ('50000000-0000-4000-a000-000000000' || lpad(n::text, 2, '0') || '1')::uuid,
  ('30000000-0000-4000-a000-0000000000' || lpad(n::text, 2, '0'))::uuid,
  ('40000000-0000-4000-a000-0000000000' || lpad(n::text, 2, '0'))::uuid,
  'Dinding utama', pr.id, pr.color_name, pr.color_hex
from generate_series(6, 15) n
join public.products pr on pr.sku = (array['CAT-001', 'CAT-002', 'CAT-003'])[1 + n % 3];

-- Ukuran: dua bidang dinding per project, lebih besar untuk area komersial
insert into public.room_measurements (project_id, wall_paint_id, area_type, label, length, width, created_by)
select
  p.id,
  ('50000000-0000-4000-a000-000000000' || lpad(n::text, 2, '0') || '1')::uuid,
  'wall', 'Dinding ' || side.s,
  3.0 + (n % 4) + case when n in (10, 13) then 4 else 0 end, 2.8,
  p.customer_id
from generate_series(6, 15) n
cross join (values ('kiri'), ('kanan')) as side(s)
join public.projects p on p.id = ('30000000-0000-4000-a000-0000000000' || lpad(n::text, 2, '0'))::uuid;

-- Furnitur (qty = jumlah penempatan; RAB menghitung 1 unit per penempatan)
insert into public.furniture_placements (project_id, photo_id, product_id, x, y, scale)
select
  ('30000000-0000-4000-a000-0000000000' || lpad(f.n::text, 2, '0'))::uuid,
  ('40000000-0000-4000-a000-0000000000' || lpad(f.n::text, 2, '0'))::uuid,
  pr.id, 0.15 + 0.1 * g, 0.7, 1.0
from (values
  (6, 'SOFA-002', 1), (6, 'MEJA-001', 1),
  (7, 'LMR-001', 1),
  (9, 'SOFA-002', 1), (9, 'RAK-001', 1),
  (10, 'KRS-001', 6), (10, 'MEJA-001', 2),
  (11, 'LMR-001', 1),
  (12, 'MEJA-002', 1), (12, 'RAK-001', 1),
  (13, 'KRS-001', 3), (13, 'RAK-001', 1),
  (14, 'SOFA-001', 1),
  (15, 'SOFA-001', 1), (15, 'MEJA-001', 1)
) as f(n, sku, qty)
join public.products pr on pr.sku = f.sku
cross join lateral generate_series(1, f.qty) g;

-- Hitung RAB (P9–P14)
select private.calculate_rab(id, assigned_admin_id)
from public.projects
where code in ('RNV-2610-00009', 'RNV-2610-00010', 'RNV-2610-00011',
               'RNV-2610-00012', 'RNV-2610-00013', 'RNV-2610-00014');

-- Keputusan super admin
insert into public.approvals (project_id, rab_id, decision, note, decided_by, decided_at)
select p.id, r.id, a.decision::public.approval_decision, a.note,
       '00000000-0000-4000-a000-000000000001', now() - a.days * interval '1 day'
from (values
  ('RNV-2610-00009', 'correction', 'Tambahkan jasa pemasangan rak dan cek ulang ukuran dinding kanan.', 5),
  ('RNV-2610-00010', 'approved',   'RAB sesuai, silakan lanjut.', 8),
  ('RNV-2610-00011', 'approved',   'RAB sesuai, silakan lanjut.', 11),
  ('RNV-2610-00012', 'approved',   'RAB sesuai, silakan lanjut.', 25),
  ('RNV-2610-00013', 'approved',   'RAB sesuai, silakan lanjut.', 35),
  ('RNV-2610-00014', 'rejected',   'Anggaran klien tidak mencukupi untuk lingkup pekerjaan ini.', 16)
) as a(code, decision, note, days)
join public.projects p on p.code = a.code
join public.rabs r on r.project_id = p.id;

-- Snapshot final untuk project yang sudah confirmed (P10–P13)
update public.projects set status = 'confirmed'
where code in ('RNV-2610-00010', 'RNV-2610-00011', 'RNV-2610-00012', 'RNV-2610-00013');

update public.projects set final_snapshot_id = private.create_final_snapshot(id, assigned_admin_id)
where code in ('RNV-2610-00010', 'RNV-2610-00011', 'RNV-2610-00012', 'RNV-2610-00013');

-- Laporan PDF (placeholder, bukan file di Storage) untuk P11–P13
insert into public.reports (project_id, snapshot_id, pdf_url, generated_by, generated_at)
select p.id, p.final_snapshot_id,
       'https://placehold.co/600x800/png?text=Laporan+RAB+' || p.code,
       p.assigned_admin_id, now() - r.days * interval '1 day'
from (values ('RNV-2610-00011', 9), ('RNV-2610-00012', 23), ('RNV-2610-00013', 33)) as r(code, days)
join public.projects p on p.code = r.code;

-- Status akhir
update public.projects set status = 'correction'       where code = 'RNV-2610-00009';
update public.projects set status = 'report_generated' where code = 'RNV-2610-00011';
update public.projects set status = 'completed'        where code in ('RNV-2610-00012', 'RNV-2610-00013');
update public.projects set status = 'rejected'         where code = 'RNV-2610-00014';

-- Riwayat status (timeline & tanggal serah terima)
insert into public.project_status_history (project_id, from_status, to_status, note, changed_by, changed_at)
select p.id, h.from_s::public.project_status, h.to_s::public.project_status, h.note,
       case h.actor when 'customer' then p.customer_id
                    when 'super'    then '00000000-0000-4000-a000-000000000001'::uuid
                    else p.assigned_admin_id end,
       now() - h.days * interval '1 day'
from (values
  ('RNV-2610-00006', 'draft',            'sent_to_admin',    null, 'customer', 0.125),
  ('RNV-2610-00007', 'draft',            'sent_to_admin',    null, 'customer', 2),
  ('RNV-2610-00009', 'draft',            'sent_to_admin',    null, 'customer', 9),
  ('RNV-2610-00009', 'sent_to_admin',    'admin_processing', null, 'admin',    8),
  ('RNV-2610-00009', 'admin_processing', 'rab_draft',        null, 'admin',    7),
  ('RNV-2610-00009', 'rab_draft',        'pending_approval', null, 'admin',    6),
  ('RNV-2610-00009', 'pending_approval', 'correction',       'Tambahkan jasa pemasangan rak dan cek ulang ukuran dinding kanan.', 'super', 5),
  ('RNV-2610-00010', 'draft',            'sent_to_admin',    null, 'customer', 12),
  ('RNV-2610-00010', 'sent_to_admin',    'admin_processing', null, 'admin',    11),
  ('RNV-2610-00010', 'admin_processing', 'rab_draft',        null, 'admin',    10),
  ('RNV-2610-00010', 'rab_draft',        'pending_approval', null, 'admin',    9),
  ('RNV-2610-00010', 'pending_approval', 'approved',         null, 'super',    8),
  ('RNV-2610-00010', 'approved',         'confirmed',        null, 'admin',    7),
  ('RNV-2610-00011', 'draft',            'sent_to_admin',    null, 'customer', 15),
  ('RNV-2610-00011', 'sent_to_admin',    'admin_processing', null, 'admin',    14),
  ('RNV-2610-00011', 'admin_processing', 'rab_draft',        null, 'admin',    13),
  ('RNV-2610-00011', 'rab_draft',        'pending_approval', null, 'admin',    12),
  ('RNV-2610-00011', 'pending_approval', 'approved',         null, 'super',    11),
  ('RNV-2610-00011', 'approved',         'confirmed',        null, 'admin',    10),
  ('RNV-2610-00011', 'confirmed',        'report_generated', null, 'admin',    9),
  ('RNV-2610-00012', 'draft',            'sent_to_admin',    null, 'customer', 30),
  ('RNV-2610-00012', 'sent_to_admin',    'admin_processing', null, 'admin',    29),
  ('RNV-2610-00012', 'admin_processing', 'rab_draft',        null, 'admin',    27),
  ('RNV-2610-00012', 'rab_draft',        'pending_approval', null, 'admin',    26),
  ('RNV-2610-00012', 'pending_approval', 'approved',         null, 'super',    25),
  ('RNV-2610-00012', 'approved',         'confirmed',        null, 'admin',    24),
  ('RNV-2610-00012', 'confirmed',        'report_generated', null, 'admin',    23),
  ('RNV-2610-00012', 'report_generated', 'completed',        null, 'admin',    12),
  ('RNV-2610-00013', 'draft',            'sent_to_admin',    null, 'customer', 40),
  ('RNV-2610-00013', 'sent_to_admin',    'admin_processing', null, 'admin',    39),
  ('RNV-2610-00013', 'admin_processing', 'rab_draft',        null, 'admin',    37),
  ('RNV-2610-00013', 'rab_draft',        'pending_approval', null, 'admin',    36),
  ('RNV-2610-00013', 'pending_approval', 'approved',         null, 'super',    35),
  ('RNV-2610-00013', 'approved',         'confirmed',        null, 'admin',    34),
  ('RNV-2610-00013', 'confirmed',        'report_generated', null, 'admin',    33),
  ('RNV-2610-00013', 'report_generated', 'completed',        null, 'admin',    25),
  ('RNV-2610-00014', 'draft',            'sent_to_admin',    null, 'customer', 20),
  ('RNV-2610-00014', 'sent_to_admin',    'admin_processing', null, 'admin',    19),
  ('RNV-2610-00014', 'admin_processing', 'rab_draft',        null, 'admin',    18),
  ('RNV-2610-00014', 'rab_draft',        'pending_approval', null, 'admin',    17),
  ('RNV-2610-00014', 'pending_approval', 'rejected',         'Anggaran klien tidak mencukupi untuk lingkup pekerjaan ini.', 'super', 16),
  ('RNV-2610-00015', 'draft',            'sent_to_admin',    null, 'customer', 4),
  ('RNV-2610-00015', 'sent_to_admin',    'admin_processing', null, 'admin',    3)
) as h(code, from_s, to_s, note, actor, days)
join public.projects p on p.code = h.code;

-- Tanggal daftar akun yang masuk akal: staff 60 hari lalu, customer beberapa
-- hari sebelum pesanan pertamanya (customer tanpa pesanan: 1 hari lalu).
update public.profiles set created_at = now() - interval '60 days' where role <> 'customer';
update public.profiles c set created_at = coalesce(
  (select min(p.submitted_at) from public.projects p where p.customer_id = c.id),
  now()
) - interval '3 days'
where c.role = 'customer';

-- -----------------------------------------------------------------------------
-- Notifikasi & chat contoh
-- -----------------------------------------------------------------------------
insert into public.notifications (user_id, project_id, type, title, body) values
  ('00000000-0000-4000-a000-000000000002', '30000000-0000-4000-a000-000000000002', 'project_submitted', 'Project baru masuk', 'RNV-2610-00002 — Ruang Tamu'),
  ('00000000-0000-4000-a000-000000000001', '30000000-0000-4000-a000-000000000004', 'approval_requested', 'Menunggu persetujuan', 'RNV-2610-00004 — Kamar Anak'),
  ('00000000-0000-4000-a000-000000000002', '30000000-0000-4000-a000-000000000006', 'project_submitted', 'Project baru masuk', 'RNV-2610-00006 — Rumah Tebet - Ruang Tamu'),
  ('00000000-0000-4000-a000-000000000005', '30000000-0000-4000-a000-000000000007', 'project_submitted', 'Project baru masuk', 'RNV-2610-00007 — Kamar Tidur Utama'),
  ('00000000-0000-4000-a000-000000000002', '30000000-0000-4000-a000-000000000009', 'approval_correction', 'RAB perlu dikoreksi', 'RNV-2610-00009 — Apartemen Senopati - Ruang Keluarga'),
  ('00000000-0000-4000-a000-000000000007', '30000000-0000-4000-a000-000000000013', 'project_completed', 'Project selesai', 'RNV-2610-00013 — Kafe Kala - Ruang Staf');

insert into public.conversations (id, customer_id, order_code) values
  ('60000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000003', 'RNV-2610-00003');

insert into public.messages (conversation_id, sender_id, body, created_at) values
  ('60000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000003',
   'Halo admin, apakah warna sage green bisa dibuat sedikit lebih gelap?', now() - interval '2 hours'),
  ('60000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002',
   'Bisa, Pak Budi. Kami siapkan alternatif warnanya di revisi RAB.', now() - interval '1 hour');
