import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../services/csv_service.dart';
import '../services/money.dart';
import '../widgets/empty_state.dart';
import 'product_form_screen.dart';

/// Daftar produk: cari, filter kategori, tambah/edit, import/export CSV.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';
  int? _categoryId;

  List<Product> _filtered(List<Product> all) {
    final String q = _query.trim().toLowerCase();
    return all.where((Product p) {
      if (_categoryId != null && p.categoryId != _categoryId) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q) ||
          p.barcode.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openForm([Product? product]) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
          builder: (_) => ProductFormScreen(product: product)),
    );
    if (changed == true && mounted) {
      await context.read<CatalogProvider>().refreshProducts();
    }
  }

  Future<void> _deleteProduct(Product p) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Nonaktifkan ${p.name}?'),
        content: const Text(
            'Produk tidak dihapus permanen — hanya disembunyikan dari kasir '
            'dan daftar. Riwayat transaksi tetap tersimpan.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Nonaktifkan')),
        ],
      ),
    );
    if (ok != true || p.id == null) return;
    await DatabaseHelper.instance.setProductActive(p.id!, false);
    if (!mounted) return;
    await context.read<CatalogProvider>().refreshProducts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${p.name} dinonaktifkan')),
    );
  }

  Future<void> _exportCsv() async {
    final List<Product> products =
        await DatabaseHelper.instance.getProducts(activeOnly: false);
    final String csv = CsvService.build(products);
    await Share.share(csv, subject: 'Data Produk - Kasir Warung');
  }

  Future<void> _importCsv() async {
    final TextEditingController ctrl = TextEditingController();
    final bool? doImport = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Import Produk dari CSV'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'Tempel isi file CSV (format persis template-produk.csv). '
                  'Baris contoh dari template bisa dimuat dengan tombol di bawah.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final String template = await rootBundle
                        .loadString('assets/template-produk.csv');
                    ctrl.text = template;
                  },
                  child: const Text('Muat Template Contoh'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    hintText: 'nama,sku,barcode,...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );
    if (doImport != true) return;
    final ({List<Product> products, List<String> errors}) result =
        CsvService.parse(ctrl.text);
    int inserted = 0;
    final DatabaseHelper db = DatabaseHelper.instance;
    for (final Product p in result.products) {
      int? catId;
      if (p.categoryName.isNotEmpty) {
        final List<Category> cats = await db.getCategories();
        Category? found;
        for (final Category c in cats) {
          if (c.name.toLowerCase() == p.categoryName.toLowerCase()) {
            found = c;
            break;
          }
        }
        if (found != null) {
          catId = found.id;
        } else {
          catId = await db.addCategory(p.categoryName);
        }
      }
      await db.insertProduct(p.copyWith(categoryId: catId));
      inserted++;
    }
    if (!mounted) return;
    await context.read<CatalogProvider>().refreshProducts();
    final String msg = result.errors.isEmpty
        ? '$inserted produk berhasil di-import.'
        : '$inserted produk di-import. ${result.errors.length} baris bermasalah:\n${result.errors.take(5).join('\n')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
    );
  }

  Future<void> _deleteDemo() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Hapus Data Demo?'),
        content: const Text(
            'Semua produk contoh (8 produk dari template) akan dihapus. '
            'Produk yang sudah kamu tambah sendiri tidak ikut terhapus.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    final int n = await DatabaseHelper.instance.deleteDemoProducts();
    if (!mounted) return;
    await context.read<CatalogProvider>().refreshProducts();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$n produk demo dihapus')),
    );
  }

  Future<void> _addCategory() async {
    final TextEditingController ctrl = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Kategori Baru'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Nama kategori',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await DatabaseHelper.instance.addCategory(name);
    if (!mounted) return;
    await context.read<CatalogProvider>().loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final CatalogProvider catalog = context.watch<CatalogProvider>();
    final AuthProvider auth = context.watch<AuthProvider>();
    final List<Product> products = _filtered(catalog.products);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari produk...',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _query = ''),
                    ),
            ),
            onChanged: (String v) => setState(() => _query = v),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: const Text('Semua'),
                  selected: _categoryId == null,
                  onSelected: (_) => setState(() => _categoryId = null),
                ),
              ),
              ...catalog.categories.map((Category c) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c.name),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Kategori'),
                  onPressed: _addCategory,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2,
                  message: 'Belum ada produk',
                  hint: 'Tambah produk baru atau import dari CSV.',
                )
              : ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (BuildContext ctx, int i) {
                    final Product p = products[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.isLowStock
                              ? Colors.orange.shade100
                              : Colors.teal.shade50,
                          child: Icon(
                            p.isService
                                ? Icons.miscellaneous_services
                                : Icons.inventory_2,
                            color: p.isLowStock
                                ? Colors.orange
                                : Colors.teal,
                          ),
                        ),
                        title: Text(p.name),
                        subtitle: Text(
                          '${p.categoryName.isEmpty ? 'Tanpa kategori' : p.categoryName}'
                          ' • ${p.sku.isEmpty ? '-' : p.sku}'
                          '${p.isDemo ? ' • DEMO' : ''}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(rp(p.priceSell),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              p.isService
                                  ? 'Jasa'
                                  : 'Stok: ${p.stock} ${p.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                color: p.isLowStock
                                    ? Colors.orange
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openForm(p),
                        onLongPress: auth.canDeleteProduct
                            ? () => _deleteProduct(p)
                            : null,
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import CSV'),
                  onPressed: _importCsv,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export CSV'),
                  onPressed: _exportCsv,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Produk'),
                  onPressed: () => _openForm(),
                ),
              ),
            ],
          ),
        ),
        if (auth.isOwner)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _deleteDemo,
                child: const Text('Hapus semua produk demo'),
              ),
            ),
          ),
      ],
    );
  }
}
