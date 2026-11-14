import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_settings.dart';
import '../models/sale.dart';
import '../services/receipt_builder.dart';

/// Dialog struk setelah checkout / dari riwayat transaksi.
/// Struk dibagikan sebagai teks (WhatsApp, dll) lewat share sistem.
/// TODO(printer): tambah tombol "Cetak" yang mengirim teks struk ke
/// printer thermal ESC/POS Bluetooth (plugin bluetooth_print) bila
/// printer sudah tersedia di toko.
Future<void> showReceiptDialog(
  BuildContext context, {
  required AppSettings settings,
  required Sale sale,
  required List<SaleItem> items,
  required List<Payment> payments,
  int change = 0,
}) async {
  final String text = ReceiptBuilder.build(
    settings: settings,
    sale: sale,
    items: items,
    payments: payments,
    change: change,
  );
  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      return AlertDialog(
        title: Text('Struk ${sale.invoiceNo}'),
        content: SingleChildScrollView(
          child: SelectableText(
            text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () {
              Share.share(text, subject: 'Struk ${sale.invoiceNo}');
            },
            icon: const Icon(Icons.share),
            label: const Text('Bagikan'),
          ),
        ],
      );
    },
  );
}
