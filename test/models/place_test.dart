import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/api/services/misc_services.dart';
import 'package:terme_mb/models/place.dart';

void main() {
  const json = {
    'id': 42,
    'type': 'village',
    'nameRu': 'Кочкор-Ата',
    'nameKg': 'Кочкор-Ата',
    'lat': 41.03,
    'lng': 72.48,
    'raion': {'nameRu': 'Ноокенский район', 'nameKg': 'Ноокен району'},
    'oblast': {'nameRu': 'Жалал-Абадская область', 'nameKg': 'Жалал-Абад облусу'},
  };

  group('Place', () {
    final p = Place.fromJson(json);
    test('id + type', () {
      expect(p.id, 42);
      expect(p.type, 'village');
    });
    test('two-line subtitle per locale', () {
      expect(p.subtitle(false), 'Ноокенский район, Жалал-Абадская область');
      expect(p.subtitle(true), 'Ноокен району, Жалал-Абад облусу');
    });
    test('capital has no subtitle', () {
      final b = Place.fromJson({'id': 1, 'type': 'capital', 'nameRu': 'Бишкек', 'nameKg': 'Бишкек', 'oblast': {'nameRu': 'X'}});
      expect(b.subtitle(false), '');
    });
    test('localized name, nameKg falls back to nameRu', () {
      final x = Place.fromJson({'id': 2, 'nameRu': 'Ош'});
      expect(x.name(true), 'Ош');
      expect(x.type, 'village');
    });
    test('toJson round-trips (recent routes in Hive)', () {
      final back = Place.fromJson(p.toJson());
      expect(back, p);
      expect(back.subtitle(true), p.subtitle(true));
      expect(back.hasPoint, true);
    });
    test('equality by id', () {
      expect(Place.fromJson(json) == Place.fromJson({...json, 'nameRu': 'other'}), true);
    });
    test('maybe() tolerates legacy payloads', () {
      expect(Place.maybe(null), isNull);
      expect(Place.maybe('Бишкек'), isNull);
      expect(Place.maybe({'nameRu': 'no id'}), isNull);
      expect(Place.maybe(json)?.id, 42);
    });
  });

  group('MeetingPoint', () {
    test('label: note · area, localized area', () {
      final m = MeetingPoint.fromJson({
        'lat': 42.87,
        'lng': 74.59,
        'address': 'у ЦУМа',
        'area': {'nameRu': 'Асанбай', 'nameKg': 'Асанбай мкр'},
      });
      expect(m.label(false), 'у ЦУМа · Асанбай');
      expect(m.label(true), 'у ЦУМа · Асанбай мкр');
    });
    test('label empty when nothing known', () {
      expect(const MeetingPoint(lat: 1, lng: 2).label(false), '');
    });
    test('toBody rounds to 6 digits and drops blank address', () {
      final b = const MeetingPoint(lat: 42.123456789, lng: 74.987654321, address: '  ').toBody();
      expect(b, {'lat': 42.123457, 'lng': 74.987654});
    });
    test('maybe() needs both coordinates', () {
      expect(MeetingPoint.maybe({'lat': 1}), isNull);
      expect(MeetingPoint.maybe({'lat': 1, 'lng': 2})?.lng, 2);
    });
  });

  group('Airport', () {
    test('serves = the city it is for', () {
      final a = Airport.fromJson({
        'id': 900,
        'type': 'airport',
        'nameRu': 'Манас',
        'nameKg': 'Манас',
        'serves': {'id': 1, 'type': 'capital', 'nameRu': 'Бишкек', 'nameKg': 'Бишкек'},
      });
      expect(a.place.isAirport, true);
      expect(a.serves?.id, 1);
    });
  });

  group('MapListings', () {
    test('items + clusters', () {
      final m = MapListings.fromJson({
        'items': [
          {
            'id': 't1',
            'lat': 42.8,
            'lng': 74.6,
            'exact': true,
            'originCity': 'Бишкек',
            'destinationCity': 'Ош',
            'destinationCityId': 2,
            'departureAt': '2026-10-20T03:00:00.000Z',
            'seats': 3,
            'price': 1200,
          }
        ],
        'clusters': [
          {'lat': 40.5, 'lng': 72.8, 'count': 7}
        ],
      });
      expect(m.items.single.price, 1200);
      expect(m.items.single.exact, true);
      expect(m.clusters.single.count, 7);
    });
    test('request items have null price; empty body → empty', () {
      expect(MapListings.fromJson(const {}).items, isEmpty);
    });
  });
}
