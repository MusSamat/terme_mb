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
  final bool instant;
  final bool wholeCabin;
  final bool booked;
  final String? comment;
  final String luggage; // yes | small | no
  final Map<String, bool> preferences;

  bool get soldOut => seatsAvailable == 0;
  bool get inactive => status != 'active';
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
}

class TripCar {
  const TripCar({required this.make, required this.model, this.color, this.plate});
  final String make;
  final String model;
  final String? color;
  final String? plate;
}
