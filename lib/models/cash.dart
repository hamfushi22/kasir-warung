/// Satu shift kasir: dibuka dengan kas awal, ditutup dengan kas akhir.
/// status: 'open' atau 'closed'.
class CashSession {
  final int? id;
  final int? userId;
  final String userName;
  final String openedAt;
  final String? closedAt;
  final int openingCash;
  final int? closingCash;
  final int? expectedCash;
  final int? difference; // closing - expected (negatif = kurang)
  final String status;

  const CashSession({
    this.id,
    this.userId,
    this.userName = '',
    required this.openedAt,
    this.closedAt,
    required this.openingCash,
    this.closingCash,
    this.expectedCash,
    this.difference,
    this.status = 'open',
  });

  factory CashSession.fromMap(Map<String, dynamic> m) {
    return CashSession(
      id: m['id'] as int?,
      userId: m['user_id'] as int?,
      userName: m['user_name'] as String? ?? '',
      openedAt: m['opened_at'] as String? ?? '',
      closedAt: m['closed_at'] as String?,
      openingCash: (m['opening_cash'] as num?)?.toInt() ?? 0,
      closingCash: (m['closing_cash'] as num?)?.toInt(),
      expectedCash: (m['expected_cash'] as num?)?.toInt(),
      difference: (m['difference'] as num?)?.toInt(),
      status: m['status'] as String? ?? 'open',
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'user_id': userId,
      'user_name': userName,
      'opened_at': openedAt,
      'closed_at': closedAt,
      'opening_cash': openingCash,
      'closing_cash': closingCash,
      'expected_cash': expectedCash,
      'difference': difference,
      'status': status,
    };
  }

  bool get isOpen => status == 'open';
}

/// Pemasukan / pengeluaran lain di luar penjualan.
/// type: 'in' (pemasukan, mis. pelunasan kasbon) atau 'out' (pengeluaran, mis. listrik).
class CashMovement {
  final int? id;
  final int? sessionId;
  final String type;
  final int amount;
  final String note;
  final String createdAt;
  final String createdDate;
  final int? userId;

  const CashMovement({
    this.id,
    this.sessionId,
    required this.type,
    required this.amount,
    this.note = '',
    required this.createdAt,
    required this.createdDate,
    this.userId,
  });

  factory CashMovement.fromMap(Map<String, dynamic> m) {
    return CashMovement(
      id: m['id'] as int?,
      sessionId: m['session_id'] as int?,
      type: m['type'] as String? ?? 'out',
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      note: m['note'] as String? ?? '',
      createdAt: m['created_at'] as String? ?? '',
      createdDate: m['created_date'] as String? ?? '',
      userId: m['user_id'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'session_id': sessionId,
      'type': type,
      'amount': amount,
      'note': note,
      'created_at': createdAt,
      'created_date': createdDate,
      'user_id': userId,
    };
  }
}
