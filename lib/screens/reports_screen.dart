import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/sale.dart';
import '../providers/auth_provider.dart';
import '../services/money.dart';
import '../widgets/bar_chart.dart';
import '../widgets/empty_state.dart';

/// Laporan penjualan. Owner melihat laporan penuh; kasir hanya
/// penjualan dirinya hari ini.
class ReportsScreen extends StatefulWidget {
  final bool fullAccess;

  const ReportsScreen({super.key, required this.fullAccess});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'today'; // today | 7d | 30d | month
  bool _loading = true;

  int _total = 0;
  int _count = 0;
  int _grossProfit = 0;
  int _expenses = 0;
  List<Map<String, dynamic>> _topProducts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _byCategory = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _byPayment = <Map<String, dynamic>>[];
  List<Sale> _ownSales = <Sale>[];

  String get _fromDate {
    final DateTime now = DateTime.now();
    switch (_period) {
      case '7d':
        return DatabaseHelper.dateStr(now.subtract(const Duration(days: 6)));
      case '30d':
        return DatabaseHelper.dateStr(now.subtract(const Duration(days: 29)));
      case 'month':
        return DatabaseHelper.dateStr(DateTime(now.year, now.month, 1));
      case 'today':
      default:
        return DatabaseHelper.todayStr();
    }
  }

  String get _toDate => DatabaseHelper.todayStr();

  String get _periodLabel {
    switch (_period) {
      case '7d':
        return '7 Hari Terakhir';
      case '30d':
        return '30 Hari Terakhir';
      case 'month':
        return 'Bulan Ini';
      case 'today':
      default:
        return 'Hari Ini';
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final DatabaseHelper db = DatabaseHelper.instance;
    final AuthProvider auth = context.read<AuthProvider>();
    final String from = _fromDate;
    final String to = _toDate;

    if (!widget.fullAccess) {
      final List<Sale> sales = await db.getSales(
        fromDate: from,
        toDate: to,
        cashierId: auth.userId,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _ownSales = sales;
        _loading = false;
      });
      return;
    }

    final Map<String, int> summary =
        await db.salesSummary(fromDate: from, toDate: to);
    final int profit = await db.grossProfit(fromDate: from, toDate: to);
    final List<Map<String, dynamic>> expRows = await (await db.database)
        .rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM cash_movements '
      "WHERE type = 'out' AND created_date BETWEEN ? AND ?",
      <String>[from, to],
    );
    final List<Map<String, dynamic>> top =
        await db.topProducts(fromDate: from, toDate: to, limit: 5);
    final List<Map<String, dynamic>> byCat =
        await db.salesByCategory(fromDate: from, toDate: to);
    final List<Map<String, dynamic>> byPay =
        await db.salesByPayment(fromDate: from, toDate: to);

    if (!mounted) return;
    setState(() {
      _total = summary['total'] ?? 0;
      _count = summary['count'] ?? 0;
      _grossProfit = profit;
      _expenses = (expRows.first['total'] as num?)?.toInt() ?? 0;
      _topProducts = top;
      _byCategory = byCat;
      _byPayment = byPay;
      _loading = false;
    });
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(t,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Kasir: hanya penjualan sendiri hari ini.
    if (!widget.fullAccess) {
      return Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Penjualan saya hari ini (laporan penuh hanya untuk Owner).',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: _ownSales.isEmpty
                ? const EmptyState(
                    icon: Icons.receipt_long,
                    message: 'Belum ada penjualan hari ini',
                  )
                : ListView.builder(
                    itemCount: _ownSales.length,
                    itemBuilder: (BuildContext ctx, int i) {
                      final Sale s = _ownSales[i];
                      return ListTile(
                        title: Text(s.invoiceNo),
                        subtitle: Text(formatDateTime(s.createdAt)),
                        trailing: Text(rp(s.grandTotal),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    final int netProfit = _grossProfit - _expenses;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final MapEntry<String, String> e in <String, String>{
                'today': 'Hari Ini',
                '7d': '7 Hari',
                '30d': '30 Hari',
                'month': 'Bulan Ini',
              }.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _period == e.key,
                  onSelected: (_) {
                    setState(() => _period = e.key);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Periode: $_periodLabel',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: StatCard(
                  label: 'Omzet',
                  value: rp(_total),
                  icon: Icons.attach_money,
                ),
              ),
              Expanded(
                child: StatCard(
                  label: 'Transaksi',
                  value: '$_count',
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
                  label: 'Laba Kotor',
                  value: rp(_grossProfit),
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: StatCard(
                  label: 'Biaya Operasional',
                  value: rp(_expenses),
                  icon: Icons.money_off,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          StatCard(
            label: 'Laba Bersih (laba kotor − biaya)',
            value: rp(netProfit),
            icon: Icons.account_balance_wallet,
            color: netProfit >= 0 ? Colors.teal : Colors.red,
          ),
          _sectionTitle('Produk Terlaris'),
          if (_topProducts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: EmptyState(
                  icon: Icons.inventory_2,
                  message: 'Belum ada penjualan pada periode ini',
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
                    title: Text(name),
                    subtitle: Text('$qty terjual'),
                    trailing: Text(rp(amount),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),
          _sectionTitle('Penjualan per Kategori'),
          if (_byCategory.isEmpty)
            const Text('Belum ada data.',
                style: TextStyle(color: Colors.grey))
          else
            Card(
              child: Column(
                children: _byCategory.map((Map<String, dynamic> row) {
                  final String name = (row['name'] as String? ?? '').isEmpty
                      ? 'Tanpa kategori'
                      : row['name'] as String;
                  final int amount = (row['amount'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    title: Text(name),
                    trailing: Text(rp(amount),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),
          _sectionTitle('Penjualan per Metode Bayar'),
          if (_byPayment.isEmpty)
            const Text('Belum ada data.',
                style: TextStyle(color: Colors.grey))
          else
            Card(
              child: Column(
                children: _byPayment.map((Map<String, dynamic> row) {
                  final String method = row['method'] as String? ?? '';
                  final int amount = (row['amount'] as num?)?.toInt() ?? 0;
                  final int cnt = (row['cnt'] as num?)?.toInt() ?? 0;
                  return ListTile(
                    title: Text(Payment.methodLabel(method)),
                    subtitle: Text('$cnt transaksi'),
                    trailing: Text(rp(amount),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
