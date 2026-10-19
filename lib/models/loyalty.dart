class LoyaltyTx {
  const LoyaltyTx({required this.points, required this.sourceKey, required this.dateLabel});
  final int points;
  final String sourceKey; // key under loyalty.sources.*
  final String dateLabel;

  factory LoyaltyTx.fromJson(Map<String, dynamic> j) => LoyaltyTx(
        points: (j['points'] ?? 0) as int,
        sourceKey: (j['source'] ?? 'bonus') as String,
        dateLabel: (() {
          // Local dd.MM.yyyy — never the raw ISO string.
          final d = DateTime.tryParse((j['createdAt'] ?? '') as String)?.toLocal();
          if (d == null) return '';
          String two(int v) => v.toString().padLeft(2, '0');
          return '${two(d.day)}.${two(d.month)}.${d.year}';
        })(),
      );
}

class LoyaltyStatus {
  const LoyaltyStatus({
    required this.tier,
    required this.points,
    required this.nextTier,
    required this.pointsToNext,
    required this.transactions,
  });
  final String tier; // key under loyalty.tiers.*
  final int points;
  final String? nextTier;
  final int pointsToNext;
  final List<LoyaltyTx> transactions;

  factory LoyaltyStatus.fromJson(Map<String, dynamic> status, List<dynamic> txs) => LoyaltyStatus(
        tier: (status['tier'] ?? 'novice') as String,
        points: (status['points'] ?? 0) as int,
        nextTier: status['nextTier'] as String?,
        pointsToNext: (status['pointsToNextTier'] ?? 0) as int,
        transactions: txs.map((e) => LoyaltyTx.fromJson((e as Map).cast<String, dynamic>())).toList(),
      );
}
