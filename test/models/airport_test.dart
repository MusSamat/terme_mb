import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/models/feed_filters.dart';
import 'package:terme_mb/models/passenger_request.dart';
import 'package:terme_mb/models/place.dart';
import 'package:terme_mb/models/trip_card_item.dart';
import 'package:terme_mb/providers/data_providers.dart';
import 'package:terme_mb/utils/airport.dart';

Map<String, dynamic> place(int id, String ru, {String type = 'city', String? kg, String? oblast}) => {
      'id': id,
      'type': type,
      'nameRu': ru,
      'nameKg': kg ?? ru,
      if (oblast != null) 'oblast': {'nameRu': oblast, 'nameKg': oblast},
    };

final manas = Airport.fromJson({
  ...place(900, 'Манас', type: 'airport'),
  'serves': place(1, 'Бишкек', type: 'capital'),
  'titleRu': 'Манас · Бишкек',
  'titleKg': 'Манас · Бишкек',
  'flightType': 'international',
  'departureBufferMin': {'international': 150, 'domestic': 90},
  'popularDestinations': [place(1, 'Бишкек', type: 'capital'), place(5, 'Кант', type: 'town')],
});

final osh = Airport.fromJson({
  ...place(901, 'Ош', type: 'airport'),
  'serves': place(2, 'Ош'),
  'titleRu': 'Ош',
  'titleKg': 'Ош',
  'flightType': 'domestic',
  'popularDestinations': [place(2, 'Ош'), place(77, 'Манас', oblast: 'Жалал-Абадская область')],
});

void main() {
  group('Airport.fromJson', () {
    test('title, flight type, buffers, popular (served city first)', () {
      expect(manas.title(false), 'Манас · Бишкек');
      expect(manas.flightType, 'international');
      expect(manas.bufferMin['domestic'], 90);
      expect(manas.popular.map((p) => p.id), [1, 5]);
      expect(osh.bufferMin['international'], 150, reason: 'defaults when the API omits buffers');
    });

    test('no title → the directory name', () {
      final a = Airport.fromJson(place(9, 'Тамчы', type: 'airport'));
      expect(a.title(true), 'Тамчы');
      expect(a.popular, isEmpty);
    });
  });

  test('PickupSuggestion parses the API payload (local time)', () {
    final s = PickupSuggestion.fromJson({
      'pickupAt': '2026-10-20T21:30:00.000Z',
      'travelMin': 30,
      'bufferMin': 150,
      'distanceKm': 24.6,
      'flightType': 'international',
    });
    expect(s.pickupAt, DateTime.utc(2026, 10, 20, 21, 30).toLocal());
    expect((s.travelMin, s.bufferMin, s.distanceKm, s.flightType), (30, 150, 24.6, 'international'));
  });

  group('collidesWithAirport', () {
    final town = osh.popular.last; // Жалал-Абад oblast's «Манас»
    test('a town named like an airport title needs its oblast line', () {
      expect(collidesWithAirport(town, [manas, osh], false), isTrue);
      expect(town.subtitle(false), 'Жалал-Абадская область');
    });
    test('the served city and plain names do not', () {
      expect(collidesWithAirport(osh.popular.first, [manas, osh], false), isFalse, reason: 'Ош ↔ «Ош»');
      expect(collidesWithAirport(manas.popular.last, [manas, osh], false), isFalse);
      expect(collidesWithAirport(manas.place, [manas, osh], false), isFalse);
    });
  });

  group('target_time grouping', () {
    test('near first, rest after, API order kept', () {
      final g = groupByTarget([('a', true), ('b', false), ('c', true), ('d', null)], (x) => x.$2);
      expect(g.near.map((x) => x.$1), ['a', 'c']);
      expect(g.rest.map((x) => x.$1), ['b', 'd']);
    });
    test('landing + 30 min slack', () {
      expect(departureAfterArrival(DateTime(2026, 10, 20, 5, 40)), DateTime(2026, 10, 20, 6, 10));
    });
  });

  group('target_time queries', () {
    const from = Place(id: 1, type: 'capital', nameRu: 'Бишкек', nameKg: 'Бишкек');
    const to = Place(id: 900, type: 'airport', nameRu: 'Манас', nameKg: 'Манас');
    const f = FeedFilters(
        from: from, to: to, kind: 'airport', date: '2026-10-20', sort: 'price_asc', targetTime: '2026-10-19T21:30:00.000Z');

    test('target_time replaces date and sort', () {
      final q = tripQuery(f);
      expect(q['target_time'], '2026-10-19T21:30:00.000Z');
      expect(q.containsKey('date') || q.containsKey('sort'), isFalse);
      expect(q['kind'], 'airport');
      expect(requestQuery(f)['target_time'], '2026-10-19T21:30:00.000Z');
    });

    test('changing the day drops the target; keeping it does not', () {
      expect(f.copyWith(date: '2026-10-21').targetTime, isNull);
      expect(f.copyWith(date: '2026-10-20').targetTime, isNotNull);
      expect(f.copyWith(clearTarget: true).targetTime, isNull);
      expect(f == f.copyWith(clearTarget: true), isFalse, reason: 'target is part of the provider key');
    });
  });

  group('listing extras', () {
    test('request: meetWithSign, luggageCount, nearTarget', () {
      final r = PassengerRequestItem.fromJson({
        'id': 'r1',
        'kind': 'airport',
        'originCity': 'Манас',
        'destinationCity': 'Бишкек',
        'meetWithSign': true,
        'luggageCount': 2,
        'nearTarget': true,
      });
      expect((r.meetWithSign, r.luggageCount, r.nearTarget, r.isAirport), (true, 2, true, true));
      final plain = PassengerRequestItem.fromJson({'id': 'r2', 'originCity': 'A', 'destinationCity': 'B'});
      expect((plain.meetWithSign, plain.luggageCount, plain.nearTarget), (false, null, null));
    });

    test('trip: nearTarget', () {
      final t = TripCardItem.fromJson({
        'id': 't1',
        'departureAt': '2026-10-20T03:00:00.000Z',
        'nearTarget': false,
      });
      expect(t.nearTarget, isFalse);
    });
  });
}
