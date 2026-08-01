/// Lean passenger-request model — mirror of tappjet_ft PassengerRequest card.
/// Hand-written for the mock phase; freezed model lands in ТЗ step 2.
class PassengerRequestItem {
  const PassengerRequestItem({
    required this.id,
    required this.originCity,
    required this.destinationCity,
    required this.seatsNeeded,
    required this.dateLabel,
    required this.budget,
    required this.passengerName,
    this.passengerRating,
    this.passengerRatingCount = 0,
    this.passengerVerified = false,
    this.comment,
    this.status = 'open',
    this.liked = false,
    this.responded = false,
  });

  final String id;
  final String originCity;
  final String destinationCity;
  final int seatsNeeded;
  final String dateLabel;
  final int budget;
  final String passengerName;
  final double? passengerRating;
  final int passengerRatingCount;
  final bool passengerVerified;
  final String? comment;
  final String status; // open | closed
  final bool liked;
  final bool responded;

  factory PassengerRequestItem.fromJson(Map<String, dynamic> j) {
    final p = (j['passenger'] as Map?)?.cast<String, dynamic>() ?? const {};
    final date = j['departureDate'] != null ? DateTime.tryParse(j['departureDate'] as String) : null;
    final dateLabel = date != null
        ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}'
        : (j['dateLabel'] ?? '') as String;
    return PassengerRequestItem(
      id: j['id'] as String,
      originCity: (j['originCity'] ?? '') as String,
      destinationCity: (j['destinationCity'] ?? '') as String,
      seatsNeeded: (j['seatsNeeded'] ?? 1) as int,
      dateLabel: dateLabel,
      budget: ((j['budget'] ?? 0) as num).toInt(),
      passengerName: (p['name'] ?? '') as String,
      passengerRating: (p['rating'] as num?)?.toDouble(),
      passengerRatingCount: (p['ratingCount'] ?? 0) as int,
      passengerVerified: (p['verified'] ?? false) as bool,
      comment: j['comment'] as String?,
      status: (j['status'] ?? 'open') as String,
      liked: (j['liked'] ?? false) as bool,
      responded: j['myResponse'] != null,
    );
  }
}
