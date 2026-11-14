import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db/database_helper.dart';
import '../models/app_settings.dart';
import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../services/sync_service.dart';

/// Pengaturan: profil toko, pajak, struk, pengguna (Owner), sinkronisasi.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  late TextEditingController _storeNameCtrl;
  late TextEditingController _storeAddressCtrl;
  late TextEditingController _storePhoneCtrl;
  late TextEditingController _headerCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _taxRateCtrl;
  bool _taxEnabled = false;

  @override
  void initState() {
    super.initState();
    _storeNameCtrl = TextEditingController();
    _storeAddressCtrl = TextEditingController();
    _storePhoneCtrl = TextEditingController();
    _headerCtrl = TextEditingController();
    _footerCtrl = TextEditingController();
    _taxRateCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _storeNameCtrl.dispose();
    _storeAddressCtrl.dispose();
    _storePhoneCtrl.dispose();
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppSettings s = await DatabaseHelper.instance.loadSettings();
    if (!mounted) return;
    setState(() {
      _storeNameCtrl.text = s.storeName;
      _storeAddressCtrl.text = s.storeAddress;
      _storePhoneCtrl.text = s.storePhone;
      _headerCtrl.text = s.receiptHeader;
      _footerCtrl.text = s.receiptFooter;
      _taxEnabled = s.taxEnabled;
      _taxRateCtrl.text = s.taxRate.toString();
      _loading = false;
    });
  }

  Future<void> _save() async {
    final AppSettings s = AppSettings(
      storeName: _storeNameCtrl.text.trim().isEmpty
          ? 'Kasir Warung'
          : _storeNameCtrl.text.trim(),
      storeAddress: _storeAddressCtrl.text.trim(),
      storePhone: _storePhoneCtrl.text.trim(),
      taxEnabled: _taxEnabled,
      taxRate: int.tryParse(_taxRateCtrl.text.trim()) ?? 10,
      receiptHeader: _headerCtrl.text,
      receiptFooter: _footerCtrl.text,
    );
    await DatabaseHelper.instance.saveSettings(s);
    if (!mounted) return;
    // Segarkan pengaturan yang dipakai layar Kasir/Dashboard.
    await context.read<CatalogProvider>().refreshSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengaturan disimpan')),
    );
  }

  Future<void> _changePin(AppUser user) async {
    final TextEditingController pinCtrl = TextEditingController();
    final String? pin = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text('Ubah PIN — ${user.name}'),
          content: TextField(
            controller: pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'PIN baru (4–6 digit)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal')),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(pinCtrl.text.trim()),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
    if (pin == null || pin.length < 4 || user.id == null) return;
    await DatabaseHelper.instance.updateUserPin(user.id!, pin);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PIN ${user.name} diubah')),
    );
  }

  Future<void> _addUser() async {
    final TextEditingController nameCtrl = TextEditingController();
    final TextEditingController pinCtrl = TextEditingController();
    String role = 'kasir';
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext c, StateSetter setState) {
            return AlertDialog(
              title: const Text('Pengguna Baru'),
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
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'PIN (4–6 digit) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: role,
                    decoration: const InputDecoration(
                      labelText: 'Peran',
                      border: OutlineInputBorder(),
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'kasir', child: Text('Kasir')),
                      DropdownMenuItem(value: 'owner', child: Text('Owner')),
                    ],
                    onChanged: (String? v) =>
                        setState(() => role = v ?? 'kasir'),
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
      },
    );
    if (ok != true ||
        nameCtrl.text.trim().isEmpty ||
        pinCtrl.text.trim().length < 4) {
      return;
    }
    await DatabaseHelper.instance.addUser(AppUser(
      name: nameCtrl.text.trim(),
      role: role,
      pin: pinCtrl.text.trim(),
    ));
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengguna ditambahkan')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final AuthProvider auth = context.watch<AuthProvider>();
    final bool isOwner = auth.isOwner;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text('Profil Toko',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _storeNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nama toko',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _storeAddressCtrl,
          decoration: const InputDecoration(
            labelText: 'Alamat',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _storePhoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'No. telepon',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Pajak',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SwitchListTile(
          title: const Text('Aktifkan pajak'),
          subtitle: Text(_taxEnabled
              ? 'Pajak ${_taxRateCtrl.text}% ditambahkan ke total transaksi'
              : 'Pajak nonaktif — harga sudah termasuk pajak'),
          value: _taxEnabled,
          onChanged: (bool v) => setState(() => _taxEnabled = v),
        ),
        if (_taxEnabled)
          TextField(
            controller: _taxRateCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tarif pajak (%)',
              border: OutlineInputBorder(),
            ),
          ),
        const SizedBox(height: 20),
        const Text('Struk',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _headerCtrl,
          decoration: const InputDecoration(
            labelText: 'Header struk (mis. ucapan pembuka)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _footerCtrl,
          decoration: const InputDecoration(
            labelText: 'Footer struk (mis. ucapan terima kasih)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Sinkronisasi',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'Sinkronisasi ke server (VPS) masih dinonaktifkan secara default. '
          'Backend belum ada — aktifkan hanya setelah server API siap.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        FutureBuilder<int>(
          future: SyncService.pendingCount(),
          builder: (BuildContext ctx, AsyncSnapshot<int> snap) {
            return ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('Status sinkronisasi'),
              subtitle: Text(
                'Nonaktif • ${snap.data ?? 0} perubahan menunggu '
                'di antrean lokal',
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        if (isOwner) ...<Widget>[
          const Text('Pengguna',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FutureBuilder<List<AppUser>>(
            future: DatabaseHelper.instance.getUsers(),
            builder:
                (BuildContext ctx, AsyncSnapshot<List<AppUser>> snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: snap.data!.map((AppUser u) {
                  return ListTile(
                    leading: CircleAvatar(
                        child: Text(u.name.isEmpty ? '?' : u.name[0])),
                    title: Text(u.name),
                    subtitle: Text(u.role == 'owner' ? 'Owner' : 'Kasir'),
                    trailing: TextButton(
                      onPressed: () => _changePin(u),
                      child: const Text('Ubah PIN'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Tambah Pengguna'),
            onPressed: _addUser,
          ),
          const SizedBox(height: 20),
        ],
        FilledButton(
          onPressed: _save,
          child: const Text('Simpan Pengaturan'),
        ),
      ],
    );
  }
}
