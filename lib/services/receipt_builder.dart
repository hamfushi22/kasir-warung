import '../models/app_settings.dart';
import '../models/sale.dart';
import 'money.dart';

/// Membangun teks struk (lebar 32 karakter, standar kertas 58mm).
/// Struk dibagikan lewat share (WhatsApp/dll).
/// TODO(printer): kirim teks ini ke printer thermal ESC/POS Bluetooth
/// (mis. plugin bluetooth_print / esc_pos_utils) bila printer sudah ada.
class ReceiptBuilder {
  static const int width = 32;

  static String _center(String s) {
    if (s.length >= width) return s;
    final int pad = (width - s.length) ~/ 2;
    return '${' ' * pad}$s';
  }

  static String _pair(String left, String right) {
    final int space = width - left.length - right.length;
    if (space <= 0) return '$left $right';
    return '$left${' ' * space}$right';
  }

  static String _dash() => '-' * width;

  static List<String> _wrap(String s) {
    final List<String> out = <String>[];
    String rest = s;
    while (rest.length > width) {
      out.add(rest.substring(0, width));
      rest = rest.substring(width);
    }
    out.add(rest);
    return out;
  }

  static String build({
    required AppSettings settings,
    required Sale sale,
    required List<SaleItem> items,
    required List<Payment> payments,
    int change = 0,
  }) {
    final StringBuffer b = StringBuffer();

    // Header toko.
    for (final String line in _wrap(settings.storeName.toUpperCase())) {
      b.writeln(_center(line));
    }
    if (settings.storeAddress.trim().isNotEmpty) {
      for (final String line in _wrap(settings.storeAddress.trim())) {
        b.writeln(_center(line));
      }
    }
    if (settings.storePhone.trim().isNotEmpty) {
      b.writeln(_center(settings.storePhone.trim()));
    }
    if (settings.receiptHeader.trim().isNotEmpty) {
      b.writeln(_center(settings.receiptHeader.trim()));
    }
    b.writeln(_dash());
    b.writeln(_pair('No: ${sale.invoiceNo}', ''));
    b.writeln(_pair(formatDateTime(sale.createdAt), ''));
    if (sale.cashierName.isNotEmpty) {
      b.writeln(_pair('Kasir: ${sale.cashierName}', ''));
    }
    if (sale.customerName.isNotEmpty) {
      b.writeln(_pair('Pelanggan: ${sale.customerName}', ''));
    }
    b.writeln(_dash());

    // Item.
    for (final SaleItem item in items) {
      for (final String line in _wrap(item.productName)) {
        b.writeln(line);
      }
      final String left = '  ${item.qty} x ${rp(item.price)}';
      final String right = rp(item.price * item.qty - item.discountAmount);
      b.writeln(_pair(left, right));
      if (item.discountAmount > 0) {
        final String discLabel = item.discountType == 'pct'
            ? 'Diskon ${item.discount}%'
            : 'Diskon';
        b.writeln(_pair('  $discLabel', '-${rp(item.discountAmount)}'));
      }
      if (item.note.trim().isNotEmpty) {
        b.writeln('  * ${item.note.trim()}');
      }
    }
    b.writeln(_dash());

    // Total.
    b.writeln(_pair('Subtotal', rp(sale.subtotal)));
    if (sale.discount > 0) {
      b.writeln(_pair('Diskon', '-${rp(sale.discount)}'));
    }
    if (sale.tax > 0) {
      b.writeln(_pair('Pajak', rp(sale.tax)));
    }
    b.writeln(_pair('TOTAL', rp(sale.grandTotal)));
    b.writeln(_dash());

    // Pembayaran.
    if (sale.isCredit) {
      b.writeln(_pair('Bayar nanti (kasbon)', rp(sale.grandTotal)));
    } else {
      for (final Payment p in payments) {
        b.writeln(_pair(Payment.methodLabel(p.method), rp(p.amount)));
      }
      if (change > 0) {
        b.writeln(_pair('Kembalian', rp(change)));
      }
    }
    b.writeln(_dash());

    // Footer.
    if (settings.receiptFooter.trim().isNotEmpty) {
      for (final String line in _wrap(settings.receiptFooter.trim())) {
        b.writeln(_center(line));
      }
    }
    b.writeln(_center('*** ${sale.invoiceNo} ***'));
    return b.toString();
  }
}
