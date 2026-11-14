import '../models/product.dart';

/// Satu baris di keranjang kasir.
class CartItem {
  final Product product;
  int qty;
  int price; // harga yang dipakai (ecer / grosir)
  String priceMode; // 'ecer' atau 'grosir'
  int discount; // nilai diskon (Rp atau %)
  String discountType; // 'rp' atau 'pct'
  String note;

  CartItem({
    required this.product,
    this.qty = 1,
    int? price,
    this.priceMode = 'ecer',
    this.discount = 0,
    this.discountType = 'rp',
    this.note = '',
  }) : price = price ?? product.priceSell;

  /// Diskon dalam Rupiah untuk baris ini (dibatasi tidak melebihi harga baris).
  int get discountAmount {
    if (discount <= 0) return 0;
    final int gross = price * qty;
    int amount;
    if (discountType == 'pct') {
      amount = gross * discount ~/ 100;
    } else {
      amount = discount;
    }
    if (amount > gross) amount = gross;
    return amount;
  }

  int get lineTotal {
    final int t = price * qty - discountAmount;
    return t < 0 ? 0 : t;
  }

  CartItem copy() {
    return CartItem(
      product: product,
      qty: qty,
      price: price,
      priceMode: priceMode,
      discount: discount,
      discountType: discountType,
      note: note,
    );
  }
}
