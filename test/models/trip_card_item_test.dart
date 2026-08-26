import 'package:flutter_test/flutter_test.dart';
import 'package:tappjet_mb/models/trip_card_item.dart';

/// Full-fidelity JSON as the backend returns it for a trip card.
Map<String, dynamic> fullJson() => {
      'id': 't1',
      'originCity': 'Бишкек',
      'destinationCity': 'Ош',
      'departureAt': '2026-08-10T07:30:00+06:00',
      'departureWindowEnd': '2026-08-10T09:00:00+06:00',
      'seatsAvailable': 2,
      'seatsTotal': 4,
      'pricePerSeat': 1200,
      'pickupCities': ['Кара-Балта', 'Токтогул'],
      'status': 'active',
      'liked': true,
      'luggage': 'yes',
      'comment': 'Еду быстро',
      'preferences': {'no_smoking': true, 'pets': false},
      'driver': {
        'id': 'd1',
        'name': 'Азамат',
        'avatarUrl': 'https://x/a.png',
        'rating': 4.7,
        'ratingCount': 33,
        'verified': true,
        'car': {'make': 'Toyota', 'model': 'Camry', 'color': 'белый', 'plate': '01KG777'},
      },
    };

void main() {
  group('TripCardItem.fromJson — full payload', () {
    final t = TripCardItem.fromJson(fullJson());

    test('id', () => expect(t.id, 't1'));
    test('originCity', () => expect(t.originCity, 'Бишкек'));
    test('destinationCity', () => expect(t.destinationCity, 'Ош'));
    test('departureAt parsed', () => expect(t.departureAt.toUtc(), DateTime.utc(2026, 8, 10, 1, 30)));
    test('departureWindowEnd parsed', () => expect(t.departureWindowEnd, isNotNull));
    test('seatsAvailable', () => expect(t.seatsAvailable, 2));
    test('seatsTotal', () => expect(t.seatsTotal, 4));
    test('pricePerSeat', () => expect(t.pricePerSeat, 1200));
    test('pickupCities', () => expect(t.pickupCities, ['Кара-Балта', 'Токтогул']));
    test('status', () => expect(t.status, 'active'));
    test('liked', () => expect(t.liked, true));
    test('luggage', () => expect(t.luggage, 'yes'));
    test('comment', () => expect(t.comment, 'Еду быстро'));
    test('preferences map', () => expect(t.preferences, {'no_smoking': true, 'pets': false}));
    test('driver nested', () => expect(t.driver.name, 'Азамат'));
    test('driver car nested', () => expect(t.driver.car?.make, 'Toyota'));
  });

  group('TripCardItem.fromJson — defaults / missing fields', () {
    final t = TripCardItem.fromJson({'id': 't2', 'departureAt': '2026-08-10T07:30:00+06:00', 'driver': {}});

    test('originCity → empty', () => expect(t.originCity, ''));
    test('destinationCity → empty', () => expect(t.destinationCity, ''));
    test('seatsAvailable → 0', () => expect(t.seatsAvailable, 0));
    test('seatsTotal → 0', () => expect(t.seatsTotal, 0));
    test('pricePerSeat → 0', () => expect(t.pricePerSeat, 0));
    test('pickupCities → empty', () => expect(t.pickupCities, isEmpty));
    test('status → active', () => expect(t.status, 'active'));
    test('liked → false', () => expect(t.liked, false));
    test('luggage → small', () => expect(t.luggage, 'small'));
    test('comment → null', () => expect(t.comment, isNull));
    test('preferences → empty', () => expect(t.preferences, isEmpty));
    test('departureWindowEnd → null', () => expect(t.departureWindowEnd, isNull));
    test('driver empty → blank name/id', () {
      expect(t.driver.id, '');
      expect(t.driver.name, '');
    });
    test('driver car → null when absent', () => expect(t.driver.car, isNull));
  });

  group('TripCardItem derived getters', () {
    test('soldOut true when 0 seats', () {
      final t = TripCardItem.fromJson({...fullJson(), 'seatsAvailable': 0});
      expect(t.soldOut, true);
    });
    test('soldOut false when seats remain', () {
      expect(TripCardItem.fromJson(fullJson()).soldOut, false);
    });
    test('inactive true when completed', () {
      final t = TripCardItem.fromJson({...fullJson(), 'status': 'completed'});
      expect(t.inactive, true);
    });
    test('inactive true when cancelled', () {
      final t = TripCardItem.fromJson({...fullJson(), 'status': 'cancelled'});
      expect(t.inactive, true);
    });
    test('inactive false when active', () {
      expect(TripCardItem.fromJson(fullJson()).inactive, false);
    });
  });

  group('TripCardItem numeric coercion', () {
    test('pricePerSeat accepts a double from JSON', () {
      final t = TripCardItem.fromJson({...fullJson(), 'pricePerSeat': 1200.0});
      expect(t.pricePerSeat, 1200);
    });
  });

  group('TripDriver.fromJson', () {
    test('rating parsed as double from int', () {
      final d = TripDriver.fromJson({'id': 'd', 'name': 'N', 'rating': 5});
      expect(d.rating, 5.0);
    });
    test('rating null when absent', () {
      final d = TripDriver.fromJson({'id': 'd', 'name': 'N'});
      expect(d.rating, isNull);
    });
    test('verified default false', () {
      expect(TripDriver.fromJson({'id': 'd', 'name': 'N'}).verified, false);
    });
    test('ratingCount default 0', () {
      expect(TripDriver.fromJson({'id': 'd', 'name': 'N'}).ratingCount, 0);
    });
  });

  group('TripCar.fromJson', () {
    test('make/model required-ish default to empty', () {
      final c = TripCar.fromJson({});
      expect(c.make, '');
      expect(c.model, '');
    });
    test('color/plate optional', () {
      final c = TripCar.fromJson({'make': 'Kia', 'model': 'Rio'});
      expect(c.color, isNull);
      expect(c.plate, isNull);
    });
  });

  group('TripCardItem constructor defaults', () {
    final t = TripCardItem(
      id: 'x',
      originCity: 'A',
      destinationCity: 'B',
      departureAt: DateTime.utc(2026, 8, 10, 7, 30),
      seatsAvailable: 1,
      seatsTotal: 3,
      pricePerSeat: 500,
      driver: const TripDriver(id: 'd', name: 'N'),
    );
    test('instant default false', () => expect(t.instant, false));
    test('wholeCabin default false', () => expect(t.wholeCabin, false));
    test('booked default false', () => expect(t.booked, false));
    test('liked default false', () => expect(t.liked, false));
    test('luggage default small', () => expect(t.luggage, 'small'));
  });
}
