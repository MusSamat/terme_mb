/// Driver performance summary (GET /drivers/me/stats).
/// Mirror of the web `DriverStats` type.
class DriverStats {
  const DriverStats({
    required this.totalTrips,
    required this.ratingCount,
    required this.cancellations30d,
    this.rating,
  });

  final int totalTrips;
  final double? rating;
  final int ratingCount;
  final int cancellations30d;

  factory DriverStats.fromJson(Map<String, dynamic> j) => DriverStats(
        totalTrips: ((j['totalTrips'] ?? 0) as num).toInt(),
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: ((j['ratingCount'] ?? 0) as num).toInt(),
        cancellations30d: ((j['cancellations30d'] ?? 0) as num).toInt(),
      );
}
