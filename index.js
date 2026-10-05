import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import ImageKit from "imagekit";
import { createClient } from "@supabase/supabase-js";

dotenv.config();

const app = express();
const PORT = process.env.PORT || 8080;

// 1. Setup CORS
app.use(
  cors({
    origin: [process.env.FRONTEND_URL, "https://*.vercel.app"],
    credentials: true,
  }),
);
app.use(express.json());

// 2. Inisialisasi Client ImageKit & Supabase
const imagekit = new ImageKit({
  publicKey: process.env.IMAGEKIT_PUBLIC_KEY,
  privateKey: process.env.IMAGEKIT_PRIVATE_KEY,
  urlEndpoint: process.env.IMAGEKIT_URL_ENDPOINT,
});

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_ANON_KEY,
);

// 3. Endpoint Auth ImageKit (dipanggil frontend saat upload)
app.get("/api/imagekit-auth", (req, res) => {
  try {
    const authParams = imagekit.getAuthenticationParameters();
    res.json(authParams);
  } catch (error) {
    res.status(500).json({ error: "Gagal membuat token ImageKit" });
  }
});

// 4. Endpoint Tambahan (Opsional): Simpan laporan proyek ke Supabase via Backend
app.post("/api/project-updates", async (req, res) => {
  const { project_id, title, notes, photo_url } = req.body;

  const { data, error } = await supabase
    .from("project_updates")
    .insert([{ project_id, title, notes, photo_url }]);

  if (error) {
    return res.status(400).json({ error: error.message });
  }

  res.status(201).json({ success: true, data });
});

// 5. Jalankan Server
app.listen(PORT, () => {
  console.log(`Backend Renovin berjalan di http://localhost:${PORT}`);
});
