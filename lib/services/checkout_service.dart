import 'package:sqflite/sqflite.dart';

import '../db/database_helper.dart';
import '../models/app_settings.dart';
import '../models/cart_item.dart';
import '../models/customer.dart';
import '../models/sale.dart';

/// Hasil hitung keranjang (dipakai layar kasir dan checkout).
class CartTotals {
  final int gross; // Σ harga × qty (sebelum diskon apa pun)
  final int itemDiscounts; // total diskon per item
  final int subtotal; // gross − diskon item
  final int transactionDiscount; // diskon transaksi (Rp)
  final int tax; // pajak (Rp)
  final int grandTotal;

  const CartTotals({
    required this.gross,
    required this.itemDiscounts,
    required this.subtotal,
    required this.transactionDiscount,
    required this.tax,
    required this.grandTotal,
  });
}

CartTotals computeTotals(
  List<CartItem> items, {
  required int txnDiscount,
  required String txnDiscountType,
  required bool taxEnabled,
  required int taxRate,
}) {
  final int gross = items.fold<int>(0, (int s, CartItem i) => s + i.price * i.qty);
  final int itemDiscounts =
      items.fold<int>(0, (int s, CartItem i) => s + i.discountAmount);
  final int subtotal = gross - itemDiscounts;
  int txnDisc;
  if (txnDiscountType == 'pct') {
    txnDisc = subtotal * txnDiscount ~/ 100;
  } else {
    txnDisc = txnDiscount;
  }
  if (txnDisc > subtotal) txnDisc = subtotal;
  if (txnDisc < 0) txnDisc = 0;
  final int taxable = subtotal - txnDisc;
  final int tax = taxEnabled ? taxable * taxRate ~/ 100 : 0;
  int grand = taxable + tax;
  if (grand < 0) grand = 0;
  return CartTotals(
    gross: gross,
    itemDiscounts: itemDiscounts,
    subtotal: subtotal,
    transactionDiscount: txnDisc,
    tax: tax,
    grandTotal: grand,
  );
}

class CheckoutResult {
  final String invoiceNo;
  final int saleId;
  final int grandTotal;
  final int change;

  const CheckoutResult({
    required this.invoiceNo,
    required this.saleId,
    required this.grandTotal,
    this.change = 0,
  });
}

/// Semua penulisan transaksi dalam SATU transaction SQLite:
/// sale + sale_items + payments + kurangi stok + (kasbon) piutang + log + sync_queue.
/// Bila satu langkah gagal, semuanya batal (atomic).
class CheckoutService {
  static Future<CheckoutResult> checkout({
    required List<CartItem> items,
    required int txnDiscount,
    required String txnDiscountType,
    required List<PaymentInput> payments,
    required bool isCredit,
    String? customerName,
    String? customerPhone,
    String? note,
    required int? userId,
    required String userName,
    required AppSettings settings,
  }) async {
    final DatabaseHelper helper = DatabaseHelper.instance;
    final Database db = await helper.database;
    final CartTotals totals = computeTotals(
      items,
      txnDiscount: txnDiscount,
      txnDiscountType: txnDiscountType,
      taxEnabled: settings.taxEnabled,
      taxRate: settings.taxRate,
    );
    final String now = DatabaseHelper.nowIso();
    final String today = DatabaseHelper.todayStr();

    final int paidTotal =
        payments.fold<int>(0, (int s, PaymentInput p) => s + p.amount);
    final int change = paidTotal > totals.grandTotal
        ? paidTotal - totals.grandTotal
        : 0;

    late String invoiceNo;
    late int saleId;

    await db.transaction((Transaction txn) async {
      // Nomor invoice: INV-YYYYMMDD-XXXX (urut per hari).
      final List<Map<String, dynamic>> cntRows = await txn.rawQuery(
        'SELECT COUNT(*) AS cnt FROM sales WHERE created_date = ?',
        <String>[today],
      );
      final int count = (cntRows.first['cnt'] as num?)?.toInt() ?? 0;
      final String day = today.replaceAll('-', '');
      invoiceNo = 'INV-$day-${(count + 1).toString().padLeft(4, '0')}';

      final String status = isCredit ? 'credit' : 'paid';
      Customer? customer;
      if (isCredit) {
        customer = await _findOrCreateCustomerTxn(
          txn,
          (customerName ?? 'Pelanggan').trim(),
          phone: customerPhone ?? '',
        );
      }

      saleId = await txn.insert('sales', <String, dynamic>{
        'invoice_no': invoiceNo,
        'subtotal': totals.subtotal,
        'discount': totals.transactionDiscount,
        'tax': totals.tax,
        'grand_total': totals.grandTotal,
        'status': status,
        'customer_id': customer?.id,
        'customer_name': customer?.name ?? (customerName ?? ''),
        'cashier_id': userId,
        'cashier_name': userName,
        'note': note ?? '',
        'created_at': now,
        'created_date': today,
      });

      for (final CartItem item in items) {
        await txn.insert('sale_items', <String, dynamic>{
          'sale_id': saleId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'price': item.price,
          'price_buy': item.product.priceBuy,
          'qty': item.qty,
          'discount': item.discount,
          'discount_type': item.discountType,
          'discount_amount': item.discountAmount,
          'note': item.note,
        });
        // Kurangi stok (kecuali produk jasa).
        if (!item.product.isService && item.product.id != null) {
          final List<Map<String, dynamic>> stockRows = await txn.query(
            'products',
            columns: <String>['stock'],
            where: 'id = ?',
            whereArgs: <int>[item.product.id!],
            limit: 1,
          );
          if (stockRows.isNotEmpty) {
            final int current = (stockRows.first['stock'] as num?)?.toInt() ?? 0;
            int next = current - item.qty;
            if (next < 0) next = 0;
            await txn.update('products', <String, dynamic>{'stock': next},
                where: 'id = ?', whereArgs: <int>[item.product.id!]);
            await txn.insert('stock_movements', <String, dynamic>{
              'product_id': item.product.id,
              'product_name': item.product.name,
              'type': 'sale',
              'qty': -item.qty,
              'note': invoiceNo,
              'created_at': now,
              'created_date': today,
              'user_id': userId,
            });
          }
        }
      }

      if (!isCredit) {
        for (final PaymentInput p in payments) {
          await txn.insert('payments', <String, dynamic>{
            'sale_id': saleId,
            'method': p.method,
            'amount': p.amount,
            'created_at': now,
            'created_date': today,
          });
        }
      } else if (customer != null) {
        await txn.insert('receivables', <String, dynamic>{
          'customer_id': customer.id,
          'customer_name': customer.name,
          'sale_id': saleId,
          'invoice_no': invoiceNo,
          'total': totals.grandTotal,
          'paid': 0,
          'status': 'open',
          'created_at': now,
          'created_date': today,
        });
      }

      await txn.insert('activity_logs', <String, dynamic>{
        'user_id': userId,
        'user_name': userName,
        'action': isCredit ? 'Jual kasbon' : 'Jual',
        'detail': '$invoiceNo — ${totals.grandTotal}',
        'created_at': now,
      });

      // Antrean sync (belum dikirim — sinkronisasi nonaktif, lihat SyncService).
      await txn.insert('sync_queue', <String, dynamic>{
        'table_name': 'sales',
        'record_id': saleId,
        'payload': invoiceNo,
        'status': 'pending',
        'created_at': now,
      });
    });

    return CheckoutResult(
      invoiceNo: invoiceNo,
      saleId: saleId,
      grandTotal: totals.grandTotal,
      change: change,
    );
  }

  /// Simpan transaksi sebagai 'held' (diparkir): tanpa pembayaran,
  /// tanpa pengurangan stok. Stok baru berkurang saat dilanjutkan + checkout.
  static Future<String> holdSale({
    required List<CartItem> items,
    required int txnDiscount,
    required String txnDiscountType,
    String? note,
    required int? userId,
    required String userName,
    required AppSettings settings,
  }) async {
    final DatabaseHelper helper = DatabaseHelper.instance;
    final Database db = await helper.database;
    final CartTotals totals = computeTotals(
      items,
      txnDiscount: txnDiscount,
      txnDiscountType: txnDiscountType,
      taxEnabled: settings.taxEnabled,
      taxRate: settings.taxRate,
    );
    final String now = DatabaseHelper.nowIso();
    final String today = DatabaseHelper.todayStr();

    late String invoiceNo;
    await db.transaction((Transaction txn) async {
      final List<Map<String, dynamic>> cntRows = await txn.rawQuery(
        'SELECT COUNT(*) AS cnt FROM sales WHERE created_date = ?',
        <String>[today],
      );
      final int count = (cntRows.first['cnt'] as num?)?.toInt() ?? 0;
      final String day = today.replaceAll('-', '');
      invoiceNo = 'HOLD-$day-${(count + 1).toString().padLeft(4, '0')}';

      final int saleId = await txn.insert('sales', <String, dynamic>{
        'invoice_no': invoiceNo,
        'subtotal': totals.subtotal,
        'discount': totals.transactionDiscount,
        'tax': totals.tax,
        'grand_total': totals.grandTotal,
        'status': 'held',
        'customer_id': null,
        'customer_name': '',
        'cashier_id': userId,
        'cashier_name': userName,
        'note': note ?? '',
        'created_at': now,
        'created_date': today,
      });
      for (final CartItem item in items) {
        await txn.insert('sale_items', <String, dynamic>{
          'sale_id': saleId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'price': item.price,
          'price_buy': item.product.priceBuy,
          'qty': item.qty,
          'discount': item.discount,
          'discount_type': item.discountType,
          'discount_amount': item.discountAmount,
          'note': item.note,
        });
      }
    });
    return invoiceNo;
  }

  static Future<Customer> _findOrCreateCustomerTxn(
    Transaction txn,
    String name, {
    String phone = '',
  }) async {
    final List<Map<String, dynamic>> maps = await txn.query('customers',
        where: 'name = ?', whereArgs: <String>[name], limit: 1);
    if (maps.isNotEmpty) return Customer.fromMap(maps.first);
    final int id = await txn.insert('customers',
        <String, dynamic>{'name': name, 'phone': phone, 'address': ''});
    return Customer(id: id, name: name, phone: phone);
  }
}
