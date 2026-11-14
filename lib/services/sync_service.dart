import '../db/database_helper.dart';

/// Klien API backend (VPS) — STUB untuk MVP.
///
/// Sinkronisasi DINONAKTIFKAN secara default karena backend belum ada.
/// Semua perubahan lokal tetap dicatat di tabel `sync_queue` oleh
/// CheckoutService, sehingga saat backend sudah siap, antrean ini
/// tinggal dikirim.
///
/// TODO(sync): saat backend Node.js + SQLite di VPS sudah jalan,
///   1. isi [baseUrl] (mis. https://kasir.168.107.85.147/api),
///   2. ubah [syncEnabled] menjadi true,
///   3. implementasikan pengiriman antrean dengan package `http`
///      (POST /sync dengan payload JSON + tandai terkirim).
/// JANGAN ada panggilan jaringan sungguhan sebelum langkah itu selesai.
class SyncService {
  static const bool syncEnabled = false;

  /// Alamat backend. Kosong = sinkronisasi nonaktif.
  static const String baseUrl = '';

  /// Kirim semua antrean yang masih pending.
  /// Mengembalikan jumlah record yang berhasil dikirim.
  /// Saat ini selalu 0 karena sinkronisasi nonaktif.
  static Future<int> syncPending() async {
    if (!syncEnabled) {
      return 0;
    }
    throw UnimplementedError(
      'Sinkronisasi belum diimplementasikan. Lihat TODO di lib/services/sync_service.dart.',
    );
  }

  /// Jumlah record yang menunggu dikirim.
  static Future<int> pendingCount() {
    return DatabaseHelper.instance.pendingSyncCount();
  }
}
