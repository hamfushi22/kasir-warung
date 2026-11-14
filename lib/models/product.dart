/// Kategori produk, mis. Minuman, Sembako, Rokok.
class Category {
  final int? id;
  final String name;

  const Category({this.id, required this.name});

  factory Category.fromMap(Map<String, dynamic> m) {
    return Category(
      id: m['id'] as int?,
      name: m['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'name': name};
  }
}

/// Produk jualan. Semua uang disimpan sebagai int (Rupiah, tanpa desimal).
class Product {
  final int? id;
  final String name;
  final String sku;
  final String barcode;
  final int? categoryId;
  final String categoryName; // denormalisasi untuk tampilan
  final String unit;
  final int priceBuy;
  final int priceSell;
  final int? priceWholesale;
  final int stock;
  final int stockMinimum;
  final bool isService; // true = jasa/non-stok (pulsa, token), stok tidak berkurang
  final bool isActive;
  final bool isDemo; // true = data contoh dari template, boleh dihapus massal

  const Product({
    this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    this.categoryId,
    this.categoryName = '',
    this.unit = 'pcs',
    required this.priceBuy,
    required this.priceSell,
    this.priceWholesale,
    this.stock = 0,
    this.stockMinimum = 0,
    this.isService = false,
    this.isActive = true,
    this.isDemo = false,
  });

  factory Product.fromMap(Map<String, dynamic> m) {
    return Product(
      id: m['id'] as int?,
      name: m['name'] as String? ?? '',
      sku: m['sku'] as String? ?? '',
      barcode: m['barcode'] as String? ?? '',
      categoryId: m['category_id'] as int?,
      categoryName: m['category_name'] as String? ?? '',
      unit: m['unit'] as String? ?? 'pcs',
      priceBuy: (m['price_buy'] as num?)?.toInt() ?? 0,
      priceSell: (m['price_sell'] as num?)?.toInt() ?? 0,
      priceWholesale: (m['price_wholesale'] as num?)?.toInt(),
      stock: (m['stock'] as num?)?.toInt() ?? 0,
      stockMinimum: (m['stock_minimum'] as num?)?.toInt() ?? 0,
      isService: (m['is_service'] as num? ?? 0) == 1,
      isActive: (m['is_active'] as num? ?? 1) == 1,
      isDemo: (m['is_demo'] as num? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'category_id': categoryId,
      'category_name': categoryName,
      'unit': unit,
      'price_buy': priceBuy,
      'price_sell': priceSell,
      'price_wholesale': priceWholesale,
      'stock': stock,
      'stock_minimum': stockMinimum,
      'is_service': isService ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_demo': isDemo ? 1 : 0,
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    String? barcode,
    int? categoryId,
    String? categoryName,
    String? unit,
    int? priceBuy,
    int? priceSell,
    int? priceWholesale,
    int? stock,
    int? stockMinimum,
    bool? isService,
    bool? isActive,
    bool? isDemo,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unit: unit ?? this.unit,
      priceBuy: priceBuy ?? this.priceBuy,
      priceSell: priceSell ?? this.priceSell,
      priceWholesale: priceWholesale ?? this.priceWholesale,
      stock: stock ?? this.stock,
      stockMinimum: stockMinimum ?? this.stockMinimum,
      isService: isService ?? this.isService,
      isActive: isActive ?? this.isActive,
      isDemo: isDemo ?? this.isDemo,
    );
  }

  /// Stok menipis: stok sudah menyentuh / di bawah batas minimum.
  bool get isLowStock => !isService && isActive && stock <= stockMinimum;

  bool get isOutOfStock => !isService && isActive && stock <= 0;
}
