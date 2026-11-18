# Kontrak FE: chat customer ↔ admin (`conversations`, `messages`, `admin_conversations`)

Dipakai halaman **Chat** di web admin (`renovin-web/app/workplace/chat`) dan fitur chat di **aplikasi Android** (customer).

Semua pemanggilan memakai client Supabase yang sudah ada. Tipe TypeScript-nya ada di `types/database.types.ts`.

Kontrak data lainnya: lihat daftar di README repo backend.

## Konsep

- Satu **percakapan** (`conversations`) dibuka **oleh customer**, opsional dengan nomor pesanan (`order_code`). Kalau ada nomor pesanan, percakapan terhubung ke pesanan itu (`project_id`).
- Setiap pesanan hanya boleh punya **satu percakapan terbuka**.
- **Semua staff** (admin dan super admin) bisa membaca dan membalas semua percakapan.
- Percakapan bisa **ditutup** dan **dibuka lagi** oleh staff. Selama ditutup, tidak ada yang bisa mengirim pesan.
- Pesan hanya teks (1–4000 karakter). `attachment_url` sudah ada kolomnya tapi **belum dipakai**.

## Data

### `conversations`

| Kolom | Isi |
|---|---|
| `id` | UUID |
| `customer_id` | Customer pemilik (otomatis = user yang login saat membuat) |
| `order_code`, `project_id` | Nomor pesanan (opsional); `project_id` diisi otomatis dari `order_code` milik customer itu. Nomor salah → error `P0002` "Nomor pesanan … tidak ditemukan" |
| `status` | `open` / `closed` |
| `last_message_at` | Waktu pesan terakhir (diperbarui otomatis) |

### `messages`

| Kolom | Isi |
|---|---|
| `id` | Angka berurutan |
| `conversation_id` | Percakapan |
| `sender_id` | Pengirim (otomatis = user yang login). Pesan dari customer kalau `sender_id = conversations.customer_id` |
| `body` | Isi pesan |
| `read_at` | Waktu dibaca oleh pihak lawan. `null` = belum dibaca |
| `created_at` | Waktu kirim |

### View `admin_conversations` (khusus staff; customer selalu 0 baris)

`id, status, created_at, last_message_at, customer_id, customer_name, customer_email, customer_phone, project_id, order_code, project_title, project_status, assigned_admin_id, assigned_admin_name, last_message_body, last_message_sender_id, last_message_from_customer, message_count, unread_count`

`unread_count` = pesan **dari customer** yang belum dibaca staff.

## Hak akses

| | Customer | Admin & super admin |
|---|---|---|
| Buat percakapan | ✓ (miliknya, nomor pesanan miliknya) | — |
| Baca percakapan & pesan | Miliknya | Semua |
| Kirim pesan | Di percakapan miliknya yang `open` | Di semua percakapan `open` |
| Tandai dibaca (`read_at`) | Pesan dari staff | Pesan dari orang lain |
| Tutup / buka lagi (`status`) | — | ✓ |

## Notifikasi (`notifications`)

| `type` | Penerima | Kapan |
|---|---|---|
| `chat_opened` | Semua admin | Customer membuka percakapan baru |
| `chat_message` | Admin penanggung jawab pesanan; kalau belum ada, semua admin | Customer mengirim pesan **lanjutan** di percakapan yang sudah ada (**baru**, migration 018) |
| `chat_reply` | Customer | Staff membalas |

## Realtime

`messages` dan `conversations` sudah masuk publication `supabase_realtime`. RLS tetap berlaku untuk realtime, jadi customer hanya menerima perubahan miliknya.

```ts
supabase
  .channel(`chat-${conversationId}`)
  .on("postgres_changes", { event: "INSERT", schema: "public", table: "messages", filter: `conversation_id=eq.${conversationId}` },
      (payload) => addMessage(payload.new))
  .subscribe();
```

## Contoh pemanggilan

```ts
// Customer (Android): buka percakapan, lalu kirim pesan pertama
const { data: conv, error } = await supabase
  .from("conversations").insert({ order_code: "RNV-2610-00004" }).select("id").single();
await supabase.from("messages").insert({ conversation_id: conv.id, body: "Halo, mau tanya RAB" });

// Staff (web): daftar percakapan, terbaru di atas
const { data } = await supabase.from("admin_conversations").select("*").order("last_message_at", { ascending: false });

// Isi percakapan
const { data: msgs } = await supabase
  .from("messages").select("id, sender_id, body, read_at, created_at")
  .eq("conversation_id", id).order("created_at");

// Balas
await supabase.from("messages").insert({ conversation_id: id, body: "Baik, kami cek dulu" });

// Tandai pesan dari pihak lain sudah dibaca
await supabase.from("messages").update({ read_at: new Date().toISOString() })
  .eq("conversation_id", id).is("read_at", null).neq("sender_id", myUserId);

// Tutup / buka lagi (staff)
await supabase.from("conversations").update({ status: "closed" }).eq("id", id);
```

## Belum tersedia

- Lampiran (foto/file) di pesan.
- Staff memulai percakapan lebih dulu.
- Integrasi WhatsApp.
- Indikator "sedang mengetik".
