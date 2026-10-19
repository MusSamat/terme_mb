import 'metrics.dart';
import 'place.dart';

/// Lean passenger-request model — mirror of terme_ft PassengerRequest card.
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
    this.passengerId,
    this.passengerRating,
    this.passengerRatingCount = 0,
    this.passengerVerified = false,
    this.comment,
    this.status = 'open',
    this.liked = false,
    this.responded = false,
    this.departureDate,
    this.metrics,
    this.kind = 'intercity',
    this.flightNumber,
    this.originCityId,
    this.destinationCityId,
    this.origin,
    this.destination,
    this.originPoint,
    this.destinationPoint,
    this.lat,
    this.lng,
    this.nearTarget,
    this.meetWithSign = false,
    this.luggageCount,
    this.distanceKm,
  });

  final String id;
  final String originCity;
  final String destinationCity;
  final int seatsNeeded;
  final String dateLabel;
  final DateTime? departureDate;
  final int budget;
  final String passengerName;
  final String? passengerId;
  final double? passengerRating;
  final int passengerRatingCount;
  final bool passengerVerified;
  final String? comment;
  final String status; // open | closed
  final bool liked;
  final bool responded;
  final Metrics? metrics; // creator-only engagement counters
  final String kind; // intercity | airport
  final String? flightNumber;
  final int? originCityId;
  final int? destinationCityId;
  final Place? origin;
  final Place? destination;
  final MeetingPoint? originPoint; // where the passenger waits
  final MeetingPoint? destinationPoint;
  // Boarding / waiting point from the API: the pin, else the origin settlement.
  final double? lat;
  final double? lng;
  // target_time searches only: departure within ±2h of the target.
  final bool? nearTarget;
  // Airport requests: meet at arrivals with a name sign; luggage pieces (null = not said).
  final bool meetWithSign;
  final int? luggageCount;
  final double? distanceKm; // sort=nearest only

  bool get isAirport => kind == 'airport';
  String originName(bool kg) => origin?.name(kg) ?? originCity;
  String destinationName(bool kg) => destination?.name(kg) ?? destinationCity;

  factory PassengerRequestItem.fromJson(Map<String, dynamic> j) {
    final p = (j['passenger'] as Map?)?.cast<String, dynamic>() ?? const {};
    final date = j['departureDate'] != null ? DateTime.tryParse(j['departureDate'] as String)?.toLocal() : null;
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
      passengerId: (j['passengerId'] ?? p['id']) as String?,
      passengerRating: (p['rating'] as num?)?.toDouble(),
      passengerRatingCount: (p['ratingCount'] ?? 0) as int,
      passengerVerified: (p['verified'] ?? false) as bool,
      comment: j['comment'] as String?,
      status: (j['status'] ?? 'open') as String,
      liked: (j['liked'] ?? false) as bool,
      responded: j['myResponse'] != null,
      departureDate: date,
      metrics: Metrics.fromJson(j['metrics']),
      kind: (j['kind'] ?? 'intercity') as String,
      flightNumber: j['flightNumber'] as String?,
      originCityId: (j['originCityId'] as num?)?.toInt(),
      destinationCityId: (j['destinationCityId'] as num?)?.toInt(),
      origin: Place.maybe(j['origin']),
      destination: Place.maybe(j['destination']),
      originPoint: MeetingPoint.maybe(j['originPoint']),
      destinationPoint: MeetingPoint.maybe(j['destinationPoint']),
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      nearTarget: j['nearTarget'] as bool?,
      meetWithSign: (j['meetWithSign'] ?? false) as bool,
      luggageCount: (j['luggageCount'] as num?)?.toInt(),
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
    );
  }
}
