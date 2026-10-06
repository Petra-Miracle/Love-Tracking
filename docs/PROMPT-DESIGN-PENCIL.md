# Prompt: Design Mockup "Love Tracking" (Android App)

Kamu adalah senior product designer (mobile, Material Design 3). Buat **mockup high-fidelity** untuk aplikasi Android **Love Tracking** di file `.pen` baru bernama `love-tracking.pen`.

Aplikasi ini **sudah dibangun** di Flutter. Desain harus mengikuti **struktur layar, komponen, dan teks (copy) yang tertulis di dokumen ini**, supaya hasil desain bisa langsung diterapkan ke kode tanpa mengubah alur. Kamu bebas memperindah gaya visual (spacing, shadow, ilustrasi, detail ikon), tapi **jangan menambah atau menghapus fitur/layar**.

---

## 1. Konsep Produk

**Love Tracking** adalah aplikasi khusus **pasangan (tepat 2 orang)** untuk saling melihat secara *real-time*:

1. **Lokasi** pasangan di peta (bergerak live saat berjalan/berkendara).
2. **Baterai** pasangan: persentase + sedang mengisi / penuh.
3. **Jaringan** pasangan: Wi-Fi / data seluler / offline, plus **nama operator** (Telkomsel, Indosat, XL, dll.) dan generasi jaringan (4G/5G).

Alur utama:

```
Login Google ──▶ Hubungkan Pasangan (kode undangan) ──▶ Beri izin lokasi ──▶ Peta live berdua
```

**Nuansa desain:** hangat, romantis, tapi tetap bersih dan tenang — bukan aplikasi "pengawasan". Fokus pada rasa *dekat* ("Kamu & Budi"), bukan *memata-matai*. Privasi terlihat jelas (ada tombol jeda berbagi lokasi).

**Platform:** Android saja. **Bahasa UI:** Bahasa Indonesia (santai, pakai "kamu").

---

## 2. Design System

Buat dulu halaman/frame **"Design System"** berisi token & komponen yang dipakai ulang di semua layar.

### Warna

| Token | Light | Dark | Pemakaian |
|---|---|---|---|
| `love` (primary/seed) | `#E91E63` | `#E91E63` | Aksen utama, hati, pin pasangan, tombol utama |
| `me` | `#2979FF` | `#2979FF` | Titik lokasi diri sendiri |
| `success` | `#2E7D32` | `#66BB6A` | Ikon baterai saat mengisi/penuh |
| `error` | Material 3 error | Material 3 error | Baterai ≤15%, banner izin |
| Surface/background | Material 3 tonal palette dari seed `#E91E63` | idem (dark) | Card, sheet, background |
| `stale` | `#9E9E9E` | `#9E9E9E` | Pin pasangan jika data > 15 menit |

Gunakan **Material 3 color scheme yang diturunkan dari seed `#E91E63`** (primary, primaryContainer, surfaceContainerHighest, errorContainer, dll.).

### Tipografi
Material 3 type scale, font **Roboto** (default Android). Opsional: judul app "Love Tracking" boleh memakai font display yang lebih personal (mis. *Poppins SemiBold*) — sebutkan jika dipakai.

### Bentuk & Spacing
- Radius tombol & input: **16**
- Radius card: **12–16**; radius stat chip: **12**
- Padding layar: **24** (login/pairing), **12** (overlay di atas peta)
- Tinggi tombol utama: **52**, lebar penuh

### Komponen (buat sebagai komponen reusable)

| Komponen | Deskripsi |
|---|---|
| **Primary Button** | Filled, warna `love`, ikon kiri opsional, state: default / loading (spinner 20px) / disabled |
| **Tonal Button** & **Outlined Button** | Varian sekunder |
| **Code Input** | TextField 6 karakter, huruf besar, rata tengah, *letter-spacing* lebar (±8), placeholder `XXXXXX` |
| **Invite Code Display** | Kode besar tebal (displaySmall), letter-spacing lebar, mis. `K7P2QX` |
| **Section Card** | Card dengan header (ikon `love` + judul) + konten |
| **Avatar** | Lingkaran foto Google; fallback huruf awal nama berwarna `love` di atas `love` 15% |
| **Partner Pin (map marker)** | Avatar 48px dengan ring `love` 3px + shadow, segitiga penunjuk di bawah. Varian **stale** = ring abu-abu |
| **Me Dot (map marker)** | Lingkaran biru `me` 24px, border putih 3px, shadow |
| **Accuracy Circle** | Lingkaran `love` 12% fill + border 40% di sekitar pin pasangan |
| **Connection Line** | Garis putus-putus `love` 50% antara titik saya & pasangan |
| **Stat Chip** | Ikon 18px + label, background `surfaceContainerHighest`. Varian: baterai, jaringan, SIM, jarak, kecepatan |
| **Top Bar Card** | Card berisi ikon hati + "Kamu & {Nama}" + tombol menu ⋮ |
| **Partner Card** | Card bawah (lihat Layar 6) |
| **Permission Banner** | Card `errorContainer` + teks + tombol teks "Izinkan" |
| **Info Chip** | Chip kecil dengan ikon, mis. status jeda |
| **Map FAB small** | FAB kecil: "Lihat berdua" (zoom_out_map), "Lokasiku" (my_location) |

### Ikon (Material Symbols)
`favorite`, `favorite_border`, `heart_broken`, `login`, `logout`, `add_link`, `share`, `copy`, `vpn_key`, `mail_outline`, `pause_circle`, `play_circle`, `my_location`, `zoom_out_map`, `center_focus_strong`, `straighten`, `directions_run`, `sim_card`, `wifi`, `signal_cellular_alt`, `signal_cellular_off`, `vpn_lock`, `battery_full`, `battery_5_bar`, `battery_4_bar`, `battery_2_bar`, `battery_alert`, `battery_charging_full`, `battery_unknown`, `cloud_off`.

---

## 3. Spesifikasi Frame

- Ukuran frame: **360 × 800** (Android standar), sertakan **status bar** Android (jam, sinyal, baterai) dan **gesture navigation bar**.
- Buat **light mode** untuk semua layar. Buat **dark mode** minimal untuk Layar 6A (Peta utama).
- Peta: gunakan gaya **OpenStreetMap** standar (jalan, blok bangunan, area hijau) — boleh berupa ilustrasi/placeholder yang mirip tile OSM area **Jakarta**. Sertakan atribusi kecil di kiri bawah: `© OpenStreetMap contributors`.
- Data contoh: pengguna **"Ana Putri"**, pasangan **"Budi Santoso"** (pakai avatar placeholder).

---

## 4. Daftar Layar

Gunakan **teks persis** seperti di bawah (teks dalam tanda kutip).

### Layar 1 — Login
- Ikon hati besar (96px, `love`) di tengah atas.
- Judul: "Love Tracking"
- Subjudul: "Lihat lokasi, baterai, dan jaringan pasanganmu secara real-time."
- Tombol utama di bawah (ikon login): "Masuk dengan Google"

**1B — Login dengan undangan tertunda** (pengguna membuka link undangan sebelum login): sama seperti Layar 1, ditambah card di bawah subjudul:
- Ikon `mail_outline` (`love`), judul "Kamu punya undangan!", subjudul "Masuk dulu untuk terhubung dengan pasanganmu."

**1C — Loading:** tombol dalam state loading (spinner) & disabled.

### Layar 2 — Hubungkan Pasangan (awal)
- AppBar: judul "Hubungkan Pasangan", aksi kanan ikon logout (tooltip "Keluar").
- Sapaan: "Hai, Ana 👋"
- Deskripsi: "Hubungkan akunmu dengan pasangan. Salah satu dari kalian membuat kode, yang lain memasukkannya."
- **Section Card 1** — ikon `favorite_border`, judul "Undang pasangan", tombol utama (ikon add_link) "Buat kode undangan"
- **Section Card 2** — ikon `vpn_key`, judul "Punya kode dari pasangan?", Code Input (placeholder `XXXXXX`), Tonal Button "Hubungkan"

### Layar 3 — Hubungkan Pasangan (kode sudah dibuat)
Section Card 1 berubah menjadi:
- Kode besar: `K7P2QX`
- Teks kecil: "Berlaku sampai besok pukul 14.30. Menunggu pasangan bergabung…"
- Dua tombol sejajar: Outlined (ikon copy) "Salin" | Filled (ikon share) "Bagikan"
- Text button: "Buat kode baru"

**3B — Snackbar:** tampilkan contoh snackbar floating "Kode disalin".

**3C — Share sheet Android** (opsional): bottom sheet berbagi dengan pratinjau teks:
> Ana mengajakmu terhubung di Love Tracking 💕
> Buka link ini di HP yang sudah terpasang aplikasinya: lovetracking://invite?code=K7P2QX
> Atau masukkan kode: K7P2QX

### Layar 4 — Memasukkan kode & error
- **4A:** Code Input terisi `K7P2QX`, tombol berubah "Menghubungkan…" (disabled).
- **4B:** Snackbar error: "Kode undangan tidak ditemukan atau sudah kedaluwarsa."

### Layar 5 — Permintaan Izin (dialog sistem Android)
Tampilkan di atas Layar 6 (peta) yang diredupkan, urut:
1. Dialog izin lokasi Android ("Allow Love Tracking to access this device's location?") — sorot opsi *While using the app*.
2. Halaman setelan lokasi dengan opsi **"Allow all the time"** terpilih.
3. Dialog notifikasi.
4. Dialog "Abaikan pengoptimalan baterai?"

(Ini layar sistem — cukup mock sederhana sebagai panduan onboarding.)

### Layar 6 — Peta Utama (layar inti, paling penting)
Struktur (peta full-screen, elemen lain melayang di atasnya):

```
┌──────────────────────────────┐
│ [♥ Kamu & Budi          ⋮ ]  │ ← Top Bar Card
│                              │
│        (peta OSM)            │
│     ● (saya)                 │
│        ╲ garis putus-putus   │
│         ╲                    │
│          (◉ pin Budi)        │
│                       [⤢]    │ ← FAB "Lihat berdua"
│                       [◎]    │ ← FAB "Lokasiku"
│ ┌──────────────────────────┐ │
│ │ (avatar) Budi Santoso  ⌖ │ │ ← Partner Card
│ │ Diperbarui baru saja     │ │
│ │ [🔋76% · mengisi] [📶Telkomsel 4G] │
│ │ [📏3,2 km] [🏃 36 km/j]  │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

Variasi yang harus dibuat:

| Frame | Kondisi | Isi Partner Card |
|---|---|---|
| **6A** Normal (bergerak) | Pasangan berkendara | Subjudul "Diperbarui baru saja"; chip: "76% · mengisi" (ikon hijau), "Telkomsel 4G", "3,2 km", "36 km/j" |
| **6B** Di rumah (Wi-Fi) | Diam, terhubung Wi-Fi | "Diperbarui 2 menit lalu"; chip: "54%", "Wi-Fi", chip SIM "Indosat", "850 m" |
| **6C** Baterai lemah | | chip baterai "12%" dengan ikon `battery_alert` warna error |
| **6D** Pasangan menjeda | Lokasi pasangan disembunyikan (tidak ada pin) | "Berbagi lokasi dijeda · 5 menit lalu"; chip baterai & jaringan tetap tampil; tidak ada tombol fokus |
| **6E** Data lama (stale) | Update terakhir > 15 menit | Pin abu-abu; "Terakhir aktif 2 jam lalu"; chip jaringan "Offline" (ikon signal_cellular_off) |
| **6F** Menunggu data pertama | Baru terhubung | Peta zoom ke Indonesia; card: "Menunggu data pertama dari Budi…" tanpa chip |
| **6G** Saya menjeda | Titik saya hilang | Info Chip di bawah top bar: ikon pause, "Berbagi lokasimu sedang dijeda" |
| **6H** Izin kurang | | Permission Banner di bawah top bar: "Agar lokasimu tetap terkirim saat HP terkunci, aktifkan: lokasi "Izinkan sepanjang waktu", pengecualian penghemat baterai." + tombol "Izinkan" |
| **6I** Dark mode | Sama seperti 6A | — |

### Layar 7 — Menu (⋮ di Top Bar)
Popup menu dengan 3 item (ikon + teks):
- `pause_circle` "Jeda berbagi lokasi" (saat dijeda berubah menjadi `play_circle` "Lanjutkan berbagi lokasi")
- `heart_broken` "Putuskan pasangan"
- `logout` "Keluar"

### Layar 8 — Dialog Putuskan Pasangan
- Judul: "Putuskan pasangan?"
- Isi: "Kamu dan Budi tidak akan bisa saling melihat lokasi lagi. Kalian perlu kode undangan baru untuk terhubung kembali."
- Aksi: text button "Batal", filled button "Putuskan"

### Layar 9 — Notifikasi Foreground Service
Mock notification shade Android berisi notifikasi persisten:
- Judul: "Love Tracking aktif 💕"
- Isi: "Berbagi lokasi dengan pasangan" (varian dijeda: "Berbagi lokasi sedang dijeda")

### Layar 10 — Error Koneksi
- Ikon `cloud_off` 64px di tengah
- Teks: "Tidak bisa terhubung ke server. Periksa koneksi internet."
- Tombol: "Coba lagi"

### (Opsional) Layar 11 — App Icon
Ikon launcher adaptif Android: hati `love` dengan elemen pin lokasi, background putih/pink muda. Sertakan versi 512×512.

---

## 5. Aturan Format Data di UI

| Data | Format | Contoh |
|---|---|---|
| Waktu relatif | < 45 dtk "baru saja"; menit; jam; hari | "baru saja", "5 menit lalu", "2 jam lalu", "1 hari lalu" |
| Jarak | < 1 km dalam meter; ≥ 1 km satu desimal pakai koma (≥10 km tanpa desimal) | "850 m", "3,2 km", "25 km" |
| Kecepatan | Hanya tampil jika ≥ 3,6 km/j | "36 km/j" |
| Baterai | "{n}%" + " · mengisi" / " · penuh" | "76% · mengisi" |
| Jaringan | Wi-Fi → "Wi-Fi"; seluler → "{Operator} {Gen}" | "Telkomsel 5G", "Data seluler" (jika operator tidak diketahui), "Offline" |

---

## 6. Output yang Diharapkan

1. Frame **Design System** (warna, tipografi, semua komponen di atas).
2. Semua layar & variasi di bagian 4, diberi nama frame sesuai nomornya (mis. `6A – Peta Normal`).
3. Frame **Flow** yang menghubungkan layar dengan panah: 1 → 2 → 3 → (pasangan menerima) → 5 → 6A, serta 6A → 7 → 8 → 2.
4. Desain harus responsif terhadap teks panjang (nama panjang terpotong dengan ellipsis, chip turun ke baris berikutnya).
5. Pastikan kontras teks memenuhi WCAG AA, dan target sentuh minimal 48×48.
