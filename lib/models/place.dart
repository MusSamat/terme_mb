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

/// An airport and the city it serves (Бишкек ↔ «Манас», Ош ↔ Ош).
class Airport {
  const Airport({required this.place, this.serves});
  final Place place;
  final Place? serves;

  factory Airport.fromJson(Map<String, dynamic> j) =>
      Airport(place: Place.fromJson(j), serves: Place.maybe(j['serves']));
}
