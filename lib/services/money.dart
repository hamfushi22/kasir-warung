import 'package:intl/intl.dart';

final NumberFormat _rpFormat =
    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

/// Format Rupiah, mis. 15000 -> "Rp15.000".
String rp(int amount) => _rpFormat.format(amount);

/// Ambil angka dari teks input (buang "Rp", titik, spasi, dll).
int parseRupiah(String s) {
  final String digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

/// Format tanggal ISO 8601 -> "11 Nov 2026, 16:25".
String formatDateTime(String iso) {
  try {
    final DateTime d = DateTime.parse(iso);
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(d);
  } catch (_) {
    return iso;
  }
}

/// Format tanggal "yyyy-MM-dd" -> "11 Nov 2026".
String formatDate(String dateStr) {
  try {
    final DateTime d = DateTime.parse(dateStr);
    return DateFormat('d MMM yyyy', 'id_ID').format(d);
  } catch (_) {
    return dateStr;
  }
}

/// Label tanggal relatif sederhana untuk laporan.
String formatDayShort(String dateStr) {
  try {
    final DateTime d = DateTime.parse(dateStr);
    return DateFormat('dd/MM', 'id_ID').format(d);
  } catch (_) {
    return dateStr;
  }
}
