import 'package:flutter/foundation.dart' hide Category;

import '../db/database_helper.dart';
import '../models/app_settings.dart';
import '../models/product.dart';

/// Katalog produk + kategori + pengaturan toko.
class CatalogProvider extends ChangeNotifier {
  List<Product> products = <Product>[];
  List<Category> categories = <Category>[];
  AppSettings settings = const AppSettings();
  bool loading = false;

  Future<void> loadAll() async {
    loading = true;
    notifyListeners();
    final DatabaseHelper db = DatabaseHelper.instance;
    products = await db.getProducts();
    categories = await db.getCategories();
    settings = await db.loadSettings();
    loading = false;
    notifyListeners();
  }

  Future<void> refreshProducts() async {
    products = await DatabaseHelper.instance.getProducts();
    notifyListeners();
  }

  Future<void> refreshSettings() async {
    settings = await DatabaseHelper.instance.loadSettings();
    notifyListeners();
  }

  Future<void> saveSettings(AppSettings s) async {
    await DatabaseHelper.instance.saveSettings(s);
    settings = s;
    notifyListeners();
  }

  List<Product> get lowStock =>
      products.where((Product p) => p.isLowStock).toList();

  Product? findById(int? id) {
    if (id == null) return null;
    for (final Product p in products) {
      if (p.id == id) return p;
    }
    return null;
  }
}
