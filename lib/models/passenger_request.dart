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
}
