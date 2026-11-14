/// Pelanggan toko (untuk kasbon / piutang).
class Customer {
  final int? id;
  final String name;
  final String phone;
  final String address;

  const Customer({
    this.id,
    required this.name,
    this.phone = '',
    this.address = '',
  });

  factory Customer.fromMap(Map<String, dynamic> m) {
    return Customer(
      id: m['id'] as int?,
      name: m['name'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      address: m['address'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'phone': phone,
      'address': address,
    };
  }
}

/// Piutang / kasbon pelanggan.
/// status: 'open' (masih ada sisa) atau 'paid' (lunas).
class Receivable {
  final int? id;
  final int? customerId;
  final String customerName;
  final int? saleId;
  final String invoiceNo;
  final int total;
  final int paid;
  final String status;
  final String createdAt;
  final String createdDate;

  const Receivable({
    this.id,
    this.customerId,
    required this.customerName,
    this.saleId,
    this.invoiceNo = '',
    required this.total,
    this.paid = 0,
    this.status = 'open',
    required this.createdAt,
    required this.createdDate,
  });

  factory Receivable.fromMap(Map<String, dynamic> m) {
    return Receivable(
      id: m['id'] as int?,
      customerId: m['customer_id'] as int?,
      customerName: m['customer_name'] as String? ?? '',
      saleId: m['sale_id'] as int?,
      invoiceNo: m['invoice_no'] as String? ?? '',
      total: (m['total'] as num?)?.toInt() ?? 0,
      paid: (m['paid'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? 'open',
      createdAt: m['created_at'] as String? ?? '',
      createdDate: m['created_date'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'customer_id': customerId,
      'customer_name': customerName,
      'sale_id': saleId,
      'invoice_no': invoiceNo,
      'total': total,
      'paid': paid,
      'status': status,
      'created_at': createdAt,
      'created_date': createdDate,
    };
  }

  int get remaining => total - paid;
  bool get isPaid => status == 'paid' || remaining <= 0;
}
