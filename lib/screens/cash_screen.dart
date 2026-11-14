import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/cash.dart';
import '../providers/auth_provider.dart';
import '../services/money.dart';
import '../widgets/empty_state.dart';

/// Manajemen kas: modal shift, pemasukan/pengeluaran lain, tutup kasir.
///
/// Satu sesi shift dibuka dengan kas awal dan ditutup dengan kas akhir;
/// selisih dihitung otomatis oleh DatabaseHelper.closeSession.
class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  CashSession? _session;
  List<CashMovement> _movements = <CashMovement>[];
  List<CashSession> _pastSessions = <CashSession>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final DatabaseHelper db = DatabaseHelper.instance;
    final CashSession? session = await db.getOpenSession();
    final int? sessionId = session?.id;
    final List<CashMovement> moves = sessionId == null
        ? <CashMovement>[]
        : await db.getSessionMovements(sessionId);
    final List<CashSession> past = await db.getSessions(limit: 10);
    if (!mounted) return;
    setState(() {
      _session = session;
      _movements = moves;
      _pastSessions =
          past.where((CashSession s) => s.status == 'closed').toList();
      _loading = false;
    });
  }

  Future<void> _openSession() async {
    final TextEditingController ctrl = TextEditingController();
    final int? amount = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Buka Shift — Kas Awal'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Modal kas awal (Rp)',
              prefixText: 'Rp ',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(parseRupiah(ctrl.text)),
              child: const Text('Buka Shift'),
            ),
          ],
        );
      },
    );
    if (amount == null) return;
    final AuthProvider auth = context.read<AuthProvider>();
    await DatabaseHelper.instance.openSession(
      userId: auth.userId,
      userName: auth.userName,
      openingCash: amount,
    );
    await DatabaseHelper.instance.logActivity(
        auth.userId, auth.userName, 'Buka shift', 'Modal ${rp(amount)}');
    await _load();
  }

  Future<void> _addMovement(bool isIn) async {
    final TextEditingController amountCtrl = TextEditingController();
    final TextEditingController noteCtrl = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(isIn ? 'Pemasukan Lain' : 'Pengeluaran Lain'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah (Rp)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Keterangan',
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
    final int amount = parseRupiah(amountCtrl.text);
    if (amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jumlah harus lebih dari 0')),
      );
      return;
    }
    await DatabaseHelper.instance.addCashMovement(
      sessionId: _session?.id,
      type: isIn ? 'in' : 'out',
      amount: amount,
      note: noteCtrl.text.trim(),
      userId: context.read<AuthProvider>().userId,
    );
    await _load();
  }

  Future<void> _closeSession() async {
    final CashSession? session = _session;
    if (session == null || session.id == null) return;
    final DatabaseHelper db = DatabaseHelper.instance;
    // Hitung kas yang seharusnya ada, untuk ditampilkan sebelum konfirmasi:
    // kas awal + penjualan tunai sejak shift dibuka + pemasukan − pengeluaran.
    final int cashSales = await db.cashSalesSince(session.openedAt);
    final int inSum = _movements
        .where((CashMovement m) => m.type == 'in')
        .fold<int>(0, (int s, CashMovement m) => s + m.amount);
    final int outSum = _movements
        .where((CashMovement m) => m.type == 'out')
        .fold<int>(0, (int s, CashMovement m) => s + m.amount);
    final int expected = session.openingCash + cashSales + inSum - outSum;

    final TextEditingController ctrl = TextEditingController();
    final int? counted = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Tutup Kasir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Kas awal: ${rp(session.openingCash)}'),
              Text('Penjualan tunai: ${rp(cashSales)}'),
              Text('Pemasukan lain: ${rp(inSum)}'),
              Text('Pengeluaran lain: ${rp(outSum)}'),
              Text('Kas seharusnya ada: ${rp(expected)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Selisih akan tercatat otomatis. Masukkan jumlah uang tunai '
                'yang dihitung di laci.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Uang dihitung (Rp)',
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
              child: const Text('Tutup Shift'),
            ),
          ],
        );
      },
    );
    if (counted == null) return;
    final AuthProvider auth = context.read<AuthProvider>();
    final CashSession closed = await db.closeSession(
      sessionId: session.id!,
      closingCash: counted,
    );
    await db.logActivity(auth.userId, auth.userName, 'Tutup shift',
        'Selisih ${rp(closed.difference ?? 0)}');
    await _load();
    if (!mounted) return;
    final int diff = closed.difference ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          diff == 0
              ? 'Shift ditutup — kas pas.'
              : 'Shift ditutup — selisih ${rp(diff)} '
                  '${diff > 0 ? '(lebih)' : '(kurang)'}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (_session == null)
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Belum ada shift yang dibuka',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                      'Buka shift dengan kas awal agar penjualan tercatat '
                      'dalam laporan per shift.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Buka Shift'),
                    onPressed: _openSession,
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Shift Berjalan',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Dibuka: ${formatDateTime(_session!.openedAt)}'
                      ' oleh ${_session!.userName}'),
                  Text('Kas awal: ${rp(_session!.openingCash)}'),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Pemasukan'),
                          onPressed: () => _addMovement(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.remove),
                          label: const Text('Pengeluaran'),
                          onPressed: () => _addMovement(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.lock),
                      label: const Text('Tutup Kasir'),
                      onPressed: _closeSession,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text('Pemasukan / Pengeluaran Shift Ini',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_movements.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: EmptyState(
                icon: Icons.point_of_sale,
                message: 'Belum ada pemasukan/pengeluaran',
              ),
            ),
          )
        else
          ..._movements.map((CashMovement m) {
            return Card(
              child: ListTile(
                leading: Icon(
                  m.type == 'in' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: m.type == 'in' ? Colors.green : Colors.red,
                ),
                title: Text(m.note.isEmpty ? '-' : m.note),
                subtitle: Text(formatDateTime(m.createdAt)),
                trailing: Text(
                  '${m.type == 'in' ? '+' : '-'}${rp(m.amount)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
        if (_pastSessions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          const Text('Shift Sebelumnya',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._pastSessions.map((CashSession s) {
            final int diff = s.difference ?? 0;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(
                    '${formatDateTime(s.openedAt)} — ${s.userName}'),
                subtitle: Text(
                    'Kas awal ${rp(s.openingCash)} • '
                    'Kas akhir ${rp(s.closingCash ?? 0)}'),
                trailing: Text(
                  diff == 0 ? 'Pas' : rp(diff),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: diff == 0
                        ? Colors.green
                        : (diff > 0 ? Colors.teal : Colors.red),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
