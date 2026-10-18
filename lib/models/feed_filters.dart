import 'place.dart';

/// Feed filter state — mirrors the /trips and /passenger-requests query params.
class FeedFilters {
  const FeedFilters({
    this.from,
    this.to,
    this.kind, // null = all | intercity | airport
    this.date = '', // '' = today, 'any', or YYYY-MM-DD
    this.seats, // ride-type: null = С попутчиками, 4 = Весь салон
    this.sort = 'time', // time | price_asc | rating_desc | nearest
    this.onlyVerified = false,
    this.luggage = '', // '' | yes | small | no
    this.minRating = 0,
    this.minPrice,
    this.maxPrice,
    this.womenOnly = false,
    this.noSmoking = false,
    this.pets = false,
  });

  final Place? from;
  final Place? to;
  final String? kind;
  final String date;
  final int? seats;
  final String sort;
  final bool onlyVerified;
  final String luggage;
  final double minRating;
  final int? minPrice;
  final int? maxPrice;
  final bool womenOnly;
  final bool noSmoking;
  final bool pets;

  bool get hasRoute => from != null && to != null;

  FeedFilters copyWith({
    Place? from,
    Place? to,
    String? kind,
    String? date,
    int? seats,
    String? sort,
    bool? onlyVerified,
    String? luggage,
    double? minRating,
    int? minPrice,
    int? maxPrice,
    bool? womenOnly,
    bool? noSmoking,
    bool? pets,
    bool clearFrom = false,
    bool clearTo = false,
    bool clearSeats = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return FeedFilters(
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      kind: kind ?? this.kind,
      date: date ?? this.date,
      seats: clearSeats ? null : (seats ?? this.seats),
      sort: sort ?? this.sort,
      onlyVerified: onlyVerified ?? this.onlyVerified,
      luggage: luggage ?? this.luggage,
      minRating: minRating ?? this.minRating,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      womenOnly: womenOnly ?? this.womenOnly,
      noSmoking: noSmoking ?? this.noSmoking,
      pets: pets ?? this.pets,
    );
  }

  int get activeCount {
    var n = 0;
    if (onlyVerified) n++;
    if (luggage.isNotEmpty) n++;
    if (minRating > 0) n++;
    if (minPrice != null || maxPrice != null) n++;
    if (womenOnly) n++;
    if (noSmoking) n++;
    if (pets) n++;
    if (sort != 'time') n++;
    return n;
  }

  // Value equality — FeedFilters is a provider family key.
  List<Object?> get _props => [
        from?.id, to?.id, kind, date, seats, sort, onlyVerified, luggage, minRating,
        minPrice, maxPrice, womenOnly, noSmoking, pets,
      ];

  @override
  bool operator ==(Object other) =>
      other is FeedFilters && _props.join('|') == other._props.join('|');

  @override
  int get hashCode => _props.join('|').hashCode;
}
