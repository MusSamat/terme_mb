import 'metrics.dart';

/// Lean trip card model — mirror of tappjet_ft TripCardItem (browse card).
/// Hand-written for now; replaced by the freezed model in ТЗ step 2.
class TripCardItem {
  const TripCardItem({
    required this.id,
    required this.originCity,
    required this.destinationCity,
    required this.departureAt,
    required this.seatsAvailable,
    required this.seatsTotal,
    required this.pricePerSeat,
    required this.driver,
    this.pickupCities = const [],
    this.departureWindowEnd,
    this.status = 'active',
    this.liked = false,
    this.metrics,
    this.instant = false,
    this.wholeCabin = false,
    this.booked = false,
    this.comment,
    this.luggage = 'small',
    this.preferences = const {},
  });

  final String id;
  final String originCity;
  final String destinationCity;
  final DateTime departureAt;
  final DateTime? departureWindowEnd;
  final int seatsAvailable;
  final int seatsTotal;
  final int pricePerSeat;
  final TripDriver driver;
  final List<String> pickupCities;
  final String status; // active | completed | cancelled
  final bool liked;
  final Metrics? metrics; // creator-only engagement counters
  final bool instant;
  final bool wholeCabin;
  final bool booked;
  final String? comment;
  final String luggage; // yes | small | no
  final Map<String, bool> preferences;

  bool get soldOut => seatsAvailable == 0;
  bool get inactive => status != 'active';

  factory TripCardItem.fromJson(Map<String, dynamic> j) => TripCardItem(
        id: j['id'] as String,
        originCity: (j['originCity'] ?? '') as String,
        destinationCity: (j['destinationCity'] ?? '') as String,
        departureAt: DateTime.parse(j['departureAt'] as String),
        departureWindowEnd:
            j['departureWindowEnd'] != null ? DateTime.tryParse(j['departureWindowEnd'] as String) : null,
        seatsAvailable: (j['seatsAvailable'] ?? 0) as int,
        seatsTotal: (j['seatsTotal'] ?? 0) as int,
        pricePerSeat: ((j['pricePerSeat'] ?? 0) as num).toInt(),
        driver: TripDriver.fromJson((j['driver'] as Map?)?.cast<String, dynamic>() ?? const {}),
        pickupCities: (j['pickupCities'] as List?)?.cast<String>() ?? const [],
        status: (j['status'] ?? 'active') as String,
        liked: (j['liked'] ?? false) as bool,
        metrics: Metrics.fromJson(j['metrics']),
        luggage: (j['luggage'] ?? 'small') as String,
        comment: j['comment'] as String?,
        preferences: (j['preferences'] as Map?)?.map((k, v) => MapEntry(k as String, v as bool)) ?? const {},
      );
}

class TripDriver {
  const TripDriver({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.rating,
    this.ratingCount = 0,
    this.verified = false,
    this.car,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final double? rating;
  final int ratingCount;
  final bool verified;
  final TripCar? car;

  factory TripDriver.fromJson(Map<String, dynamic> j) => TripDriver(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        avatarUrl: j['avatarUrl'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        ratingCount: (j['ratingCount'] ?? 0) as int,
        verified: (j['verified'] ?? false) as bool,
        car: j['car'] != null ? TripCar.fromJson((j['car'] as Map).cast<String, dynamic>()) : null,
      );
}

class TripCar {
  const TripCar({required this.make, required this.model, this.color, this.plate});
  final String make;
  final String model;
  final String? color;
  final String? plate;

  factory TripCar.fromJson(Map<String, dynamic> j) => TripCar(
        make: (j['make'] ?? '') as String,
        model: (j['model'] ?? '') as String,
        color: j['color'] as String?,
        plate: j['plate'] as String?,
      );
}
