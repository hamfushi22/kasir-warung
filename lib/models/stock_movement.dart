/// Satu perubahan stok.
/// type: 'in' (masuk), 'out' (keluar), 'adjust' (penyesuaian/opname), 'sale' (terjual).
class StockMovement {
  final int? id;
  final int? productId;
  final String productName;
  final String type;
  final int qty; // positif = bertambah, negatif = berkurang
  final String note;
  final String createdAt;
  final String createdDate;
  final int? userId;

  const StockMovement({
    this.id,
    this.productId,
    required this.productName,
    required this.type,
    required this.qty,
    this.note = '',
    required this.createdAt,
    required this.createdDate,
    this.userId,
  });

  factory StockMovement.fromMap(Map<String, dynamic> m) {
    return StockMovement(
      id: m['id'] as int?,
      productId: m['product_id'] as int?,
      productName: m['product_name'] as String? ?? '',
      type: m['type'] as String? ?? 'in',
      qty: (m['qty'] as num?)?.toInt() ?? 0,
      note: m['note'] as String? ?? '',
      createdAt: m['created_at'] as String? ?? '',
      createdDate: m['created_date'] as String? ?? '',
      userId: m['user_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'product_id': productId,
      'product_name': productName,
      'type': type,
      'qty': qty,
      'note': note,
      'created_at': createdAt,
      'created_date': createdDate,
      'user_id': userId,
    };
  }

  static String typeLabel(String type) {
    switch (type) {
      case 'in':
        return 'Masuk';
      case 'out':
        return 'Keluar';
      case 'adjust':
        return 'Penyesuaian';
      case 'sale':
        return 'Terjual';
      default:
        return type;
    }
  }
}
