import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import 'dashboard_screen.dart';
import 'other_menu_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';

/// Shell utama dengan navigasi bawah (5 tab).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 1; // Buka langsung di Kasir (layar yang paling sering dipakai).

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final String storeName =
        context.watch<CatalogProvider>().settings.storeName;

    final List<Widget> pages = <Widget>[
      const DashboardScreen(),
      const PosScreen(),
      const ProductsScreen(),
      ReportsScreen(fullAccess: auth.canViewFullReports),
      const OtherMenuScreen(),
    ];
    const List<String> titles = <String>[
      'Beranda',
      'Kasir',
      'Produk',
      'Laporan',
      'Lainnya',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _index == 0 ? storeName : titles[_index],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              label: Text(auth.userName),
              avatar: Icon(
                auth.isOwner ? Icons.admin_panel_settings : Icons.person,
                size: 18,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (int i) => setState(() => _index = i),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Beranda'),
          BottomNavigationBarItem(
              icon: Icon(Icons.point_of_sale), label: 'Kasir'),
          BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2), label: 'Produk'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Laporan'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Lainnya'),
        ],
      ),
    );
  }
}
