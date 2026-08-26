import 'package:flutter_test/flutter_test.dart';
import 'package:tappjet_mb/models/request_response.dart';
import 'package:tappjet_mb/models/pending_rating.dart';
import 'package:tappjet_mb/models/driver_stats.dart';

void main() {
  group('RequestResponse.fromJson', () {
    final r = RequestResponse.fromJson({
      'id': 'resp1',
      'requestId': 'r1',
      'driverId': 'd1',
      'price': 900,
      'departureTime': '08:00',
      'message': 'могу подвезти',
      'status': 'pending',
      'bookingId': null,
      'expiresAt': '2026-08-05T00:00:00Z',
      'createdAt': '2026-08-04T10:00:00Z',
      'driver': {'id': 'd1', 'name': 'Азамат', 'rating': 4.8, 'ratingCount': 20, 'verified': true},
    });

    test('id', () => expect(r.id, 'resp1'));
    test('requestId', () => expect(r.requestId, 'r1'));
    test('driverId', () => expect(r.driverId, 'd1'));
    test('price', () => expect(r.price, 900));
    test('departureTime', () => expect(r.departureTime, '08:00'));
    test('message', () => expect(r.message, 'могу подвезти'));
    test('status', () => expect(r.status, 'pending'));
    test('bookingId null', () => expect(r.bookingId, isNull));
    test('driver nested', () => expect(r.driver.name, 'Азамат'));
    test('driver verified', () => expect(r.driver.verified, true));
    test('isPending true', () => expect(r.isPending, true));
  });

  group('RequestResponse.fromJson — defaults', () {
    final r = RequestResponse.fromJson({'id': 'x'});
    test('price → 0', () => expect(r.price, 0));
    test('status → pending', () => expect(r.status, 'pending'));
    test('message null', () => expect(r.message, isNull));
    test('driver blank', () => expect(r.driver.name, ''));
    test('price coerces double', () {
      expect(RequestResponse.fromJson({'id': 'x', 'price': 750.0}).price, 750);
    });
    test('isPending false when accepted', () {
      expect(RequestResponse.fromJson({'id': 'x', 'status': 'accepted'}).isPending, false);
    });
  });

  group('PendingRating.fromJson', () {
    final p = PendingRating.fromJson({
      'tripId': 't1',
      'counterpartId': 'u2',
      'counterpartName': 'Айгуль',
      'direction': 'driver',
      'departureAt': '2026-08-01T07:00:00Z',
      'expiresAt': '2026-08-08T07:00:00Z',
    });
    test('tripId', () => expect(p.tripId, 't1'));
    test('counterpartId', () => expect(p.counterpartId, 'u2'));
    test('counterpartName', () => expect(p.counterpartName, 'Айгуль'));
    test('direction', () => expect(p.direction, 'driver'));
    test('departureAt', () => expect(p.departureAt, '2026-08-01T07:00:00Z'));
  });

  group('PendingRating.fromJson — defaults', () {
    final p = PendingRating.fromJson({'tripId': 't2'});
    test('counterpartName empty', () => expect(p.counterpartName, ''));
    test('direction defaults passenger', () => expect(p.direction, 'passenger'));
  });

  group('DriverStats.fromJson', () {
    final s = DriverStats.fromJson({'totalTrips': 42, 'rating': 4.9, 'ratingCount': 30, 'cancellations30d': 1});
    test('totalTrips', () => expect(s.totalTrips, 42));
    test('rating', () => expect(s.rating, 4.9));
    test('ratingCount', () => expect(s.ratingCount, 30));
    test('cancellations30d', () => expect(s.cancellations30d, 1));
  });

  group('DriverStats.fromJson — defaults', () {
    final s = DriverStats.fromJson({});
    test('totalTrips 0', () => expect(s.totalTrips, 0));
    test('rating null', () => expect(s.rating, isNull));
    test('ratingCount 0', () => expect(s.ratingCount, 0));
    test('cancellations30d 0', () => expect(s.cancellations30d, 0));
    test('rating from int', () {
      expect(DriverStats.fromJson({'rating': 5}).rating, 5.0);
    });
  });
}
