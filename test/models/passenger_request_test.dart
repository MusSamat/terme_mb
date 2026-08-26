import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/models/passenger_request.dart';

void main() {
  group('PassengerRequestItem.fromJson — full payload', () {
    final r = PassengerRequestItem.fromJson({
      'id': 'r1',
      'originCity': 'Бишкек',
      'destinationCity': 'Ош',
      'seatsNeeded': 2,
      'budget': 800,
      'departureDate': '2026-08-05T12:00:00Z',
      'comment': 'Нужно срочно',
      'status': 'open',
      'liked': true,
      'myResponse': {'id': 'resp1'},
      'passenger': {'id': 'u7', 'name': 'Айгуль', 'rating': 4.9, 'ratingCount': 12, 'verified': true},
    });

    test('id', () => expect(r.id, 'r1'));
    test('originCity', () => expect(r.originCity, 'Бишкек'));
    test('destinationCity', () => expect(r.destinationCity, 'Ош'));
    test('seatsNeeded', () => expect(r.seatsNeeded, 2));
    test('budget', () => expect(r.budget, 800));
    test('comment', () => expect(r.comment, 'Нужно срочно'));
    test('status', () => expect(r.status, 'open'));
    test('liked', () => expect(r.liked, true));
    test('passengerName', () => expect(r.passengerName, 'Айгуль'));
    test('passengerId from nested passenger', () => expect(r.passengerId, 'u7'));
    test('passengerRating', () => expect(r.passengerRating, 4.9));
    test('passengerRatingCount', () => expect(r.passengerRatingCount, 12));
    test('passengerVerified', () => expect(r.passengerVerified, true));
    test('responded true when myResponse present', () => expect(r.responded, true));
    test('departureDate parsed', () => expect(r.departureDate, isNotNull));
    test('dateLabel derived as dd.MM from date', () => expect(r.dateLabel, '05.08'));
  });

  group('PassengerRequestItem.fromJson — defaults', () {
    final r = PassengerRequestItem.fromJson({'id': 'r2'});
    test('seatsNeeded defaults to 1', () => expect(r.seatsNeeded, 1));
    test('budget defaults to 0', () => expect(r.budget, 0));
    test('status defaults to open', () => expect(r.status, 'open'));
    test('liked defaults false', () => expect(r.liked, false));
    test('responded false when no myResponse', () => expect(r.responded, false));
    test('passengerName empty when no passenger', () => expect(r.passengerName, ''));
    test('passengerId null when no passenger', () => expect(r.passengerId, isNull));
    test('passengerRating null', () => expect(r.passengerRating, isNull));
    test('passengerRatingCount 0', () => expect(r.passengerRatingCount, 0));
    test('passengerVerified false', () => expect(r.passengerVerified, false));
    test('departureDate null', () => expect(r.departureDate, isNull));
    test('dateLabel empty when neither date nor label', () => expect(r.dateLabel, ''));
  });

  group('PassengerRequestItem — dateLabel fallback', () {
    test('uses explicit dateLabel when no departureDate', () {
      final r = PassengerRequestItem.fromJson({'id': 'r3', 'dateLabel': 'завтра'});
      expect(r.dateLabel, 'завтра');
    });
    test('departureDate wins over dateLabel', () {
      final r = PassengerRequestItem.fromJson({
        'id': 'r4',
        'dateLabel': 'IGNORED',
        'departureDate': '2026-12-31T12:00:00Z',
      });
      expect(r.dateLabel, '31.12');
    });
    test('single-digit day/month zero-padded', () {
      final r = PassengerRequestItem.fromJson({'id': 'r5', 'departureDate': '2026-01-09T12:00:00Z'});
      expect(r.dateLabel, '09.01');
    });
  });

  group('PassengerRequestItem — numeric coercion', () {
    test('budget accepts double', () {
      final r = PassengerRequestItem.fromJson({'id': 'r6', 'budget': 750.0});
      expect(r.budget, 750);
    });
    test('passengerRating from int', () {
      final r = PassengerRequestItem.fromJson({'id': 'r7', 'passenger': {'rating': 5}});
      expect(r.passengerRating, 5.0);
    });
  });
}
