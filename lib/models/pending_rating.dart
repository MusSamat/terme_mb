/// A trip awaiting the current user's rating (GET /ratings/pending).
/// Mirror of the web `PendingRating` type.
class PendingRating {
  const PendingRating({
    required this.tripId,
    required this.counterpartId,
    required this.counterpartName,
    required this.direction,
    required this.departureAt,
    required this.expiresAt,
  });

  final String tripId;
  final String counterpartId;
  final String counterpartName;
  final String direction; // 'driver' | 'passenger' — who the current user is rating
  final String departureAt;
  final String expiresAt;

  factory PendingRating.fromJson(Map<String, dynamic> j) => PendingRating(
        tripId: (j['tripId'] ?? '') as String,
        counterpartId: (j['counterpartId'] ?? '') as String,
        counterpartName: (j['counterpartName'] ?? '') as String,
        direction: (j['direction'] ?? 'passenger') as String,
        departureAt: (j['departureAt'] ?? '') as String,
        expiresAt: (j['expiresAt'] ?? '') as String,
      );
}
