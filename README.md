# Love Tracking (Flutter · Android)

Aplikasi pasangan untuk berbagi **lokasi real-time, baterai, dan jaringan/operator seluler**.
Backend (Express + Pusher + Neon Postgres di Vercel) ada di `D:\Love-Tracking-BACKEND` —
kontrak API lengkap ada di `D:\Love-Tracking-BACKEND\PROMPT-BACKEND.md`.

## Install di HP

Scan QR ini dengan kamera HP Android (atau buka link di bawahnya):

<img src="docs/install-qr.png" alt="QR install Love Tracking" width="220">

https://github.com/Petra-Miracle/Love-Tracking/releases/latest/download/love-tracking.apk

QR ini **dinamis**: link-nya selalu mengarah ke rilis terbaru di GitHub Releases, jadi QR yang sama
bisa dipakai untuk setiap update. Saat menginstall, izinkan *Install unknown apps* untuk browser.

Rilis versi baru (menaikkan versi, build APK, dan publish ke GitHub Releases):
```
.\scripts\release.ps1 -Notes "Ringkasan perubahan"
```
Update bisa menimpa versi lama hanya jika APK ditandatangani dengan keystore yang sama
(saat ini: debug keystore komputer pengembang).

## Arsitektur

```
HP A (foreground service) ──PUT /status──▶ Express ──▶ Neon (status terakhir)
                                              └─trigger─▶ Pusher private-couple-{id} ──▶ HP B (peta live)
```

| Bagian | File |
|---|---|
| Entry & root screen switch | `lib/main.dart`, `lib/app.dart` |
| State (Riverpod 3) | `lib/providers.dart` |
| REST client | `lib/data/api_client.dart` |
| Background tracking (GPS 10 m, heartbeat 60 dtk, throttle 5 dtk) | `lib/services/tracking_service.dart` |
| Baca baterai / jaringan / operator | `lib/services/device_snapshot.dart` |
| Pusher realtime | `lib/services/realtime_service.dart` |
| Plugin native operator seluler (Kotlin) | `packages/network_carrier/` |
| UI | `lib/ui/` (login, pairing, home/peta) |

## Setup

1. **Google Cloud Console** (project yang sama dengan backend):
   - OAuth client **Web application** → ID-nya dipakai sebagai `GOOGLE_SERVER_CLIENT_ID` (sama dengan `GOOGLE_WEB_CLIENT_ID` di backend).
   - OAuth client **Android** → package `com.lovetracking.love_tracking` + SHA-1. Lihat SHA-1 debug:
     ```
     cd android && ./gradlew signingReport
     ```
2. Salin `config/example.json` → `config/dev.json` lalu isi:
   ```json
   {
     "API_BASE_URL": "https://your-backend.vercel.app",
     "PUSHER_KEY": "...",
     "PUSHER_CLUSTER": "ap1",
     "GOOGLE_SERVER_CLIENT_ID": "xxxx.apps.googleusercontent.com"
   }
   ```
   (`config/dev.json` sudah di-`.gitignore`.) Untuk backend lokal (`npm run dev`) pakai IP LAN laptop,
   mis. `http://192.168.1.69:3000` (HP di Wi-Fi yang sama) atau `http://10.0.2.2:3000` dari emulator.
   HTTP biasa hanya diizinkan di build **debug** (`android/app/src/debug/AndroidManifest.xml`); release tetap HTTPS-only.
3. Jalankan:
   ```
   flutter run --dart-define-from-file=config/dev.json
   flutter build apk --release --dart-define-from-file=config/dev.json
   ```

## Alur pemakaian

1. Masuk dengan Google.
2. Satu orang menekan **Buat kode undangan** → **Bagikan**. Pasangan mengetuk link
   `lovetracking://invite?code=XXXXXX` atau mengetik kodenya.
   (WhatsApp tidak membuat custom scheme bisa diklik — karena itu ada input kode manual.)
3. Setelah terhubung, aplikasi meminta izin: lokasi → **Izinkan sepanjang waktu**, notifikasi,
   telepon (opsional, untuk label 4G/5G), dan pengecualian penghemat baterai.
4. Foreground service "Love Tracking aktif 💕" berjalan dan mengirim status; peta menampilkan pasangan secara live.

Menu kanan atas: **Jeda berbagi lokasi** (baterai & jaringan tetap terkirim, lokasi tidak),
**Putuskan pasangan**, **Keluar**.

## Catatan

- Pada HP Xiaomi/Oppo/Vivo/Samsung, aktifkan juga *Autostart* dan set baterai ke *No restrictions*
  di pengaturan aplikasi; jika tidak, service bisa dimatikan OS.
- Generasi jaringan 5G NSA dilaporkan Android sebagai 4G (LTE).
- Peta memakai tile OpenStreetMap (`tile.openstreetmap.org`) yang punya *usage policy*; untuk pemakaian
  pribadi 2 orang aman. Jika ingin, ganti `urlTemplate` di `lib/ui/home_screen.dart` dengan provider lain (MapTiler/Carto).
- Test: `flutter test`.
