import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';
import '../models/app_user.dart';
import '../models/cash.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/stock_movement.dart';

/// Satu-satunya akses ke SQLite lokal (offline-first).
/// Semua tabel dibuat di onCreate + data awal (seed) dimasukkan sekali.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const String _dbName = 'kasir_warung.db';
  static const int _version = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final String path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: _createDb,
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1: belum ada migrasi. Tambahkan ALTER TABLE di sini bila versi naik.
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helper tanggal (disimpan sebagai teks agar query laporan mudah).
  // ---------------------------------------------------------------------------

  static String dateStr(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static String todayStr() => dateStr(DateTime.now());

  static String nowIso() => DateTime.now().toIso8601String();

  // ---------------------------------------------------------------------------
  // Skema + seed.
  // ---------------------------------------------------------------------------

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pin TEXT NOT NULL,
        role TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1
      )''');
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )''');
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT NOT NULL DEFAULT '',
        barcode TEXT NOT NULL DEFAULT '',
        category_id INTEGER,
        category_name TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT 'pcs',
        price_buy INTEGER NOT NULL DEFAULT 0,
        price_sell INTEGER NOT NULL DEFAULT 0,
        price_wholesale INTEGER,
        stock INTEGER NOT NULL DEFAULT 0,
        stock_minimum INTEGER NOT NULL DEFAULT 0,
        is_service INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        is_demo INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE stock_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        product_name TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL,
        qty INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        created_date TEXT NOT NULL,
        user_id INTEGER
      )''');
    await db.execute('''
      CREATE TABLE customers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        address TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute('''
      CREATE TABLE receivables(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER,
        customer_name TEXT NOT NULL DEFAULT '',
        sale_id INTEGER,
        invoice_no TEXT NOT NULL DEFAULT '',
        total INTEGER NOT NULL DEFAULT 0,
        paid INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'open',
        created_at TEXT NOT NULL,
        created_date TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL,
        subtotal INTEGER NOT NULL DEFAULT 0,
        discount INTEGER NOT NULL DEFAULT 0,
        tax INTEGER NOT NULL DEFAULT 0,
        grand_total INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'paid',
        customer_id INTEGER,
        customer_name TEXT NOT NULL DEFAULT '',
        cashier_id INTEGER,
        cashier_name TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        created_date TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE sale_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL DEFAULT '',
        price INTEGER NOT NULL DEFAULT 0,
        price_buy INTEGER NOT NULL DEFAULT 0,
        qty INTEGER NOT NULL DEFAULT 0,
        discount INTEGER NOT NULL DEFAULT 0,
        discount_type TEXT NOT NULL DEFAULT 'rp',
        discount_amount INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute('''
      CREATE TABLE payments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        method TEXT NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        created_date TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE cash_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        user_name TEXT NOT NULL DEFAULT '',
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        opening_cash INTEGER NOT NULL DEFAULT 0,
        closing_cash INTEGER,
        expected_cash INTEGER,
        difference INTEGER,
        status TEXT NOT NULL DEFAULT 'open'
      )''');
    await db.execute('''
      CREATE TABLE cash_movements(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        created_date TEXT NOT NULL,
        user_id INTEGER
      )''');
    await db.execute('''
      CREATE TABLE activity_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        user_name TEXT NOT NULL DEFAULT '',
        action TEXT NOT NULL,
        detail TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE settings(
        "key" TEXT PRIMARY KEY,
        value TEXT NOT NULL DEFAULT ''
      )''');
    await db.execute('''
      CREATE TABLE sync_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        payload TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'pending',
        created_at TEXT NOT NULL
      )''');

    await db.execute('CREATE INDEX idx_sales_date ON sales(created_date)');
    await db.execute('CREATE INDEX idx_sales_status ON sales(status)');
    await db.execute('CREATE INDEX idx_payments_sale ON payments(sale_id)');
    await db.execute('CREATE INDEX idx_items_sale ON sale_items(sale_id)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_products_name ON products(name)');

    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    // Pengguna awal. PIN DEMO — ganti di Pengaturan setelah instalasi.
    await db.insert('users',
        {'name': 'Owner', 'pin': '1234', 'role': 'owner', 'active': 1});
    await db.insert('users',
        {'name': 'Kasir', 'pin': '1111', 'role': 'kasir', 'active': 1});

    // Kategori awal.
    const List<String> cats = <String>[
      'Minuman',
      'Sembako',
      'Makanan',
      'Rokok',
      'Perawatan',
      'Lainnya',
    ];
    final Map<String, int> catIds = <String, int>{};
    for (final String c in cats) {
      final int id = await db.insert('categories', {'name': c});
      catIds[c] = id;
    }

    // 8 produk contoh dari template-produk.csv (ditandai is_demo = 1).
    final List<Product> demo = <Product>[
      Product(
          name: 'Kopi Hitam 165g',
          sku: 'BRG-001',
          barcode: '8991234567890',
          categoryId: catIds['Minuman'],
          categoryName: 'Minuman',
          unit: 'pcs',
          priceBuy: 8500,
          priceSell: 10000,
          priceWholesale: 9500,
          stock: 24,
          stockMinimum: 6,
          isDemo: true),
      Product(
          name: 'Gula Pasir 1kg',
          sku: 'BRG-002',
          categoryId: catIds['Sembako'],
          categoryName: 'Sembako',
          unit: 'pcs',
          priceBuy: 16500,
          priceSell: 18000,
          priceWholesale: 17500,
          stock: 30,
          stockMinimum: 10,
          isDemo: true),
      Product(
          name: 'Minyak Goreng 1L',
          sku: 'BRG-003',
          categoryId: catIds['Sembako'],
          categoryName: 'Sembako',
          unit: 'pcs',
          priceBuy: 36000,
          priceSell: 39000,
          priceWholesale: 38000,
          stock: 18,
          stockMinimum: 6,
          isDemo: true),
      Product(
          name: 'Mie Instan Goreng',
          sku: 'BRG-004',
          categoryId: catIds['Makanan'],
          categoryName: 'Makanan',
          unit: 'pcs',
          priceBuy: 2900,
          priceSell: 3500,
          priceWholesale: 3200,
          stock: 120,
          stockMinimum: 24,
          isDemo: true),
      Product(
          name: 'Teh Celup isi 25',
          sku: 'BRG-005',
          categoryId: catIds['Minuman'],
          categoryName: 'Minuman',
          unit: 'dus',
          priceBuy: 11500,
          priceSell: 14000,
          priceWholesale: 13000,
          stock: 12,
          stockMinimum: 4,
          isDemo: true),
      Product(
          name: 'Rokok Filter 12',
          sku: 'BRG-006',
          categoryId: catIds['Rokok'],
          categoryName: 'Rokok',
          unit: 'pcs',
          priceBuy: 21500,
          priceSell: 24000,
          stock: 20,
          stockMinimum: 5,
          isDemo: true),
      Product(
          name: 'Air Mineral 600ml',
          sku: 'BRG-007',
          categoryId: catIds['Minuman'],
          categoryName: 'Minuman',
          unit: 'pcs',
          priceBuy: 2800,
          priceSell: 3500,
          priceWholesale: 3200,
          stock: 48,
          stockMinimum: 12,
          isDemo: true),
      Product(
          name: 'Sabun Mandi Batang',
          sku: 'BRG-008',
          categoryId: catIds['Perawatan'],
          categoryName: 'Perawatan',
          unit: 'pcs',
          priceBuy: 4500,
          priceSell: 5500,
          priceWholesale: 5000,
          stock: 36,
          stockMinimum: 6,
          isDemo: true),
    ];
    for (final Product p in demo) {
      await db.insert('products', p.toMap());
    }

    // Pengaturan awal.
    const Map<String, String> defaults = <String, String>{
      'store_name': 'Kasir Warung',
      'store_address': '',
      'store_phone': '',
      'tax_enabled': '0',
      'tax_rate': '10',
      'receipt_header': '',
      'receipt_footer': 'Terima kasih sudah berbelanja',
    };
    for (final MapEntry<String, String> e in defaults.entries) {
      await db.insert('settings', {'key': e.key, 'value': e.value});
    }
  }

  // ---------------------------------------------------------------------------
  // Pengaturan.
  // ---------------------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('settings',
        columns: ['value'], where: '"key" = ?', whereArgs: [key], limit: 1);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final Database db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppSettings> loadSettings() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('settings');
    final Map<String, String> m = <String, String>{};
    for (final Map<String, dynamic> row in maps) {
      m[row['key'] as String] = row['value'] as String? ?? '';
    }
    return AppSettings.fromMap(m);
  }

  Future<void> saveSettings(AppSettings s) async {
    for (final MapEntry<String, String> e in s.toMap().entries) {
      await setSetting(e.key, e.value);
    }
  }

  // ---------------------------------------------------------------------------
  // Pengguna.
  // ---------------------------------------------------------------------------

  Future<AppUser?> findUserByPin(String pin) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users',
        where: 'pin = ? AND active = 1', whereArgs: [pin], limit: 1);
    if (maps.isEmpty) return null;
    return AppUser.fromMap(maps.first);
  }

  Future<List<AppUser>> getUsers() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('users', orderBy: 'id ASC');
    return maps.map((Map<String, dynamic> m) => AppUser.fromMap(m)).toList();
  }

  Future<void> updateUserPin(int id, String pin) async {
    final Database db = await database;
    await db.update('users', {'pin': pin},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> addUser(AppUser u) async {
    final Database db = await database;
    return db.insert('users', u.toMap());
  }

  // ---------------------------------------------------------------------------
  // Kategori.
  // ---------------------------------------------------------------------------

  Future<List<Category>> getCategories() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('categories', orderBy: 'name ASC');
    return maps.map((Map<String, dynamic> m) => Category.fromMap(m)).toList();
  }

  Future<int> addCategory(String name) async {
    final Database db = await database;
    return db.insert('categories', {'name': name.trim()},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> deleteCategory(int id) async {
    final Database db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Produk.
  // ---------------------------------------------------------------------------

  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    bool activeOnly = true,
  }) async {
    final Database db = await database;
    final List<String> where = <String>[];
    final List<dynamic> args = <dynamic>[];
    if (activeOnly) {
      where.add('is_active = 1');
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (query != null && query.trim().isNotEmpty) {
      final String q = '%${query.trim()}%';
      where.add('(name LIKE ? OR sku LIKE ? OR barcode LIKE ?)');
      args.addAll(<String>[q, q, q]);
    }
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return maps.map((Map<String, dynamic> m) => Product.fromMap(m)).toList();
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products',
        where: 'barcode = ? AND is_active = 1',
        whereArgs: [barcode.trim()],
        limit: 1);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<Product?> getProductById(int id) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<int> insertProduct(Product p) async {
    final Database db = await database;
    return db.insert('products', p.toMap());
  }

  Future<void> updateProduct(Product p) async {
    final Database db = await database;
    await db.update('products', p.toMap(),
        where: 'id = ?', whereArgs: [p.id]);
  }

  Future<void> setProductActive(int id, bool active) async {
    final Database db = await database;
    await db.update('products', {'is_active': active ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Hapus semua produk contoh (is_demo = 1). Mengembalikan jumlah yang dihapus.
  Future<int> deleteDemoProducts() async {
    final Database db = await database;
    return db.delete('products', where: 'is_demo = 1');
  }

  Future<List<Product>> getLowStockProducts() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('products',
        where: 'is_active = 1 AND is_service = 0 AND stock <= stock_minimum',
        orderBy: 'stock ASC');
    return maps.map((Map<String, dynamic> m) => Product.fromMap(m)).toList();
  }

  // ---------------------------------------------------------------------------
  // Stok.
  // ---------------------------------------------------------------------------

  /// Catat perubahan stok (qtyDelta bertanda: + masuk, - keluar).
  Future<void> recordStockChange({
    required int productId,
    required int qtyDelta,
    required String type,
    required String note,
    required int? userId,
  }) async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      final List<Map<String, dynamic>> maps = await txn.query('products',
          columns: <String>['stock', 'name'],
          where: 'id = ?',
          whereArgs: <int>[productId],
          limit: 1);
      if (maps.isEmpty) return;
      final int current = (maps.first['stock'] as num?)?.toInt() ?? 0;
      int next = current + qtyDelta;
      if (next < 0) next = 0;
      await txn.update('products', {'stock': next},
          where: 'id = ?', whereArgs: <int>[productId]);
      await txn.insert('stock_movements', <String, dynamic>{
        'product_id': productId,
        'product_name': maps.first['name'] as String? ?? '',
        'type': type,
        'qty': qtyDelta,
        'note': note,
        'created_at': nowIso(),
        'created_date': todayStr(),
        'user_id': userId,
      });
    });
  }

  /// Opname: set stok ke angka absolut (selisih tercatat sebagai 'adjust').
  Future<void> setStockAbsolute({
    required int productId,
    required int newStock,
    required String note,
    required int? userId,
  }) async {
    final Product? p = await getProductById(productId);
    if (p == null) return;
    final int delta = newStock - p.stock;
    if (delta == 0) return;
    await recordStockChange(
      productId: productId,
      qtyDelta: delta,
      type: 'adjust',
      note: note,
      userId: userId,
    );
  }

  Future<List<StockMovement>> getStockMovements(int productId,
      {int limit = 100}) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('stock_movements',
        where: 'product_id = ?',
        whereArgs: <int>[productId],
        orderBy: 'id DESC',
        limit: limit);
    return maps
        .map((Map<String, dynamic> m) => StockMovement.fromMap(m))
        .toList();
  }

  Future<List<StockMovement>> getRecentStockMovements({int limit = 50}) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('stock_movements',
        orderBy: 'id DESC', limit: limit);
    return maps
        .map((Map<String, dynamic> m) => StockMovement.fromMap(m))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Penjualan.
  // ---------------------------------------------------------------------------

  Future<List<Sale>> getSales({
    String? fromDate,
    String? toDate,
    String? query,
    String? status,
    int? cashierId,
    int limit = 100,
  }) async {
    final Database db = await database;
    final List<String> where = <String>[];
    final List<dynamic> args = <dynamic>[];
    if (fromDate != null) {
      where.add('created_date >= ?');
      args.add(fromDate);
    }
    if (toDate != null) {
      where.add('created_date <= ?');
      args.add(toDate);
    }
    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (cashierId != null) {
      where.add('cashier_id = ?');
      args.add(cashierId);
    }
    if (query != null && query.trim().isNotEmpty) {
      final String q = '%${query.trim()}%';
      where.add('(invoice_no LIKE ? OR customer_name LIKE ?)');
      args.addAll(<String>[q, q]);
    }
    final List<Map<String, dynamic>> maps = await db.query(
      'sales',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'id DESC',
      limit: limit,
    );
    return maps.map((Map<String, dynamic> m) => Sale.fromMap(m)).toList();
  }

  Future<Sale?> getSaleById(int id) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sales',
        where: 'id = ?', whereArgs: <int>[id], limit: 1);
    if (maps.isEmpty) return null;
    return Sale.fromMap(maps.first);
  }

  Future<List<SaleItem>> getSaleItems(int saleId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sale_items',
        where: 'sale_id = ?', whereArgs: <int>[saleId], orderBy: 'id ASC');
    return maps.map((Map<String, dynamic> m) => SaleItem.fromMap(m)).toList();
  }

  Future<List<Payment>> getSalePayments(int saleId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('payments',
        where: 'sale_id = ?', whereArgs: <int>[saleId], orderBy: 'id ASC');
    return maps.map((Map<String, dynamic> m) => Payment.fromMap(m)).toList();
  }

  Future<List<Sale>> getHeldSales() async {
    return getSales(status: 'held', limit: 50);
  }

  /// Hapus transaksi yang diparkir (held) beserta itemnya.
  Future<void> deleteSale(int id) async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      await txn.delete('sale_items', where: 'sale_id = ?', whereArgs: [id]);
      await txn.delete('payments', where: 'sale_id = ?', whereArgs: [id]);
      await txn.delete('sales', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<Map<String, int>> salesSummary({
    required String fromDate,
    required String toDate,
    int? cashierId,
  }) async {
    final Database db = await database;
    final StringBuffer where =
        StringBuffer("status != 'held' AND created_date BETWEEN ? AND ?");
    final List<dynamic> args = <dynamic>[fromDate, toDate];
    if (cashierId != null) {
      where.write(' AND cashier_id = ?');
      args.add(cashierId);
    }
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM(grand_total), 0) AS total, COUNT(*) AS cnt '
      'FROM sales WHERE $where',
      args,
    );
    return <String, int>{
      'total': (rows.first['total'] as num?)?.toInt() ?? 0,
      'count': (rows.first['cnt'] as num?)?.toInt() ?? 0,
    };
  }

  /// Laba kotor = Σ((harga jual − HPP) × qty − diskon item).
  Future<int> grossProfit({
    required String fromDate,
    required String toDate,
  }) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM((si.price - si.price_buy) * si.qty '
      '- si.discount_amount), 0) AS profit '
      'FROM sale_items si JOIN sales s ON s.id = si.sale_id '
      "WHERE s.status != 'held' AND s.created_date BETWEEN ? AND ?",
      <String>[fromDate, toDate],
    );
    return (rows.first['profit'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> topProducts({
    required String fromDate,
    required String toDate,
    int limit = 10,
  }) async {
    final Database db = await database;
    return db.rawQuery(
      'SELECT si.product_name AS name, SUM(si.qty) AS qty, '
      'SUM(si.price * si.qty - si.discount_amount) AS amount '
      'FROM sale_items si JOIN sales s ON s.id = si.sale_id '
      "WHERE s.status != 'held' AND s.created_date BETWEEN ? AND ? "
      'GROUP BY si.product_id, si.product_name '
      'ORDER BY qty DESC LIMIT ?',
      <dynamic>[fromDate, toDate, limit],
    );
  }

  Future<List<Map<String, dynamic>>> salesByCategory({
    required String fromDate,
    required String toDate,
  }) async {
    final Database db = await database;
    return db.rawQuery(
      "SELECT COALESCE(p.category_name, '') AS name, "
      'SUM(si.price * si.qty - si.discount_amount) AS amount, '
      'SUM(si.qty) AS qty '
      'FROM sale_items si LEFT JOIN products p ON p.id = si.product_id '
      'JOIN sales s ON s.id = si.sale_id '
      "WHERE s.status != 'held' AND s.created_date BETWEEN ? AND ? "
      "GROUP BY COALESCE(p.category_name, '') ORDER BY amount DESC",
      <String>[fromDate, toDate],
    );
  }

  Future<List<Map<String, dynamic>>> salesByPayment({
    required String fromDate,
    required String toDate,
  }) async {
    final Database db = await database;
    return db.rawQuery(
      'SELECT p.method AS method, SUM(p.amount) AS amount, COUNT(*) AS cnt '
      'FROM payments p JOIN sales s ON s.id = p.sale_id '
      "WHERE s.status != 'held' AND s.created_date BETWEEN ? AND ? "
      'GROUP BY p.method ORDER BY amount DESC',
      <String>[fromDate, toDate],
    );
  }

  Future<List<Map<String, dynamic>>> dailyTotals({
    required String fromDate,
    required String toDate,
  }) async {
    final Database db = await database;
    return db.rawQuery(
      'SELECT created_date AS date, COALESCE(SUM(grand_total), 0) AS total, '
      'COUNT(*) AS cnt FROM sales '
      "WHERE status != 'held' AND created_date BETWEEN ? AND ? "
      'GROUP BY created_date ORDER BY created_date ASC',
      <String>[fromDate, toDate],
    );
  }

  // ---------------------------------------------------------------------------
  // Pelanggan & piutang.
  // ---------------------------------------------------------------------------

  Future<List<Customer>> getCustomers() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('customers', orderBy: 'name ASC');
    return maps.map((Map<String, dynamic> m) => Customer.fromMap(m)).toList();
  }

  Future<int> addCustomer(Customer c) async {
    final Database db = await database;
    return db.insert('customers', c.toMap());
  }

  Future<Customer> findOrCreateCustomer(String name, {String phone = ''}) async {
    final Database db = await database;
    final String trimmed = name.trim();
    final List<Map<String, dynamic>> maps = await db.query('customers',
        where: 'name = ?', whereArgs: <String>[trimmed], limit: 1);
    if (maps.isNotEmpty) return Customer.fromMap(maps.first);
    final int id = await db.insert(
        'customers', <String, dynamic>{'name': trimmed, 'phone': phone, 'address': ''});
    return Customer(id: id, name: trimmed, phone: phone);
  }

  Future<List<Receivable>> getReceivables({bool openOnly = true}) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'receivables',
      where: openOnly ? 'status = ?' : null,
      whereArgs: openOnly ? <String>['open'] : null,
      orderBy: 'id DESC',
    );
    return maps
        .map((Map<String, dynamic> m) => Receivable.fromMap(m))
        .toList();
  }

  Future<List<Receivable>> getReceivablesByCustomer(int customerId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('receivables',
        where: 'customer_id = ?',
        whereArgs: <int>[customerId],
        orderBy: 'id DESC');
    return maps
        .map((Map<String, dynamic> m) => Receivable.fromMap(m))
        .toList();
  }

  Future<int> insertReceivable(Receivable r) async {
    final Database db = await database;
    return db.insert('receivables', r.toMap());
  }

  /// Bayar piutang (sebagian / lunas). Bila ada sesi kas terbuka (sessionId),
  /// uang masuk dicatat sebagai pemasukan kas.
  Future<void> payReceivable({
    required int receivableId,
    required int amount,
    required int? userId,
    required String userName,
    int? sessionId,
  }) async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      final List<Map<String, dynamic>> maps = await txn.query('receivables',
          where: 'id = ?', whereArgs: <int>[receivableId], limit: 1);
      if (maps.isEmpty) return;
      final Receivable r = Receivable.fromMap(maps.first);
      final int newPaid = r.paid + amount;
      final String status = newPaid >= r.total ? 'paid' : 'open';
      await txn.update('receivables', {'paid': newPaid, 'status': status},
          where: 'id = ?', whereArgs: <int>[receivableId]);
      if (sessionId != null) {
        await txn.insert('cash_movements', <String, dynamic>{
          'session_id': sessionId,
          'type': 'in',
          'amount': amount,
          'note': 'Pelunasan kasbon ${r.customerName} (${r.invoiceNo})',
          'created_at': nowIso(),
          'created_date': todayStr(),
          'user_id': userId,
        });
      }
      await txn.insert('activity_logs', <String, dynamic>{
        'user_id': userId,
        'user_name': userName,
        'action': 'Bayar piutang',
        'detail': '${r.customerName} bayar $amount untuk ${r.invoiceNo}',
        'created_at': nowIso(),
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Kas.
  // ---------------------------------------------------------------------------

  Future<CashSession?> getOpenSession() async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cash_sessions',
        where: 'status = ?', whereArgs: <String>['open'], limit: 1);
    if (maps.isEmpty) return null;
    return CashSession.fromMap(maps.first);
  }

  Future<CashSession> openSession({
    required int? userId,
    required String userName,
    required int openingCash,
  }) async {
    final Database db = await database;
    final int id = await db.insert('cash_sessions', <String, dynamic>{
      'user_id': userId,
      'user_name': userName,
      'opened_at': nowIso(),
      'closed_at': null,
      'opening_cash': openingCash,
      'closing_cash': null,
      'expected_cash': null,
      'difference': null,
      'status': 'open',
    });
    final List<Map<String, dynamic>> maps = await db.query('cash_sessions',
        where: 'id = ?', whereArgs: <int>[id], limit: 1);
    return CashSession.fromMap(maps.first);
  }

  Future<List<CashSession>> getSessions({int limit = 20}) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cash_sessions',
        orderBy: 'id DESC', limit: limit);
    return maps
        .map((Map<String, dynamic> m) => CashSession.fromMap(m))
        .toList();
  }

  Future<List<CashMovement>> getSessionMovements(int sessionId) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cash_movements',
        where: 'session_id = ?',
        whereArgs: <int>[sessionId],
        orderBy: 'id DESC');
    return maps
        .map((Map<String, dynamic> m) => CashMovement.fromMap(m))
        .toList();
  }

  Future<void> addCashMovement({
    int? sessionId,
    required String type,
    required int amount,
    required String note,
    required int? userId,
  }) async {
    final Database db = await database;
    await db.insert('cash_movements', <String, dynamic>{
      'session_id': sessionId,
      'type': type,
      'amount': amount,
      'note': note,
      'created_at': nowIso(),
      'created_date': todayStr(),
      'user_id': userId,
    });
  }

  Future<int> _sumMovements(int sessionId, String type) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM cash_movements '
      'WHERE session_id = ? AND type = ?',
      <dynamic>[sessionId, type],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Total pembayaran tunai sejak [openedAtIso] (transaksi lunas/kasbon lunas).
  Future<int> cashSalesSince(String openedAtIso) async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM(p.amount), 0) AS total FROM payments p '
      'JOIN sales s ON s.id = p.sale_id '
      "WHERE p.method = 'tunai' AND s.status != 'held' "
      'AND s.created_at >= ?',
      <String>[openedAtIso],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  /// Tutup sesi: hitung kas yang seharusnya ada, bandingkan dengan kas fisik.
  Future<CashSession> closeSession({
    required int sessionId,
    required int closingCash,
  }) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cash_sessions',
        where: 'id = ?', whereArgs: <int>[sessionId], limit: 1);
    if (maps.isEmpty) throw StateError('Sesi kas tidak ditemukan');
    final CashSession session = CashSession.fromMap(maps.first);
    final int cashSales = await cashSalesSince(session.openedAt);
    final int inSum = await _sumMovements(sessionId, 'in');
    final int outSum = await _sumMovements(sessionId, 'out');
    final int expected =
        session.openingCash + cashSales + inSum - outSum;
    final int difference = closingCash - expected;
    await db.update(
      'cash_sessions',
      <String, dynamic>{
        'closed_at': nowIso(),
        'closing_cash': closingCash,
        'expected_cash': expected,
        'difference': difference,
        'status': 'closed',
      },
      where: 'id = ?',
      whereArgs: <int>[sessionId],
    );
    final List<Map<String, dynamic>> updated = await db.query('cash_sessions',
        where: 'id = ?', whereArgs: <int>[sessionId], limit: 1);
    return CashSession.fromMap(updated.first);
  }

  // ---------------------------------------------------------------------------
  // Log aktivitas.
  // ---------------------------------------------------------------------------

  Future<void> logActivity(
      int? userId, String userName, String action, String detail) async {
    final Database db = await database;
    await db.insert('activity_logs', <String, dynamic>{
      'user_id': userId,
      'user_name': userName,
      'action': action,
      'detail': detail,
      'created_at': nowIso(),
    });
  }

  Future<List<ActivityLog>> getActivityLogs({int limit = 100}) async {
    final Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query('activity_logs',
        orderBy: 'id DESC', limit: limit);
    return maps
        .map((Map<String, dynamic> m) => ActivityLog.fromMap(m))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Antrean sync (siap-sync, sinkronisasi masih nonaktif — lihat SyncService).
  // ---------------------------------------------------------------------------

  Future<void> enqueueSync(
      String tableName, int recordId, String payload) async {
    final Database db = await database;
    await db.insert('sync_queue', <String, dynamic>{
      'table_name': tableName,
      'record_id': recordId,
      'payload': payload,
      'status': 'pending',
      'created_at': nowIso(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingSync() async {
    final Database db = await database;
    return db.query('sync_queue',
        where: 'status = ?', whereArgs: <String>['pending'], orderBy: 'id ASC');
  }

  Future<void> markSyncSent(List<int> ids) async {
    if (ids.isEmpty) return;
    final Database db = await database;
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    await db.update(
      'sync_queue',
      <String, dynamic>{'status': 'sent'},
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<int> pendingSyncCount() async {
    final Database db = await database;
    final List<Map<String, dynamic>> rows = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM sync_queue WHERE status = 'pending'");
    return (rows.first['cnt'] as num?)?.toInt() ?? 0;
  }
}
