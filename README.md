# Kasir Warung — Aplikasi Kasir Android (Flutter)

Aplikasi kasir offline-first untuk warung/toko kelontong. Dibangun dengan Flutter,
semua data tersimpan di SQLite lokal di HP (paket `sqflite`). Tidak ada panggilan
jaringan — sinkronisasi ke server disiapkan tapi dinonaktifkan secara default.

## Fitur (Fase 1 — MVP)

- **Dashboard** — omzet hari ini, jumlah transaksi, produk terlaris, grafik 7 hari,
  peringatan stok menipis.
- **Kasir (POS)** — cari produk (nama/SKU/barcode), input barcode manual, grid produk
  favorit, keranjang (jumlah, catatan, hapus), diskon per item (Rp/%) dan diskon
  transaksi, metode bayar tunai (+ hitung kembalian & tombol uang pas), QRIS statis,
  transfer, e-wallet, split payment (tunai + non-tunai), kasbon (piutang pelanggan),
  parkir transaksi (hold) dan lanjutkan, struk (bagikan sebagai teks via share).
- **Produk** — CRUD lengkap (nama, SKU, barcode, kategori, satuan, harga beli/jual/
  grosir, stok, stok minimum), kategori, tanpa foto.
- **Stok** — stok masuk/keluar/opname, peringatan stok di bawah minimum, riwayat
  pergerakan stok per produk.
- **Laporan** — penjualan harian/7 hari/30 hari/bulan ini, per produk/kategori/
  metode bayar, produk terlaris, laba/rugi sederhana (laba kotor − biaya).
- **Kas** — kas awal (modal shift), kas akhir/tutup kasir dengan pencatatan selisih,
  pemasukan/pengeluaran lain, laporan per shift.
- **Pengguna** — login PIN, peran Owner dan Kasir (kasir tidak bisa ubah harga dan
  tidak bisa lihat laporan penuh), log aktivitas sederhana.
- **Pengaturan** — profil toko (nama, alamat, telepon), toggle pajak + tarif,
  header/footer struk, mata uang Rp.
- **Import/Export CSV** — import produk dari CSV (format persis
  `assets/template-produk.csv`), export produk ke CSV (via share).
- **Siap-sync** — tabel `sync_queue` + `ApiClient` stub; sinkronisasi dinonaktifkan
  secara default (backend belum ada).

## Pengguna demo (PIN)

- Owner: **1234**
- Kasir: **1111**

⚠️ Ganti PIN setelah instalasi pertama (Pengaturan → Pengguna → Ubah PIN).

## Data awal (demo)

8 produk contoh dari `assets/template-produk.csv` (sama dengan
`../template-produk.csv`) dimuat saat instalasi pertama dan ditandai sebagai data
demo. Bisa dihapus lewat Produk → "Hapus semua produk demo" (hanya Owner).

## Struktur proyek

```text
lib/
  main.dart                Entry point + tema + routing (login/home)
  models/                  Product, Sale, Customer, Cash, StockMovement,
                           AppUser, AppSettings, CartItem
  db/database_helper.dart  Skema SQLite (12 tabel) + seed + semua query
  services/                money.dart (format Rp), receipt_builder.dart,
                           csv_service.dart, checkout_service.dart,
                           sync_service.dart (stub, nonaktif)
  providers/               auth_provider, catalog_provider, cart_provider
  screens/                 login, home, dashboard, pos, products,
                           product_form, stock, reports, cash, customers,
                           sales_history, settings, other_menu
  widgets/                 pin_pad, bar_chart, empty_state, receipt_dialog
```

## Cara menjalankan (development)

```bash
flutter pub get
flutter run
```

## Cara build APK (release)

```bash
flutter build apk --release
```

File APK ada di `build/app/outputs/flutter-apk/app-release.apk`.

> Catatan: build release memakai debug signing config agar bisa langsung build
> tanpa keystore. Sebelum distribusi luas, buat keystore sendiri dan ganti
> `signingConfig signingConfigs.debug` di `android/app/build.gradle` dengan
> signing config release yang benar.

## Persiapan build (di mesin build)

1. Instal Flutter SDK (stable, 3.22+) dan Android SDK (compileSdk 34).
2. Jalankan `flutter doctor` dan penuhi yang belum terpasang
   (Android SDK, platform-tools, Java 17).
3. `flutter pub get` lalu `flutter build apk --release`.
4. Jika `gradle-wrapper.jar` belum ada (file ini tidak ikut dalam proyek),
   jalankan `flutter build` sekali — Flutter akan mengunduh Gradle wrapper
   secara otomatis — atau salin `gradle-wrapper.jar` dari proyek Flutter lain.

## Keputusan desain / penyederhanaan (Fase 1)

- **Tanpa scan barcode kamera** — tidak ada `mobile_scanner`/plugin kamera agar
  build lebih ringan dan tidak gagal karena permission kamera. Barcode cukup
  diketik manual lalu dicari di kolom pencarian kasir.
- **Tanpa foto produk** — tidak ada `image_picker`; produk diidentifikasi lewat
  nama/SKU/barcode.
- **Tanpa plugin printer Bluetooth** — struk dibagikan sebagai teks (share_plus)
  dan bisa dicetak lewat dialog share/print sistem Android. Lihat TODO di
  `lib/widgets/receipt_dialog.dart` untuk integrasi printer ESC/POS Bluetooth
  (mis. plugin `esc_pos_utils` + `bluetooth_print`) di Fase 2.
- **QRIS statis** — kasir menampilkan nomor/ID QRIS statis toko; pembayaran
  dikonfirmasi manual (cek mutasi) sebelum menyelesaikan transaksi. Tanpa
  payment gateway, tanpa verifikasi otomatis.
- **Transaksi parkir (hold)** — disimpan sebagai penjualan berstatus `held`
  (tabel `sales`), tidak mengurangi stok sampai transaksi diselesaikan dan
  di-checkout; saat dimuat kembali ke kasir, baris parkir lama dihapus dan
  transaksi baru dibuat saat checkout.
- **Laporan laba/rugi** — sederhana: laba kotor = penjualan − HPP (harga beli
  saat transaksi), biaya = total pengeluaran kas. Belum ada pemisahan biaya
  operasional rinci.
- **Satu toko** — tanpa multi-cabang; semua data milik satu toko.
- **Pajak nonaktif** secara default; bisa diaktifkan di Pengaturan (tarif %).

## TODO untuk langkah selanjutnya

- [ ] Build APK pertama (`flutter build apk --release`) dan uji instalasi di HP.
- [ ] Buat keystore release sebelum distribusi luas.
- [ ] Uji alur kasir end-to-end (jual → struk → laporan → tutup kasir).
- [ ] Integrasi printer ESC/POS Bluetooth (lihat TODO di receipt_dialog.dart).
- [ ] Backend di VPS (Node.js + SQLite) + aktifkan sinkronisasi
      (`lib/services/sync_service.dart` + `ApiClient`).
- [ ] Mode grosir: harga grosir otomatis saat qty mencapai ambang (saat ini harga
      grosir hanya tercatat di produk, belum dipakai otomatis di kasir).
