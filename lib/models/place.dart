/// A settlement of the official SOATE directory (or an airport) — the backend
/// `Place` schema. Trips / requests reference places by [id]; names are
/// localized for display (`kg` → [nameKg]).
class Place {
  const Place({
    required this.id,
    required this.type,
    required this.nameRu,
    required this.nameKg,
    this.lat,
    this.lng,
    this.raionRu,
    this.raionKg,
    this.oblastRu,
    this.oblastKg,
  });

  final int id;
  final String type; // capital | city | town | village | airport
  final String nameRu;
  final String nameKg;
  final double? lat;
  final double? lng;
  final String? raionRu;
  final String? raionKg;
  final String? oblastRu;
  final String? oblastKg;

  bool get isAirport => type == 'airport';
  bool get isCapital => type == 'capital';
  bool get hasPoint => lat != null && lng != null;

  String name(bool kg) => kg ? nameKg : nameRu;

  /// Second line in pickers (Yandex-style): «Ноокенский район, Жалал-Абадская
  /// область». Capitals need none; oblast-level cities show the oblast only.
  String subtitle(bool kg) {
    if (isCapital) return '';
    final r = kg ? raionKg : raionRu;
    final o = kg ? oblastKg : oblastRu;
    return [r, o].where((s) => s != null && s.isNotEmpty).join(', ');
  }

  factory Place.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic>? sub(String k) => (j[k] as Map?)?.cast<String, dynamic>();
    final raion = sub('raion');
    final oblast = sub('oblast');
    return Place(
      id: (j['id'] as num).toInt(),
      type: (j['type'] ?? 'village') as String,
      nameRu: (j['nameRu'] ?? '') as String,
      nameKg: (j['nameKg'] ?? j['nameRu'] ?? '') as String,
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      raionRu: raion?['nameRu'] as String?,
      raionKg: raion?['nameKg'] as String?,
      oblastRu: oblast?['nameRu'] as String?,
      oblastKg: oblast?['nameKg'] as String?,
    );
  }

  /// Parses an optional nested place; tolerates legacy payloads without one.
  static Place? maybe(dynamic j) =>
      j is Map && j['id'] != null ? Place.fromJson(j.cast<String, dynamic>()) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'nameRu': nameRu,
        'nameKg': nameKg,
        'lat': lat,
        'lng': lng,
        if (raionRu != null) 'raion': {'nameRu': raionRu, 'nameKg': raionKg ?? raionRu},
        if (oblastRu != null) 'oblast': {'nameRu': oblastRu, 'nameKg': oblastKg ?? oblastRu},
      };

  @override
  bool operator ==(Object other) => other is Place && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Exact boarding / drop-off spot inside a settlement (map pin). [areaRu] /
/// [areaKg] is the жилмассив the server derived for pins in Бишкек / Ош.
class MeetingPoint {
  const MeetingPoint({required this.lat, required this.lng, this.address, this.areaRu, this.areaKg});

  final double lat;
  final double lng;
  final String? address;
  final String? areaRu;
  final String? areaKg;

  /// «ЦУМ · Асанбай» — note first, then the area; empty when neither is known.
  String label(bool kg) {
    final area = kg ? (areaKg ?? areaRu) : areaRu;
    return [address, area].where((s) => s != null && s.trim().isNotEmpty).join(' · ');
  }

  factory MeetingPoint.fromJson(Map<String, dynamic> j) {
    final area = (j['area'] as Map?)?.cast<String, dynamic>();
    return MeetingPoint(
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      address: j['address'] as String?,
      areaRu: area?['nameRu'] as String?,
      areaKg: area?['nameKg'] as String?,
    );
  }

  static MeetingPoint? maybe(dynamic j) =>
      j is Map && j['lat'] != null && j['lng'] != null ? MeetingPoint.fromJson(j.cast<String, dynamic>()) : null;

  /// Request body shape (the server derives the area itself).
  Map<String, dynamic> toBody() => {
        'lat': double.parse(lat.toStringAsFixed(6)),
        'lng': double.parse(lng.toStringAsFixed(6)),
        if (address != null && address!.trim().isNotEmpty) 'address': address!.trim(),
      };
}

/// One-tap pin inside Бишкек / Ош: a departure spot or a жилмассив.
class MeetingSpot {
  const MeetingSpot({required this.kind, required this.nameRu, required this.nameKg, required this.lat, required this.lng});

  final String kind; // spot | area
  final String nameRu;
  final String nameKg;
  final double lat;
  final double lng;

  String name(bool kg) => kg ? nameKg : nameRu;

  factory MeetingSpot.fromJson(Map<String, dynamic> j) => MeetingSpot(
        kind: (j['kind'] ?? 'spot') as String,
        nameRu: (j['nameRu'] ?? '') as String,
        nameKg: (j['nameKg'] ?? j['nameRu'] ?? '') as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
      );
}

/// A transfer airport (GET /cities/airports): the place, the city it serves
/// (Бишкек ↔ «Манас», Ош ↔ Ош), its display title, default flight type,
/// check-in buffers and popular other ends (served city first).
class Airport {
  const Airport({
    required this.place,
    this.serves,
    String? titleRu,
    String? titleKg,
    this.flightType = 'domestic',
    this.bufferMin = const {'international': 150, 'domestic': 90},
    this.popular = const [],
  })  : titleRu = titleRu ?? '',
        titleKg = titleKg ?? titleRu ?? '';
  final Place place;
  final Place? serves;
  final String titleRu;
  final String titleKg;
  final String flightType; // international | domestic
  final Map<String, int> bufferMin;
  final List<Place> popular;

  /// «Манас · Бишкек» / «Ош»; the directory name when no title came.
  String title(bool kg) {
    final t = kg ? titleKg : titleRu;
    return t.isEmpty ? place.name(kg) : t;
  }

  factory Airport.fromJson(Map<String, dynamic> j) {
    final buf = (j['departureBufferMin'] as Map?)?.cast<String, dynamic>();
    return Airport(
      place: Place.fromJson(j),
      serves: Place.maybe(j['serves']),
      titleRu: j['titleRu'] as String?,
      titleKg: j['titleKg'] as String?,
      flightType: (j['flightType'] ?? 'domestic') as String,
      bufferMin: buf == null
          ? const {'international': 150, 'domestic': 90}
          : {for (final e in buf.entries) e.key: (e.value as num).toInt()},
      popular: [
        for (final p in (j['popularDestinations'] as List?) ?? const [])
          if (Place.maybe(p) != null) Place.maybe(p)!,
      ],
    );
  }
}

/// GET /cities/airports/:id/pickup-suggestion — when to leave for a flight.
class PickupSuggestion {
  const PickupSuggestion({
    required this.pickupAt,
    required this.travelMin,
    required this.bufferMin,
    required this.distanceKm,
    required this.flightType,
  });
  final DateTime pickupAt; // local
  final int travelMin;
  final int bufferMin;
  final double distanceKm;
  final String flightType;

  factory PickupSuggestion.fromJson(Map<String, dynamic> j) => PickupSuggestion(
        pickupAt: DateTime.parse(j['pickupAt'] as String).toLocal(),
        travelMin: (j['travelMin'] as num?)?.toInt() ?? 0,
        bufferMin: (j['bufferMin'] as num?)?.toInt() ?? 0,
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        flightType: (j['flightType'] ?? 'domestic') as String,
      );
}
