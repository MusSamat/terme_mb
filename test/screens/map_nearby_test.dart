import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/api/services/misc_services.dart';
import 'package:terme_mb/models/passenger_request.dart';
import 'package:terme_mb/models/place.dart';
import 'package:terme_mb/models/trip_card_item.dart';
import 'package:terme_mb/screens/map/map_nearby.dart';

const bishkek = (lat: 42.8746, lng: 74.5698);
final soon = DateTime.now().add(const Duration(days: 1));

MapItem item(String id, double km, {Duration later = Duration.zero}) => MapItem(
      id: id,
      lat: bishkek.lat + km / 111.2, // ~km north of Bishkek
      lng: bishkek.lng,
      exact: true,
      originCity: 'Бишкек',
      destinationCity: 'Ош',
      departureAt: soon.add(later),
      seats: 2,
    );

void main() {
  test('haversine: Bishkek → Osh ≈ 300 km, zero to itself', () {
    expect(haversineKm(bishkek, (lat: 40.5283, lng: 72.7985)), closeTo(301, 6));
    expect(haversineKm(bishkek, bishkek), 0);
  });

  group('sortResults', () {
    final items = [
      item('far', 20, later: const Duration(hours: 1)),
      item('near', 2, later: const Duration(hours: 3)),
      item('mid', 8, later: const Duration(hours: 2)),
    ];

    test('with a location: nearest first, distance attached', () {
      final r = sortResults(bishkek, items);
      expect(r.map((e) => e.item.id), ['near', 'mid', 'far']);
      expect(r.first.km, closeTo(2, 0.1));
    });

    test('without a location: by departure time, no distance', () {
      final r = sortResults(null, items);
      expect(r.map((e) => e.item.id), ['far', 'mid', 'near']);
      expect(r.every((e) => e.km == null), isTrue);
    });
  });

  group('pickup pins', () {
    const from = Place(id: 1, type: 'city', nameRu: 'Бишкек', nameKg: 'Бишкек', lat: 42.87, lng: 74.59);
    Map<String, dynamic> trip({Map<String, dynamic>? point, Map<String, dynamic>? origin}) => {
          'id': 't1',
          'originCity': 'Бишкек',
          'destinationCity': 'Ош',
          'departureAt': soon.toUtc().toIso8601String(),
          'seatsAvailable': 3,
          'pricePerSeat': 1200,
          if (point != null) 'originPoint': point,
          if (origin != null) 'origin': origin,
        };

    test('meeting point wins and is exact', () {
      final p = tripPin(TripCardItem.fromJson(trip(point: {'lat': 42.9, 'lng': 74.6})), fallback: from)!;
      expect((p.lat, p.lng, p.exact, p.seats, p.price), (42.9, 74.6, true, 3, 1200));
    });

    test('no point → listing origin city, then the searched «Откуда»', () {
      final viaOrigin = tripPin(
          TripCardItem.fromJson(trip(origin: {'id': 5, 'nameRu': 'Кант', 'lat': 42.89, 'lng': 74.85})),
          fallback: from)!;
      expect((viaOrigin.lat, viaOrigin.exact), (42.89, false));
      final viaFrom = tripPin(TripCardItem.fromJson(trip()), fallback: from)!;
      expect((viaFrom.lat, viaFrom.lng), (42.87, 74.59));
      expect(tripPin(TripCardItem.fromJson(trip())), isNull, reason: 'no coordinates at all');
    });

    test('request pin uses where the passenger waits + seats needed', () {
      final r = PassengerRequestItem.fromJson({
        'id': 'r1',
        'originCity': 'Бишкек',
        'destinationCity': 'Ош',
        'seatsNeeded': 2,
        'departureDate': soon.toUtc().toIso8601String(),
        'originPoint': {'lat': 42.8, 'lng': 74.5},
      });
      final p = requestPin(r)!;
      expect((p.lat, p.seats, p.price), (42.8, 2, null));
    });
  });
}
