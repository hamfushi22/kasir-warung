/// Satu transaksi penjualan (header).
/// status: 'paid' (lunas), 'credit' (kasbon/piutang), 'held' (diparkir).
class Sale {
  final int? id;
  final String invoiceNo;
  final int subtotal; // sebelum diskon transaksi & pajak
  final int discount; // diskon transaksi (Rp)
  final int tax; // pajak (Rp), 0 bila pajak nonaktif
  final int grandTotal;
  final String status;
  final int? customerId;
  final String customerName;
  final int? cashierId;
  final String cashierName;
  final String note;
  final String createdAt; // ISO 8601
  final String createdDate; // yyyy-MM-dd, untuk query laporan

  const Sale({
    this.id,
    required this.invoiceNo,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.grandTotal,
    this.status = 'paid',
    this.customerId,
    this.customerName = '',
    this.cashierId,
    this.cashierName = '',
    this.note = '',
    required this.createdAt,
    required this.createdDate,
  });

  factory Sale.fromMap(Map<String, dynamic> m) {
    return Sale(
      id: m['id'] as int?,
      invoiceNo: m['invoice_no'] as String? ?? '',
      subtotal: (m['subtotal'] as num?)?.toInt() ?? 0,
      discount: (m['discount'] as num?)?.toInt() ?? 0,
      tax: (m['tax'] as num?)?.toInt() ?? 0,
      grandTotal: (m['grand_total'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? 'paid',
      customerId: m['customer_id'] as int?,
      customerName: m['customer_name'] as String? ?? '',
      cashierId: m['cashier_id'] as int?,
      cashierName: m['cashier_name'] as String? ?? '',
      note: m['note'] as String? ?? '',
      createdAt: m['created_at'] as String? ?? '',
      createdDate: m['created_date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'invoice_no': invoiceNo,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'grand_total': grandTotal,
      'status': status,
      'customer_id': customerId,
      'customer_name': customerName,
      'cashier_id': cashierId,
      'cashier_name': cashierName,
      'note': note,
      'created_at': createdAt,
      'created_date': createdDate,
    };
  }

  bool get isHeld => status == 'held';
  bool get isCredit => status == 'credit';
  bool get isPaid => status == 'paid';
}

/// Satu baris item di dalam transaksi.
/// discount_amount disimpan dalam Rupiah (sudah dihitung saat checkout)
/// supaya laporan tidak perlu menghitung ulang.
class SaleItem {
  final int? id;
  final int? saleId;
  final int? productId;
  final String productName;
  final int price; // harga jual saat transaksi
  final int priceBuy; // HPP saat transaksi (untuk laba)
  final int qty;
  final int discount; // nilai diskon (Rp atau %)
  final String discountType; // 'rp' atau 'pct'
  final int discountAmount; // diskon dalam Rp
  final String note;

  const SaleItem({
    this.id,
    this.saleId,
    this.productId,
    required this.productName,
    required this.price,
    required this.priceBuy,
    required this.qty,
    this.discount = 0,
    this.discountType = 'rp',
    this.discountAmount = 0,
    this.note = '',
  });

  factory SaleItem.fromMap(Map<String, dynamic> m) {
    return SaleItem(
      id: m['id'] as int?,
      saleId: m['sale_id'] as int?,
      productId: m['product_id'] as int?,
      productName: m['product_name'] as String? ?? '',
      price: (m['price'] as num?)?.toInt() ?? 0,
      priceBuy: (m['price_buy'] as num?)?.toInt() ?? 0,
      qty: (m['qty'] as num?)?.toInt() ?? 0,
      discount: (m['discount'] as num?)?.toInt() ?? 0,
      discountType: m['discount_type'] as String? ?? 'rp',
      discountAmount: (m['discount_amount'] as num?)?.toInt() ?? 0,
      note: m['note'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'price_buy': priceBuy,
      'qty': qty,
      'discount': discount,
      'discount_type': discountType,
      'discount_amount': discountAmount,
      'note': note,
    };
  }

  int get lineTotal => price * qty - discountAmount;
}

/// Satu pembayaran dalam transaksi.
/// method: 'tunai', 'qris', 'transfer', 'ewallet'.
class Payment {
  final int? id;
  final int? saleId;
  final String method;
  final int amount;
  final String createdAt;
  final String createdDate;

  const Payment({
    this.id,
    this.saleId,
    required this.method,
    required this.amount,
    required this.createdAt,
    required this.createdDate,
  });

  factory Payment.fromMap(Map<String, dynamic> m) {
    return Payment(
      id: m['id'] as int?,
      saleId: m['sale_id'] as int?,
      method: m['method'] as String? ?? 'tunai',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      createdAt: m['created_at'] as String? ?? '',
      createdDate: m['created_date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'sale_id': saleId,
      'method': method,
      'amount': amount,
      'created_at': createdAt,
      'created_date': createdDate,
    };
  }

  static String methodLabel(String method) {
    switch (method) {
      case 'tunai':
        return 'Tunai';
      case 'qris':
        return 'QRIS';
      case 'transfer':
        return 'Transfer';
      case 'ewallet':
        return 'E-Wallet';
      default:
        return method;
    }
  }
}

/// Input pembayaran dari layar kasir (sebelum disimpan).
class PaymentInput {
  final String method;
  final int amount;

  const PaymentInput({required this.method, required this.amount});
}
