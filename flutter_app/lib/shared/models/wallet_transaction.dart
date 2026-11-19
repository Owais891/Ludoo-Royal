/// A wallet transaction (credit or debit, coin or gem).
class WalletTransaction {
  final int id;
  final String type;     // credit | debit
  final String currency; // coin | gem
  final int amount;
  final int balanceAfter;
  final String reason;
  final String? referenceId;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.type,
    required this.currency,
    required this.amount,
    required this.balanceAfter,
    required this.reason,
    this.referenceId,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> j) => WalletTransaction(
    id: (j['id'] as num).toInt(),
    type: j['type'] as String? ?? 'credit',
    currency: j['currency'] as String? ?? 'coin',
    amount: (j['amount'] as num).toInt(),
    balanceAfter: (j['balance_after'] as num).toInt(),
    reason: j['reason'] as String? ?? '',
    referenceId: j['reference_id'] as String?,
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  );
}
