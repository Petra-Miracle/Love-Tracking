# Catatan: Deteksi Gerakan (Ikon Gerakan & Gelembung Hati)

Dokumen ini menjelaskan kapan Love Tracking menampilkan **ikon gerakan** (🚶 berjalan, 🏃 berlari, 🚗 dalam perjalanan) dan **gelembung hati** di pin peta.

- Berlaku sejak: **v1.0.4**
- Kode: `lib/ui/movement.dart` (`MovementEstimator`), `lib/services/tracking_service.dart` (pengirim), dan `lib/ui/format.dart` (`movementForSpeed`, `movementOf`)

---

## 1. Prinsip dasar

Sistem **tidak memakai angka kecepatan dari GPS**. Di dalam ruangan, titik GPS sering meloncat 10–50 m bolak-balik, dan Android melaporkan loncatan itu sebagai kecepatan. Akibatnya orang yang sedang duduk diam bisa terlihat seperti sedang berjalan.

Sebagai gantinya, sistem mengukur **perpindahan nyata**:

> Bandingkan **posisi paling awal** dan **posisi terbaru** dalam **60 detik terakhir**, lalu ukur jarak lurus di antara keduanya (perpindahan bersih).

**Perhitungan dilakukan sekali saja, di HP orang yang bergerak.** HP itu memakai semua titik GPS-nya sendiri (yang rapat), lalu mengirim hasilnya (kecepatan gerak terukur) bersama status. **Kedua HP menampilkan hasil yang sama persis**: pin di HP sendiri dan pin di HP pasangan membaca nilai yang sama. Begitu pasangan membuka aplikasi, ikon langsung tampil tanpa perlu menunggu data terkumpul.

> Sebelum v1.0.4, setiap HP menghitung sendiri dari titik-titik yang diterimanya. Akibatnya gerakan bisa terbaca di HP sendiri tapi tidak di HP pasangan. Kedua HP harus memakai v1.0.4 atau lebih baru.

---

## 2. Syarat sebuah gerakan terbaca

Ketiga syarat ini harus terpenuhi.

### Syarat A: ada cukup data
- Minimal **2 titik lokasi** dalam 60 detik terakhir.
- Rentang waktu antara titik pertama dan terakhir minimal **20 detik**. Ini mencegah satu loncatan GPS terbaca sebagai lari.

### Syarat B: perpindahan melewati ambang ketidakakuratan GPS

**Ambang = 2 × akurasi GPS + 10 m**

Akurasi diambil dari nilai yang dilaporkan HP. Kalau tidak diketahui, dianggap 30 m (dibatasi antara 5–100 m).

| Kondisi GPS | Akurasi biasa | Harus berpindah lebih dari |
|---|---|---|
| Di luar, langit terbuka | 5–10 m | **20–30 m** |
| Di luar, banyak gedung | ±15 m | **±40 m** |
| Di dalam ruangan | 25–40 m | **60–90 m** |

### Syarat C: kecepatan rata-rata minimal ±3 km/jam

Kecepatan rata-rata = jarak perpindahan ÷ rentang waktu.

| Kecepatan rata-rata | Status | Ikon |
|---|---|---|
| di bawah 0,8 m/s (±3 km/jam) | Diam | – |
| 0,8 – 2,2 m/s (±3–8 km/jam) | Sedang berjalan | 🚶 |
| 2,2 – 4,5 m/s (±8–16 km/jam) | Sedang berlari | 🏃 |
| di atas 4,5 m/s (±16 km/jam) | Dalam perjalanan (motor/mobil) | 🚗 |

---

## 3. Kapan ikon **tidak** muncul

- **Berjalan di dalam ruangan atau kamar.** Ruangan biasanya hanya 3–10 m, jauh di bawah ambang di dalam ruangan (60–90 m).
- **Bolak-balik di tempat.** Yang diukur adalah jarak dari titik awal ke titik akhir, bukan total langkah, jadi jalan bolak-balik di kamar menghasilkan perpindahan hampir nol.
- **Berkeliling di area kecil**, misalnya lapangan kecil atau jogging track pendek, karena titik awal dan akhirnya berdekatan.
- **Jalan sangat santai** di bawah ±3 km/jam.
- **Berbagi lokasi sedang dijeda.**
- **Status terakhir lebih dari 2 menit lalu**, misalnya karena aplikasi pengirim mati atau tidak ada sinyal.

---

## 4. Waktu reaksi

| Situasi | Perkiraan waktu |
|---|---|
| Jalan kaki normal di luar (±5 km/jam, GPS bagus) | Ikon muncul setelah **±20–30 detik** |
| Naik motor atau mobil | Ikon muncul setelah **±20 detik** (data minimum) |
| Berhenti bergerak | Ikon hilang dalam **±1 menit** (HP pengirim mengecek perubahan gerakan setiap 15 detik dan langsung mengirim kalau statusnya berubah) |
| GPS buruk (di antara gedung tinggi) | Bisa terlambat, atau jalan kaki tidak terbaca |

Catatan pendukung:
- HP mengirim lokasi setiap berpindah **≥10 m** (maksimal satu kiriman per 5 detik), plus *heartbeat* setiap **60 detik** saat diam.
- Field `speed` yang dikirim ke server berisi **kecepatan gerak terukur** dari `MovementEstimator` (0 saat diam), **bukan** kecepatan mentah dari GPS.

---

## 5. Tampilan

- **Badge gerakan** ada di pojok kanan atas foto profil pada pin: **pink** untuk pasangan, **biru** untuk diri sendiri. Teks tooltip-nya: *Sedang berjalan*, *Sedang berlari*, atau *Dalam perjalanan*.
- **Gelembung hati**: 5 lingkaran pink kecil berisi hati yang melayang naik dari pin, sedikit bergoyang, lalu memudar dan berulang (siklus 2,8 detik).
- Kalau mode **Remove animations** di HP aktif, gelembung tampil diam tanpa animasi.

---

## 6. Cara menyesuaikan sensitivitas

Semua angka ada di dua file:

| Yang ingin diubah | Lokasi | Nilai sekarang |
|---|---|---|
| Panjang jendela waktu | `MovementEstimator.window` (`lib/ui/movement.dart`) | 60 detik |
| Data minimum sebelum memutuskan | `MovementEstimator.minSpan` | 20 detik |
| Ambang loncatan GPS | `final noise = 2 * max(akurasi) + 10` | 2× akurasi + 10 m |
| Batas kecepatan berjalan, berlari, kendaraan | `movementForSpeed` (`lib/ui/format.dart`) | 0,8 / 2,2 / 4,5 m/s |

**Trade-off:** menurunkan ambang atau jendela waktu membuat ikon muncul lebih cepat dan lebih peka, tapi kemungkinan ikon muncul saat sedang diam (terutama di dalam ruangan) ikut naik.

Setelah mengubah angka, jalankan `flutter test` (test `MovementEstimator` di `test/logic_test.dart` mencakup skenario diam di kamar, jalan kaki, naik motor, dan berhenti), lalu rilis ulang dengan `.\scripts\release.ps1`.
