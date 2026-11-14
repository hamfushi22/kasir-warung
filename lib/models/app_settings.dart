/// Pengaturan toko (disimpan sebagai key/value di tabel settings).
class AppSettings {
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final bool taxEnabled;
  final int taxRate; // persen, mis. 10 = 10%
  final String receiptHeader;
  final String receiptFooter;

  const AppSettings({
    this.storeName = 'Kasir Warung',
    this.storeAddress = '',
    this.storePhone = '',
    this.taxEnabled = false,
    this.taxRate = 10,
    this.receiptHeader = '',
    this.receiptFooter = 'Terima kasih sudah berbelanja',
  });

  factory AppSettings.fromMap(Map<String, String> m) {
    return AppSettings(
      storeName: m['store_name'] ?? 'Kasir Warung',
      storeAddress: m['store_address'] ?? '',
      storePhone: m['store_phone'] ?? '',
      taxEnabled: (m['tax_enabled'] ?? '0') == '1',
      taxRate: int.tryParse(m['tax_rate'] ?? '10') ?? 10,
      receiptHeader: m['receipt_header'] ?? '',
      receiptFooter: m['receipt_footer'] ?? 'Terima kasih sudah berbelanja',
    );
  }

  Map<String, String> toMap() {
    return <String, String>{
      'store_name': storeName,
      'store_address': storeAddress,
      'store_phone': storePhone,
      'tax_enabled': taxEnabled ? '1' : '0',
      'tax_rate': taxRate.toString(),
      'receipt_header': receiptHeader,
      'receipt_footer': receiptFooter,
    };
  }

  AppSettings copyWith({
    String? storeName,
    String? storeAddress,
    String? storePhone,
    bool? taxEnabled,
    int? taxRate,
    String? receiptHeader,
    String? receiptFooter,
  }) {
    return AppSettings(
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      taxRate: taxRate ?? this.taxRate,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
    );
  }
}
