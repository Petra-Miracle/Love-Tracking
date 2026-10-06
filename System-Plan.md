# Rencana Sistem & Rekomendasi Tech Stack: Love Tracking App

Sistem tracking lokasi dan status perangkat secara *real-time* khusus untuk pasangan (2 pengguna), terinspirasi dari aplikasi **Love8**.

---

## 📋 Fitur Utama
1. **Real-Time Location Tracking**: Menunjukkan lokasi presisi dan pergerakan pasangan saat berjalan/bepergian secara *real-time*.
2. **Battery Status Tracking**: Menampilkan persentase dan status pengisian daya (charging) baterai pasangan.
3. **Network & Cellular Tracking**: Menunjukkan koneksi jaringan yang sedang digunakan pasangan (Wi-Fi / Seluler) beserta nama operator seluler (Telkomsel, Indosat, XL, dll.).
4. **Invite Link Pairing**: Penggabungan akun pasangan menggunakan link undangan (*deep link* / *app link*).

---

## 🛠️ Rekomendasi Backend (Untuk Background Programmer JavaScript)

Karena Anda memiliki latar belakang **JavaScript**, ada dua pendekatan backend terbaik:

### 🌟 Opsi 1: Firebase (Firestore + Realtime DB + Cloud Functions Node.js + Firebase Auth)
> **Sangat Direkomendasikan untuk proyek personal 2 pengguna.**

* **Alasan**:
  * **Real-time out-of-the-box**: Flutter SDK Firebase mendukung *stream listener* (`snapshots()`). Perubahan lokasi, baterai, dan jaringan langsung ter-update di layar pasangan tanpa perlu membuat server WebSocket manual.
  * **Cloud Functions**: Ditolong dengan Node.js / JavaScript untuk logika backend tambahan (misal: penanganan invite link, push notification).
  * **Gratis**: Bebas biaya (*Free Tier*) selamanya untuk penggunaan 2 orang.
  * **Firebase Auth**: Login gampang (Email/Google/Anonymous) dan aman.

### 🚀 Opsi 2: Custom Node.js (NestJS / Express) + Socket.IO + PostgreSQL (PostGIS) + Redis
> **Cocok jika Anda ingin full control atas data dan mempelajari arsitektur microservice/realtime.**

* **Framework Backend**: Express.js atau NestJS (TypeScript/JavaScript).
* **Komunikasi Real-Time**: **Socket.IO** atau WebSockets murni untuk *streaming* lokasi & baterai secara *bi-directional*.
* **Database**:
  * **PostgreSQL + PostGIS**: Pilihan terbaik untuk menyimpan riwayat lokasi/perjalanan (geospatial query untuk menghitung jarak, rute, dll.).
  * **Redis**: Digunakan untuk menyimpan lokasi & status *live* paling baru (*in-memory*) agar query lokasi super cepat.

---

## 📱 Rekomendasi Tech Stack & Library Flutter (Dart)

### 1. Peta & Visualisasi Lokasi (Gratis & Open Source)
* **`flutter_map`**: Library peta terbaik di Flutter untuk **OpenStreetMap (OSM)**. 100% Gratis, tanpa perlu API Key / kartu kredit seperti Google Maps.
* **`latlong2`**: Library penanganan koordinat latitude & longitude yang digunakan bersama `flutter_map`.
* *Tile Server URL*: Menggunakan `https://tile.openstreetmap.org/{z}/{x}/{y}.png` atau Tile Provider gratis lainnya (seperti CartoDB / MapTiler).

### 2. Location Tracking & Background Processing
* **`geolocator`**: Mengambil koordinat GPS (latitude, longitude, kecepatan, akurasi).
* **`flutter_background_service`**: Menjalankan service tracking di latar belakang (*background/foreground service*) agar lokasi tetap terkirim meskipun aplikasi ditutup/HP terkunci.
* **`permission_handler`**: Mengelola izin akses lokasi (*Always Allow / Location in Background*).

### 3. Status Baterai
* **`battery_plus`**: Mendapatkan level baterai (0-100%) dan status pengisian daya (`charging`, `discharging`, `full`).

### 4. Status Jaringan & Operator Seluler
* **`connectivity_plus`**: Memeriksa jenis koneksi (*Wi-Fi*, *Mobile Data*, *None*).
* **`carrier_info`**: Mendapatkan nama operator seluler (Telkomsel, XL, Indosat, dll.) serta tipe jaringan (4G/5G).

### 5. Pairing Link (Invite Link / Deep Linking)
* **`app_links`** atau **`go_router`**: Mengendalikan *Deep Link* / *Universal Link* (contoh: `https://lovetracking.app/invite?code=XYZ` atau `lovetracking://invite?code=XYZ`).

### 6. State Management & Real-time Stream
* **`flutter_riverpod`**: Sangat bersih dan cocok untuk menangani `StreamProvider` dari WebSocket atau Firebase Firestore.

---

## ⚠️ Tantangan Teknis & Solusi (Important Notes)

1. **Penghematan Baterai OS (Android Doze Mode & iOS Background Restrictions)**:
   * **Masalah**: Android/iOS suka mematikan aplikasi di latar belakang untuk menghemat baterai.
   * **Solusi**: Gunakan **Android Foreground Service** dengan notifikasi persisten (misal: "Love Tracking sedang aktif") dan minta izin `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.
2. **Efisiensi Pengiriman Data Lokasi**:
   * Jangan kirim koordinat setiap milidetik. Gunakan `distanceFilter` (misal: kirim pembaruan hanya jika bergeser > 10 meter) untuk menghemat baterai & kuota data.
