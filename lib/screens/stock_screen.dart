import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/stock_movement.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../services/money.dart';
import '../widgets/empty_state.dart';

/// Stok: daftar stok + penyesuaian (masuk/keluar/opname) + riwayat pergerakan.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _query = '';
  List<StockMovement> _history = <StockMovement>[];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final List<StockMovement> h =
        await DatabaseHelper.instance.getRecentStockMovements(limit: 100);
    if (!mounted) return;
    setState(() {
      _history = h;
      _historyLoading = false;
    });
  }

  Future<void> _adjustDialog(Product p, String mode) async {
    // mode: 'in' (masuk), 'out' (keluar), 'set' (opname -> stok absolut).
    final TextEditingController qtyCtrl = TextEditingController();
    final TextEditingController noteCtrl = TextEditingController();
    final String title = mode == 'in'
        ? 'Stok Masuk — ${p.name}'
        : mode == 'out'
            ? 'Stok Keluar — ${p.name}'
            : 'Opname — ${p.name}';
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Stok saat ini: ${p.stock} ${p.unit}'),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: mode == 'set'
                      ? 'Stok fisik hasil hitung'
                      : 'Jumlah',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan (mis. beli dari supplier / rusak)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Simpan')),
          ],
        );
      },
    );
    if (ok != true) return;
    final int qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0 && mode != 'set') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah harus lebih dari 0')),
      );
      return;
    }
    final AuthProvider auth = context.read<AuthProvider>();
    final DatabaseHelper db = DatabaseHelper.instance;
    final String note = noteCtrl.text.trim();
    if (mode == 'set') {
      await db.setStockAbsolute(
        productId: p.id!,
        newStock: qty,
        note: note.isEmpty ? 'Opname stok' : note,
        userId: auth.userId,
      );
    } else {
      await db.recordStockChange(
        productId: p.id!,
        qtyDelta: mode == 'in' ? qty : -qty,
        type: mode,
        note: note,
        userId: auth.userId,
      );
    }
    await db.logActivity(auth.userId, auth.userName, 'Ubah stok',
        '${p.name}: $mode $qty');
    if (!mounted) return;
    await context.read<CatalogProvider>().refreshProducts();
    await _loadHistory();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stok diperbarui')),
    );
  }

  Future<void> _showHistory(Product p) async {
    final List<StockMovement> moves =
        await DatabaseHelper.instance.getStockMovements(p.id!);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Riwayat — ${p.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: moves.isEmpty
                ? const Text('Belum ada pergerakan stok.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: moves.length,
                    itemBuilder: (BuildContext c, int i) {
                      final StockMovement m = moves[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                            '${StockMovement.typeLabel(m.type)} ${m.qty > 0 ? '+' : ''}${m.qty}'),
                        subtitle: Text(
                            '${m.note.isEmpty ? '-' : m.note}\n${formatDateTime(m.createdAt)}'),
                      );
                    },
                  ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> all = context.watch<CatalogProvider>().products;
    final String q = _query.trim().toLowerCase();
    final List<Product> products = all.where((Product p) {
      if (p.isService) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok'),
        bottom: TabBar(
          controller: _tab,
          tabs: const <Tab>[
            Tab(text: 'Daftar Stok'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: <Widget>[
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari produk...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (String v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2,
                        message: 'Tidak ada produk stok',
                      )
                    : ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (BuildContext ctx, int i) {
                          final Product p = products[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: ListTile(
                              title: Text(p.name),
                              subtitle: Text(
                                'Stok: ${p.stock} ${p.unit} • Min: ${p.stockMinimum}',
                                style: TextStyle(
                                  color: p.isLowStock
                                      ? Colors.orange
                                      : null,
                                  fontWeight: p.isLowStock
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  IconButton(
                                    tooltip: 'Stok masuk',
                                    icon: const Icon(Icons.add_circle,
                                        color: Colors.green),
                                    onPressed: () =>
                                        _adjustDialog(p, 'in'),
                                  ),
                                  IconButton(
                                    tooltip: 'Stok keluar',
                                    icon: const Icon(Icons.remove_circle,
                                        color: Colors.red),
                                    onPressed: () =>
                                        _adjustDialog(p, 'out'),
                                  ),
                                  IconButton(
                                    tooltip: 'Opname (hitung fisik)',
                                    icon: const Icon(Icons.fact_check),
                                    onPressed: () =>
                                        _adjustDialog(p, 'set'),
                                  ),
                                ],
                              ),
                              onTap: () => _showHistory(p),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          _historyLoading
              ? const Center(child: CircularProgressIndicator())
              : _history.isEmpty
                  ? const EmptyState(
                      icon: Icons.history,
                      message: 'Belum ada pergerakan stok',
                    )
                  : ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (BuildContext ctx, int i) {
                        final StockMovement m = _history[i];
                        return ListTile(
                          leading: Icon(
                            m.qty >= 0
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color:
                                m.qty >= 0 ? Colors.green : Colors.red,
                          ),
                          title: Text(m.productName),
                          subtitle: Text(
                              '${StockMovement.typeLabel(m.type)}'
                              '${m.note.isEmpty ? '' : ' • ${m.note}'}\n'
                              '${formatDateTime(m.createdAt)}'),
                          trailing: Text(
                            '${m.qty > 0 ? '+' : ''}${m.qty}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
