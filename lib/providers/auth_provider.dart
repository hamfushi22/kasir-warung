import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/app_user.dart';

/// Pengguna yang sedang login (PIN).
/// Aturan peran MVP:
/// - Owner: semua akses (laporan penuh, ubah harga, pengaturan, pengguna).
/// - Kasir: jualan + stok + kas; TIDAK bisa ubah harga, TIDAK bisa lihat
///   laporan penuh (hanya penjualan dirinya hari ini), TIDAK bisa buka
///   Pengaturan.
class AuthProvider extends ChangeNotifier {
  AppUser? _user;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isOwner => _user?.isOwner ?? false;
  bool get isKasir => _user?.isKasir ?? false;
  String get userName => _user?.name ?? '';
  int? get userId => _user?.id;

  bool get canViewFullReports => isOwner;
  bool get canEditPrice => isOwner;
  bool get canDeleteProduct => isOwner;
  bool get canOpenSettings => isOwner;
  bool get canManageUsers => isOwner;

  /// Login dengan PIN. Mengembalikan true bila PIN cocok.
  Future<bool> login(String pin) async {
    final AppUser? u =
        await DatabaseHelper.instance.findUserByPin(pin.trim());
    if (u == null) return false;
    _user = u;
    notifyListeners();
    return true;
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}
