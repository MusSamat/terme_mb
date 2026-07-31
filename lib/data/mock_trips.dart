import '../models/trip_card_item.dart';

/// Approximate coordinates for the sample KG cities (for the detail map).
const Map<String, ({double lat, double lng})> kCityCoords = {
  'Бишкек': (lat: 42.8746, lng: 74.5698),
  'Ош': (lat: 40.5283, lng: 72.7985),
  'Джалал-Абад': (lat: 40.9333, lng: 73.0000),
  'Каракол': (lat: 42.4907, lng: 78.3936),
  'Талас': (lat: 42.5228, lng: 72.2427),
  'Нарын': (lat: 41.4287, lng: 75.9911),
};

const _drivers = [
  TripDriver(id: 'd1', name: 'Азамат Кыдыров', rating: 4.9, ratingCount: 128, verified: true, car: TripCar(make: 'Toyota', model: 'Camry', plate: '01KG777')),
  TripDriver(id: 'd2', name: 'Нургуль С.', rating: 4.7, ratingCount: 41, car: TripCar(make: 'Honda', model: 'Fit')),
  TripDriver(id: 'd3', name: 'Тимур', ratingCount: 0, car: TripCar(make: 'Hyundai', model: 'Starex')),
  TripDriver(id: 'd4', name: 'Бек Осмонов', rating: 5.0, ratingCount: 12, verified: true, car: TripCar(make: 'Toyota', model: 'Prius')),
  TripDriver(id: 'd5', name: 'Эркин', rating: 4.5, ratingCount: 7, car: TripCar(make: 'Mercedes', model: 'Sprinter')),
  TripDriver(id: 'd6', name: 'Айбек', rating: 4.8, ratingCount: 63, verified: true, car: TripCar(make: 'Lexus', model: 'RX')),
];

const _routes = [
  ('Бишкек', 'Ош'),
  ('Ош', 'Джалал-Абад'),
  ('Бишкек', 'Каракол'),
  ('Талас', 'Бишкек'),
  ('Бишкек', 'Нарын'),
];

const _luggage = ['small', 'yes', 'no', 'small', 'yes'];

/// ~18 trips spread across today..+8 so the calendar counts and date filter
/// are meaningful. Deterministic (no RNG). Replaced by /trips in ТЗ step 2.
List<TripCardItem> mockTrips() {
  final now = DateTime.now();
  final base = DateTime(now.year, now.month, now.day);
  final trips = <TripCardItem>[];
  var i = 0;
  // Distribution: how many trips on each day offset from today.
  const perDay = [3, 2, 3, 1, 2, 0, 2, 1, 3];
  for (var dayOffset = 0; dayOffset < perDay.length; dayOffset++) {
    for (var k = 0; k < perDay[dayOffset]; k++) {
      final route = _routes[(i + k) % _routes.length];
      final driver = _drivers[i % _drivers.length];
      final hour = 6 + ((i * 3 + k * 2) % 14);
      final dep = DateTime(base.year, base.month, base.day + dayOffset, hour, (k % 2) * 30);
      const seatsTotal = 4;
      final seatsAvail = ((i + k) % 5); // 0..4, sometimes sold out
      trips.add(TripCardItem(
        id: 't${i + 1}',
        originCity: route.$1,
        destinationCity: route.$2,
        departureAt: dep,
        seatsTotal: seatsTotal,
        seatsAvailable: seatsAvail > seatsTotal ? seatsTotal : seatsAvail,
        pricePerSeat: 300 + ((i % 6) * 180),
        driver: driver,
        pickupCities: i.isEven ? const ['Кара-Балта'] : const [],
        instant: i % 3 == 0,
        wholeCabin: i % 5 == 0,
        liked: i % 4 == 0,
        luggage: _luggage[i % _luggage.length],
      ));
      i++;
    }
  }
  return trips;
}

/// Per-day trip counts derived from the sample data (for the calendar / stepper).
Map<String, int> tripCalendarCounts() {
  final counts = <String, int>{};
  for (final t in mockTrips()) {
    final d = t.departureAt;
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
}

TripCardItem mockTripById(String id) {
  final list = mockTrips();
  final base = list.firstWhere((t) => t.id == id, orElse: () => list.first);
  return TripCardItem(
    id: base.id,
    originCity: base.originCity,
    destinationCity: base.destinationCity,
    departureAt: base.departureAt,
    departureWindowEnd: base.departureWindowEnd,
    seatsAvailable: base.seatsAvailable,
    seatsTotal: base.seatsTotal,
    pricePerSeat: base.pricePerSeat,
    driver: base.driver,
    pickupCities: base.pickupCities,
    status: base.status,
    liked: base.liked,
    instant: base.instant,
    wholeCabin: base.wholeCabin,
    luggage: base.luggage,
    comment: 'Выезжаю утром от автовокзала. Есть место для небольшого багажа. '
        'Можно с ручной кладью, помогу загрузить.',
    preferences: const {'no_smoking': true, 'clean': true, 'music': true},
  );
}
