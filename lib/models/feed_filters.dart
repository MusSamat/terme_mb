/// Feed filter state — mirrors the tappjet_ft search query params.
class FeedFilters {
  const FeedFilters({
    this.from = '',
    this.to = '',
    this.date = '', // '' = today, 'any', or YYYY-MM-DD
    this.sort = 'time', // time | price_asc | rating_desc
    this.onlyVerified = false,
    this.luggage = '', // '' | yes | small | no
    this.minRating = 0,
    this.minPrice,
    this.maxPrice,
    this.womenOnly = false,
    this.noSmoking = false,
    this.pets = false,
  });

  final String from;
  final String to;
  final String date;
  final String sort;
  final bool onlyVerified;
  final String luggage;
  final double minRating;
  final int? minPrice;
  final int? maxPrice;
  final bool womenOnly;
  final bool noSmoking;
  final bool pets;

  FeedFilters copyWith({
    String? from,
    String? to,
    String? date,
    String? sort,
    bool? onlyVerified,
    String? luggage,
    double? minRating,
    int? minPrice,
    int? maxPrice,
    bool? womenOnly,
    bool? noSmoking,
    bool? pets,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return FeedFilters(
      from: from ?? this.from,
      to: to ?? this.to,
      date: date ?? this.date,
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
}
