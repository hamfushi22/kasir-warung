import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/cash.dart';
import '../models/customer.dart';
import '../providers/auth_provider.dart';
import '../services/money.dart';
import '../widgets/empty_state.dart';

/// Daftar pelanggan + piutang (kasbon) per pelanggan.
///
/// Piutang disimpan sebagai [Receivable] per transaksi kasbon
/// (satu pelanggan bisa punya beberapa piutang terbuka).
/// Pembayaran dicatat per piutang lewat [DatabaseHelper.payReceivable].
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _customers = <Customer>[];
  List<Receivable> _openReceivables = <Receivable>[];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final List<Customer> customers = await db.getCustomers();
    final List<Receivable> receivables =
        await db.getReceivables(openOnly: true);
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _openReceivables = receivables;
      _loading = false;
    });
  }

  /// Total sisa piutang terbuka untuk satu pelanggan.
  int _debtOf(Customer c) {
    int total = 0;
    for (final Receivable r in _openReceivables) {
      final bool sameCustomer = (r.customerId != null && r.customerId == c.id) ||
          (r.customerId == null && r.customerName == c.name);
      if (sameCustomer) total += r.remaining;
    }
    return total;
  }

  List<Receivable> _receivablesOf(Customer c) {
    return _openReceivables.where((Receivable r) {
      return (r.customerId != null && r.customerId == c.id) ||
          (r.customerId == null && r.customerName == c.name);
    }).toList();
  }

  Future<void> _addCustomer() async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController addrCtrl = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Pelanggan Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'No. HP',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alamat',
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
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    await DatabaseHelper.instance.addCustomer(
      Customer(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: addrCtrl.text.trim(),
      ),
    );
    await _load();
  }

  Future<void> _showCustomerDebt(Customer c) async {
    final List<Receivable> list = _receivablesOf(c);
    if (list.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Piutang — ${c.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: list.length,
              itemBuilder: (BuildContext c2, int i) {
                final Receivable r = list[i];
                return ListTile(
                  dense: true,
                  title: Text(r.invoiceNo.isEmpty ? 'Kasbon' : r.invoiceNo),
                  subtitle: Text(
                      'Total ${rp(r.total)} • Dibayar ${rp(r.paid)}\n'
                      '${formatDateTime(r.createdAt)}'),
                  trailing: Text(rp(r.remaining),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _payReceivable(r);
                  },
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

  Future<void> _payReceivable(Receivable r) async {
    final TextEditingController ctrl = TextEditingController();
    final int? amount = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Bayar Piutang — ${r.customerName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Struk: ${r.invoiceNo.isEmpty ? '-' : r.invoiceNo}'),
              Text('Sisa piutang: ${rp(r.remaining)}'),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah dibayar (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(parseRupiah(ctrl.text)),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (amount == null || amount <= 0 || r.id == null) return;
    final int pay = amount > r.remaining ? r.remaining : amount;
    final AuthProvider auth = context.read<AuthProvider>();
    // Bila ada shift berjalan, pelunasan tercatat juga sebagai pemasukan kas.
    final CashSession? session =
        await DatabaseHelper.instance.getOpenSession();
    await DatabaseHelper.instance.payReceivable(
      receivableId: r.id!,
      amount: pay,
      userId: auth.userId,
      userName: auth.userName,
      sessionId: session?.id,
    );
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pembayaran piutang ${rp(pay)} dicatat')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final String q = _query.trim().toLowerCase();
    final List<Customer> list = _customers.where((Customer c) {
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q);
    }).toList();
    final int totalDebt = _openReceivables.fold<int>(
        0, (int s, Receivable r) => s + r.remaining);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text('Total Piutang (Kasbon)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(rp(totalDebt),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Cari pelanggan...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (String v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(
                  icon: Icons.people,
                  message: 'Belum ada pelanggan',
                  hint: 'Pelanggan baru bisa ditambah di sini, '
                      'atau otomatis tercatat saat transaksi kasbon.',
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (BuildContext ctx, int i) {
                    final Customer c = list[i];
                    final int debt = _debtOf(c);
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Text(c.name.isEmpty ? '?' : c.name[0])),
                        title: Text(c.name),
                        subtitle: Text(
                            c.phone.isEmpty ? 'Tanpa nomor HP' : c.phone),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            const Text('Piutang',
                                style: TextStyle(fontSize: 11)),
                            Text(
                              rp(debt),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: debt > 0 ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        onTap: debt > 0 ? () => _showCustomerDebt(c) : null,
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Tambah Pelanggan'),
              onPressed: _addCustomer,
            ),
          ),
        ),
      ],
    );
  }
}
