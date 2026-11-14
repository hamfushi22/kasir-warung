import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../services/money.dart';

const List<String> _units = <String>[
  'pcs',
  'kg',
  'dus',
  'sachet',
  'liter',
  'pack',
  'botol',
];

/// Form tambah / edit produk.
class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _skuCtrl;
  late TextEditingController _barcodeCtrl;
  late TextEditingController _buyCtrl;
  late TextEditingController _sellCtrl;
  late TextEditingController _wholesaleCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _minCtrl;
  String _unit = 'pcs';
  int? _categoryId;
  bool _isService = false;

  @override
  void initState() {
    super.initState();
    final Product? p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _buyCtrl = TextEditingController(
        text: p == null ? '' : p.priceBuy.toString());
    _sellCtrl = TextEditingController(
        text: p == null ? '' : p.priceSell.toString());
    _wholesaleCtrl = TextEditingController(
        text: p?.priceWholesale?.toString() ?? '');
    _stockCtrl =
        TextEditingController(text: p == null ? '0' : p.stock.toString());
    _minCtrl =
        TextEditingController(text: p == null ? '0' : p.stockMinimum.toString());
    _unit = p?.unit ?? 'pcs';
    _categoryId = p?.categoryId;
    _isService = p?.isService ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _barcodeCtrl.dispose();
    _buyCtrl.dispose();
    _sellCtrl.dispose();
    _wholesaleCtrl.dispose();
    _stockCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final CatalogProvider catalog = context.read<CatalogProvider>();
    String categoryName = '';
    if (_categoryId != null) {
      for (final Category c in catalog.categories) {
        if (c.id == _categoryId) categoryName = c.name;
      }
    }
    final Product product = Product(
      id: widget.product?.id,
      name: _nameCtrl.text.trim(),
      sku: _skuCtrl.text.trim(),
      barcode: _barcodeCtrl.text.trim(),
      categoryId: _categoryId,
      categoryName: categoryName,
      unit: _unit,
      priceBuy: parseRupiah(_buyCtrl.text),
      priceSell: parseRupiah(_sellCtrl.text),
      priceWholesale: _wholesaleCtrl.text.trim().isEmpty
          ? null
          : parseRupiah(_wholesaleCtrl.text),
      stock: int.tryParse(_stockCtrl.text.trim()) ?? 0,
      stockMinimum: int.tryParse(_minCtrl.text.trim()) ?? 0,
      isService: _isService,
      isActive: true,
      isDemo: widget.product?.isDemo ?? false,
    );
    final DatabaseHelper db = DatabaseHelper.instance;
    if (product.id == null) {
      await db.insertProduct(product);
    } else {
      await db.updateProduct(product);
    }
    await db.logActivity(
      context.read<AuthProvider>().userId,
      context.read<AuthProvider>().userName,
      widget.product == null ? 'Tambah produk' : 'Ubah produk',
      product.name,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final CatalogProvider catalog = context.watch<CatalogProvider>();
    final bool canEditPrice =
        context.watch<AuthProvider>().canEditPrice;
    final bool isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(
          title: Text(isEdit ? 'Ubah Produk' : 'Produk Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama produk *',
                border: OutlineInputBorder(),
              ),
              validator: (String? v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _skuCtrl,
                    decoration: const InputDecoration(
                      labelText: 'SKU / Kode',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Barcode',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: catalog.categories
                  .map((Category c) => DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(c.name),
                      ))
                  .toList(),
              onChanged: (int? v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _unit,
              decoration: const InputDecoration(
                labelText: 'Satuan',
                border: OutlineInputBorder(),
              ),
              items: _units
                  .map((String u) => DropdownMenuItem<String>(
                        value: u,
                        child: Text(u),
                      ))
                  .toList(),
              onChanged: (String? v) =>
                  setState(() => _unit = v ?? 'pcs'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Produk jasa / non-stok'),
              subtitle: const Text(
                  'Mis. pulsa, token listrik — stok tidak berkurang saat dijual'),
              value: _isService,
              onChanged: (bool v) => setState(() => _isService = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buyCtrl,
              keyboardType: TextInputType.number,
              enabled: canEditPrice,
              decoration: const InputDecoration(
                labelText: 'Harga beli (Rp) *',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
              validator: (String? v) => parseRupiah(v ?? '') < 0
                  ? 'Harga tidak valid'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellCtrl,
              keyboardType: TextInputType.number,
              enabled: canEditPrice,
              decoration: const InputDecoration(
                labelText: 'Harga jual / ecer (Rp) *',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
              validator: (String? v) {
                if (parseRupiah(v ?? '') <= 0) {
                  return 'Harga jual wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _wholesaleCtrl,
              keyboardType: TextInputType.number,
              enabled: canEditPrice,
              decoration: const InputDecoration(
                labelText: 'Harga grosir (Rp, opsional)',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
            ),
            if (!canEditPrice)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Harga hanya bisa diubah oleh Owner.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok saat ini',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Stok minimum',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _save,
              child: Text(isEdit ? 'Simpan Perubahan' : 'Tambah Produk'),
            ),
          ],
        ),
      ),
    );
  }
}
