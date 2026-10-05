-- =============================================================================
-- Seed data — HANYA untuk lokal & renovin-dev. JANGAN dijalankan di prod.
--
-- Akun uji (password sama untuk semua): Renovin#Dev2026
--   superadmin@renovin.test   super_admin
--   admin@renovin.test        admin
--   customer1@renovin.test    customer  (punya project P1, P2, P3)
--   customer2@renovin.test    customer  (punya project P4, P5)
--
-- Foto memakai placeholder (placehold.co), bukan file ImageKit sungguhan.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Akun
-- -----------------------------------------------------------------------------
with seed_users (id, email, full_name) as (
  values
    ('00000000-0000-4000-a000-000000000001'::uuid, 'superadmin@renovin.test', 'Super Admin Renovin'),
    ('00000000-0000-4000-a000-000000000002'::uuid, 'admin@renovin.test',      'Admin Renovin'),
    ('00000000-0000-4000-a000-000000000003'::uuid, 'customer1@renovin.test',  'Budi Santoso'),
    ('00000000-0000-4000-a000-000000000004'::uuid, 'customer2@renovin.test',  'Siti Rahma')
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

-- -----------------------------------------------------------------------------
-- Katalog
-- -----------------------------------------------------------------------------
insert into public.product_categories (id, name, slug, type, sort_order) values
  ('10000000-0000-4000-a000-000000000001', 'Cat Dinding Interior', 'cat-interior', 'paint',     1),
  ('10000000-0000-4000-a000-000000000002', 'Sofa',                 'sofa',         'furniture', 2),
  ('10000000-0000-4000-a000-000000000003', 'Meja',                 'meja',         'furniture', 3),
  ('10000000-0000-4000-a000-000000000004', 'Lemari & Rak',         'lemari-rak',   'furniture', 4);

insert into public.products (
  id, category_id, type, sku, name, unit, price_customer, color_name, color_hex,
  width_cm, depth_cm, height_cm, image_url, asset_url, active, created_by
) values
  -- Cat (harga per m2)
  ('20000000-0000-4000-a000-000000000001', '10000000-0000-4000-a000-000000000001', 'paint', 'CAT-001',
   'Cat Interior Putih Gading', 'm2', 35000, 'Putih Gading', '#F3EBDD', null, null, null,
   'https://placehold.co/400x400/F3EBDD/333?text=Putih+Gading', null, true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000002', '10000000-0000-4000-a000-000000000001', 'paint', 'CAT-002',
   'Cat Interior Sage Green', 'm2', 38000, 'Sage Green', '#A3B18A', null, null, null,
   'https://placehold.co/400x400/A3B18A/fff?text=Sage+Green', null, true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000003', '10000000-0000-4000-a000-000000000001', 'paint', 'CAT-003',
   'Cat Interior Abu Hangat', 'm2', 36000, 'Abu Hangat', '#B8B0A6', null, null, null,
   'https://placehold.co/400x400/B8B0A6/fff?text=Abu+Hangat', null, true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000004', '10000000-0000-4000-a000-000000000001', 'paint', 'CAT-004',
   'Cat Interior Terracotta (nonaktif)', 'm2', 40000, 'Terracotta', '#C2703D', null, null, null,
   'https://placehold.co/400x400/C2703D/fff?text=Terracotta', null, false, '00000000-0000-4000-a000-000000000002'),
  -- Furnitur (harga per unit)
  ('20000000-0000-4000-a000-000000000011', '10000000-0000-4000-a000-000000000002', 'furniture', 'SOFA-001',
   'Sofa 3 Dudukan Linen Abu', 'pcs', 4500000, null, null, 200, 85, 80,
   'https://placehold.co/400x300?text=Sofa+3+Dudukan', 'https://placehold.co/800x400/png?text=Sofa+Asset', true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000012', '10000000-0000-4000-a000-000000000003', 'furniture', 'MEJA-001',
   'Meja Kopi Kayu Jati', 'pcs', 1750000, null, null, 100, 55, 45,
   'https://placehold.co/400x300?text=Meja+Kopi', 'https://placehold.co/800x400/png?text=Meja+Asset', true, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000013', '10000000-0000-4000-a000-000000000004', 'furniture', 'RAK-001',
   'Rak Buku Minimalis 5 Susun', 'pcs', 1250000, null, null, 80, 30, 180,
   'https://placehold.co/400x300?text=Rak+Buku', 'https://placehold.co/800x400/png?text=Rak+Asset', true, '00000000-0000-4000-a000-000000000002');

insert into public.product_internal_prices (product_id, price_internal, updated_by) values
  ('20000000-0000-4000-a000-000000000001',   22000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000002',   24000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000003',   23000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000004',   26000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000011', 3200000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000012', 1100000, '00000000-0000-4000-a000-000000000002'),
  ('20000000-0000-4000-a000-000000000013',  800000, '00000000-0000-4000-a000-000000000002');

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
   'https://placehold.co/1200x800?text=Ruang+Tamu+-+Asli', 'https://placehold.co/1200x800/F3EBDD/333?text=Ruang+Tamu+-+Desain', 1200, 800),
  ('40000000-0000-4000-a000-000000000003', '30000000-0000-4000-a000-000000000003',
   'https://placehold.co/1200x800?text=Ruang+Keluarga+-+Asli', 'https://placehold.co/1200x800/A3B18A/fff?text=Ruang+Keluarga+-+Desain', 1200, 800),
  ('40000000-0000-4000-a000-000000000004', '30000000-0000-4000-a000-000000000004',
   'https://placehold.co/1200x800?text=Kamar+Anak+-+Asli', 'https://placehold.co/1200x800/B8B0A6/fff?text=Kamar+Anak+-+Desain', 1200, 800),
  ('40000000-0000-4000-a000-000000000005', '30000000-0000-4000-a000-000000000005',
   'https://placehold.co/1200x800?text=Ruang+Kerja+-+Asli', 'https://placehold.co/1200x800/A3B18A/fff?text=Ruang+Kerja+-+Desain', 1200, 800);

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
-- Notifikasi & chat contoh
-- -----------------------------------------------------------------------------
insert into public.notifications (user_id, project_id, type, title, body) values
  ('00000000-0000-4000-a000-000000000002', '30000000-0000-4000-a000-000000000002', 'project_submitted', 'Project baru masuk', 'RNV-2610-00002 — Ruang Tamu'),
  ('00000000-0000-4000-a000-000000000001', '30000000-0000-4000-a000-000000000004', 'approval_requested', 'Menunggu persetujuan', 'RNV-2610-00004 — Kamar Anak');

insert into public.conversations (id, customer_id, order_code) values
  ('60000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000003', 'RNV-2610-00003');

insert into public.messages (conversation_id, sender_id, body, created_at) values
  ('60000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000003',
   'Halo admin, apakah warna sage green bisa dibuat sedikit lebih gelap?', now() - interval '2 hours'),
  ('60000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000000002',
   'Bisa, Pak Budi. Kami siapkan alternatif warnanya di revisi RAB.', now() - interval '1 hour');
