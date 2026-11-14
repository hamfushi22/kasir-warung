import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import 'cash_screen.dart';
import 'customers_screen.dart';
import 'reports_screen.dart';
import 'sales_history_screen.dart';
import 'settings_screen.dart';
import 'stock_screen.dart';

/// Menu "Lainnya": semua fitur di luar Kasir/Produk/Dashboard,
/// sebagai tab terpisah agar home tetap ringkas.
class OtherMenuScreen extends StatelessWidget {
  const OtherMenuScreen({super.key});

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => page),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final bool isOwner = auth.isOwner;

    return ListView(
      children: <Widget>[
        const SizedBox(height: 8),
        _tile(
            context,
            icon: Icons.inventory_2,
            title: 'Stok',
            subtitle: 'Stok masuk/keluar, opname, riwayat pergerakan',
            page: const StockScreen(),
          ),
          _tile(
            context,
            icon: Icons.receipt_long,
            title: 'Riwayat Transaksi',
            subtitle: 'Semua penjualan, cari & lihat struk ulang',
            page: const SalesHistoryScreen(),
          ),
          _tile(
            context,
            icon: Icons.point_of_sale,
            title: 'Kas & Shift',
            subtitle: 'Kas awal/akhir, tutup kasir, pemasukan/pengeluaran',
            page: const CashScreen(),
          ),
          _tile(
            context,
            icon: Icons.people,
            title: 'Pelanggan & Kasbon',
            subtitle: 'Data pelanggan dan piutang',
            page: const CustomersScreen(),
          ),
          _tile(
            context,
            icon: Icons.bar_chart,
            title: 'Laporan',
            subtitle: isOwner
                ? 'Penjualan, laba/rugi, per produk & metode bayar'
                : 'Penjualan saya hari ini (laporan penuh hanya Owner)',
            page: ReportsScreen(fullAccess: isOwner),
          ),
          _tile(
            context,
            icon: Icons.settings,
            title: 'Pengaturan',
            subtitle: 'Profil toko, pajak, struk, pengguna',
            page: const SettingsScreen(),
          ),
          _tile(
            context,
            icon: Icons.history,
            title: 'Log Aktivitas',
            subtitle: 'Catatan aktivitas pengguna aplikasi',
            page: const ActivityLogScreen(),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.logout)),
            title: const Text('Keluar (ganti pengguna)'),
            subtitle: Text('Masuk sebagai ${auth.userName}'),
            onTap: () {
              auth.logout();
            },
          ),
        ],
      );
  }
}

/// Log aktivitas sederhana (login, tambah/ubah produk, ubah stok, buka/tutup shift).
class ActivityLogScreen extends StatelessWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log Aktivitas')),
      body: FutureBuilder<List<ActivityLog>>(
        future: DatabaseHelper.instance.getActivityLogs(limit: 200),
        builder: (BuildContext ctx, AsyncSnapshot<List<ActivityLog>> snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<ActivityLog> logs = snap.data!;
          if (logs.isEmpty) {
            return const Center(child: Text('Belum ada aktivitas tercatat.'));
          }
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (BuildContext c, int i) {
              final ActivityLog l = logs[i];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text('${l.userName} — ${l.action}'),
                subtitle: Text(
                  '${l.detail.isEmpty ? '-' : l.detail}\n${l.createdAt}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
