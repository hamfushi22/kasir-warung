/// Pengguna aplikasi. role: 'owner' atau 'kasir'.
class AppUser {
  final int? id;
  final String name;
  final String pin; // PIN 4-6 digit
  final String role;
  final bool active;

  const AppUser({
    this.id,
    required this.name,
    required this.pin,
    required this.role,
    this.active = true,
  });

  factory AppUser.fromMap(Map<String, dynamic> m) {
    return AppUser(
      id: m['id'] as int?,
      name: m['name'] as String? ?? '',
      pin: m['pin'] as String? ?? '',
      role: m['role'] as String? ?? 'kasir',
      active: (m['active'] as num? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'name': name,
      'pin': pin,
      'role': role,
      'active': active ? 1 : 0,
    };
  }

  bool get isOwner => role == 'owner';
  bool get isKasir => role == 'kasir';
}

/// Jejak aktivitas penting (siapa melakukan apa).
class ActivityLog {
  final int? id;
  final int? userId;
  final String userName;
  final String action;
  final String detail;
  final String createdAt;

  const ActivityLog({
    this.id,
    this.userId,
    this.userName = '',
    required this.action,
    this.detail = '',
    required this.createdAt,
  });

  factory ActivityLog.fromMap(Map<String, dynamic> m) {
    return ActivityLog(
      id: m['id'] as int?,
      userId: m['user_id'] as int?,
      userName: m['user_name'] as String? ?? '',
      action: m['action'] as String? ?? '',
      detail: m['detail'] as String? ?? '',
      createdAt: m['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user_id': userId,
      'user_name': userName,
      'action': action,
      'detail': detail,
      'created_at': createdAt,
    };
  }
}
