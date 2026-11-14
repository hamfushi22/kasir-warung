import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/app_settings.dart';
import '../models/sale.dart';
import '../services/money.dart';
import '../widgets/empty_state.dart';
import '../widgets/receipt_dialog.dart';

/// Riwayat transaksi: pencarian, filter tanggal, detail + struk ulang.
class SalesHistoryScreen extends StatefulWidget {
  final bool showAll;

  const SalesHistoryScreen({super.key, this.showAll = true});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  List<Sale> _sales = <Sale>[];
  bool _loading = true;
  String _query = '';
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final List<Sale> sales = await db.getSales(
      query: _query.trim().isEmpty ? null : _query.trim(),
      fromDate: _range == null ? null : DatabaseHelper.dateStr(_range!.start),
      toDate: _range == null ? null : DatabaseHelper.dateStr(_range!.end),
      limit: 200,
    );
    if (!mounted) return;
    setState(() {
      _sales = sales;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _range ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
    );
    if (range != null) {
      setState(() => _range = range);
      await _load();
    }
  }

  Future<void> _openDetail(Sale s) async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final List<SaleItem> items = await db.getSaleItems(s.id!);
    final List<Payment> payments = await db.getSalePayments(s.id!);
    final AppSettings settings = await db.loadSettings();
    if (!mounted) return;
    await showReceiptDialog(
      context,
      settings: settings,
      sale: s,
      items: items,
      payments: payments,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari nomor struk / nama pelanggan...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _query = '');
                              _load();
                            },
                          ),
                  ),
                  onChanged: (String v) => setState(() => _query = v),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Filter tanggal',
                icon: Icon(Icons.date_range,
                    color: _range != null ? Colors.teal : null),
                onPressed: _pickRange,
              ),
            ],
          ),
        ),
        Expanded(
          child: _sales.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long,
                  message: 'Belum ada transaksi',
                  hint: 'Coba ubah pencarian atau filter tanggal.',
                )
              : ListView.builder(
                  itemCount: _sales.length,
                  itemBuilder: (BuildContext ctx, int i) {
                    final Sale s = _sales[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        title: Text(s.invoiceNo),
                        subtitle: Text(
                          '${formatDateTime(s.createdAt)}'
                          '${s.customerName.isNotEmpty ? ' • ${s.customerName}' : ''}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text(rp(s.grandTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                              s.status == 'credit' ? 'KASBON' : s.status,
                              style: TextStyle(
                                fontSize: 11,
                                color: s.status == 'credit'
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _openDetail(s),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
