import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/product.dart';
import '../providers/catalog_provider.dart';
import '../services/money.dart';
import '../widgets/bar_chart.dart';
import '../widgets/empty_state.dart';
import 'stock_screen.dart';

/// Dashboard: omzet hari ini, grafik 7 hari, produk terlaris, stok menipis.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  int _todayTotal = 0;
  int _todayCount = 0;
  int _weekProfit = 0;
  List<BarData> _weekBars = <BarData>[];
  List<Map<String, dynamic>> _topProducts = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final DatabaseHelper db = DatabaseHelper.instance;
    final DateTime now = DateTime.now();
    final String today = DatabaseHelper.todayStr();
    final String weekAgo =
        DatabaseHelper.dateStr(now.subtract(const Duration(days: 6)));

    final Map<String, int> summary =
        await db.salesSummary(fromDate: today, toDate: today);
    final int profit = await db.grossProfit(fromDate: weekAgo, toDate: today);
    final List<Map<String, dynamic>> daily =
        await db.dailyTotals(fromDate: weekAgo, toDate: today);
    final List<Map<String, dynamic>> top =
        await db.topProducts(fromDate: weekAgo, toDate: today, limit: 5);

    // Lengkapi hari yang tidak ada transaksi dengan nilai 0.
    final Map<String, int> byDate = <String, int>{};
    for (final Map<String, dynamic> row in daily) {
      byDate[row['date'] as String] =
          (row['total'] as num?)?.toInt() ?? 0;
    }
    final List<BarData> bars = <BarData>[];
    for (int i = 6; i >= 0; i--) {
      final DateTime d = now.subtract(Duration(days: i));
      final String key = DatabaseHelper.dateStr(d);
      bars.add(BarData(label: formatDayShort(key), value: byDate[key] ?? 0));
    }

    if (!mounted) return;
    setState(() {
      _todayTotal = summary['total'] ?? 0;
      _todayCount = summary['count'] ?? 0;
      _weekProfit = profit;
      _weekBars = bars;
      _topProducts = top;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> lowStock =
        context.watch<CatalogProvider>().lowStock;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: StatCard(
                  label: 'Omzet Hari Ini',
                  value: rp(_todayTotal),
                  icon: Icons.attach_money,
                ),
              ),
              Expanded(
                child: StatCard(
                  label: 'Transaksi Hari Ini',
                  value: '$_todayCount',
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: StatCard(
                  label: 'Laba Kotor 7 Hari',
                  value: rp(_weekProfit),
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: StatCard(
                  label: 'Stok Menipis',
                  value: '${lowStock.length} produk',
                  icon: Icons.warning_amber,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Penjualan 7 Hari Terakhir',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SimpleBarChart(data: _weekBars),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Produk Terlaris (7 Hari)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_topProducts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: EmptyState(
                  icon: Icons.inventory_2,
                  message: 'Belum ada penjualan 7 hari terakhir',
                ),
              ),
            )
          else
            Card(
              child: Column(
                children: _topProducts.map((Map<String, dynamic> row) {
                  final String name = row['name'] as String? ?? '';
                  final int qty = (row['qty'] as num?)?.toInt() ?? 0;
                  final int amount = (row['amount'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(name),
                    subtitle: Text('$qty terjual'),
                    trailing: Text(rp(amount),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Peringatan Stok Menipis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (lowStock.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: EmptyState(
                  icon: Icons.check_circle,
                  message: 'Semua stok aman',
                ),
              ),
            )
          else
            Card(
              color: Colors.orange.shade50,
              child: Column(
                children: lowStock.map((Product p) {
                  return ListTile(
                    leading: const Icon(Icons.warning_amber,
                        color: Colors.orange),
                    title: Text(p.name),
                    subtitle: Text(
                        'Stok ${p.stock} ${p.unit} (min. ${p.stockMinimum})'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const StockScreen()),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
