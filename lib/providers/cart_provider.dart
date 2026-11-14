import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../services/checkout_service.dart';

/// Keranjang belanja di layar kasir.
class CartProvider extends ChangeNotifier {
  final List<CartItem> items = <CartItem>[];
  int txnDiscount = 0;
  String txnDiscountType = 'rp'; // 'rp' atau 'pct'

  bool _taxEnabled = false;
  int _taxRate = 10;

  void setTax(bool enabled, int rate) {
    _taxEnabled = enabled;
    _taxRate = rate;
  }

  CartTotals get totals => computeTotals(
        items,
        txnDiscount: txnDiscount,
        txnDiscountType: txnDiscountType,
        taxEnabled: _taxEnabled,
        taxRate: _taxRate,
      );

  int get grandTotal => totals.grandTotal;
  int get itemCount => items.fold<int>(0, (int s, CartItem i) => s + i.qty);
  bool get isEmpty => items.isEmpty;

  /// Tambah produk. Bila produk yang sama (ecer, tanpa diskon/catatan)
  /// sudah ada, jumlahnya ditambah.
  void addProduct(Product p) {
    final int idx = items.indexWhere((CartItem i) =>
        i.product.id == p.id &&
        i.priceMode == 'ecer' &&
        i.discount == 0 &&
        i.note.isEmpty);
    if (idx >= 0) {
      items[idx].qty++;
    } else {
      items.add(CartItem(product: p));
    }
    notifyListeners();
  }

  void setQty(int index, int qty) {
    if (index < 0 || index >= items.length) return;
    if (qty <= 0) {
      items.removeAt(index);
    } else {
      items[index].qty = qty;
    }
    notifyListeners();
  }

  void removeAt(int index) {
    if (index < 0 || index >= items.length) return;
    items.removeAt(index);
    notifyListeners();
  }

  void updateItem(int index, CartItem updated) {
    if (index < 0 || index >= items.length) return;
    items[index] = updated;
    notifyListeners();
  }

  void setTransactionDiscount(int value, String type) {
    txnDiscount = value;
    txnDiscountType = type;
    notifyListeners();
  }

  void clearCart() {
    items.clear();
    txnDiscount = 0;
    txnDiscountType = 'rp';
    notifyListeners();
  }

  /// Checkout lunas / kasbon. Mengosongkan keranjang bila berhasil.
  Future<CheckoutResult> checkout({
    required List<PaymentInput> payments,
    required bool isCredit,
    String? customerName,
    String? customerPhone,
    String? note,
    required int? userId,
    required String userName,
    required bool taxEnabled,
    required int taxRate,
  }) async {
    final CheckoutResult result = await CheckoutService.checkout(
      items: List<CartItem>.from(items),
      txnDiscount: txnDiscount,
      txnDiscountType: txnDiscountType,
      payments: payments,
      isCredit: isCredit,
      customerName: customerName,
      customerPhone: customerPhone,
      note: note,
      userId: userId,
      userName: userName,
      settings: await DatabaseHelper.instance.loadSettings(),
    );
    clearCart();
    return result;
  }

  /// Parkir transaksi (hold). Mengosongkan keranjang bila berhasil.
  Future<String> holdSale({
    String? note,
    required int? userId,
    required String userName,
  }) async {
    final String invoiceNo = await CheckoutService.holdSale(
      items: List<CartItem>.from(items),
      txnDiscount: txnDiscount,
      txnDiscountType: txnDiscountType,
      note: note,
      userId: userId,
      userName: userName,
      settings: await DatabaseHelper.instance.loadSettings(),
    );
    clearCart();
    return invoiceNo;
  }

  /// Muat transaksi yang diparkir kembali ke keranjang.
  Future<void> loadHeldSale(int saleId) async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final List<SaleItem> saleItems = await db.getSaleItems(saleId);
    items.clear();
    txnDiscount = 0;
    txnDiscountType = 'rp';
    for (final SaleItem si in saleItems) {
      final Product? p =
          si.productId != null ? await db.getProductById(si.productId!) : null;
      final Product product = p ??
          Product(
            id: si.productId,
            name: si.productName,
            priceBuy: si.priceBuy,
            priceSell: si.price,
            stock: 0,
          );
      items.add(CartItem(
        product: product,
        qty: si.qty,
        price: si.price,
        priceMode: 'ecer',
        discount: si.discount,
        discountType: si.discountType,
        note: si.note,
      ));
    }
    // Hapus transaksi parkir yang sudah dimuat (akan dibuat baru saat checkout).
    await db.deleteSale(saleId);
    notifyListeners();
  }
}
