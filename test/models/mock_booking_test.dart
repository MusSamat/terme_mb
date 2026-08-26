import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/data/mock_app_data.dart';

void main() {
  group('MockBooking.fromJson — as passenger (other = trip.driver)', () {
    final b = MockBooking.fromJson({
      'id': 'b1',
      'seatsCount': 2,
      'status': 'accepted',
      'totalPrice': 2400,
      'comment': 'у автовокзала',
      'trip': {
        'originCity': 'Бишкек',
        'destinationCity': 'Ош',
        'departureAt': '2026-08-10T12:00:00Z',
        'pricePerSeat': 1200,
        'driver': {'name': 'Азамат', 'verified': true, 'phone': '+996700'},
      },
    });

    test('id', () => expect(b.id, 'b1'));
    test('seats', () => expect(b.seats, 2));
    test('status', () => expect(b.status, 'accepted'));
    test('sum from totalPrice', () => expect(b.sum, 2400));
    test('otherName from driver', () => expect(b.otherName, 'Азамат'));
    test('origin', () => expect(b.origin, 'Бишкек'));
    test('destination', () => expect(b.destination, 'Ош'));
    test('dateLabel dd.MM from departureAt', () => expect(b.dateLabel, '10.08'));
    test('verified from driver', () => expect(b.verified, true));
    test('phone from driver', () => expect(b.phone, '+996700'));
    test('comment', () => expect(b.comment, 'у автовокзала'));
  });

  group('MockBooking.fromJson — tripId (for pending-rating match)', () {
    test('reads trip.id when tripId absent', () {
      final b = MockBooking.fromJson({'id': 'b1', 'trip': {'id': 't9'}});
      expect(b.tripId, 't9');
    });
    test('top-level tripId wins', () {
      final b = MockBooking.fromJson({'id': 'b1', 'tripId': 't-top', 'trip': {'id': 't9'}});
      expect(b.tripId, 't-top');
    });
    test('null when neither present', () {
      expect(MockBooking.fromJson({'id': 'b1'}).tripId, isNull);
    });
  });

  group('MockBooking.fromJson — passenger overrides driver as "other"', () {
    final b = MockBooking.fromJson({
      'id': 'b2',
      'passenger': {'name': 'Айгуль', 'verified': false},
      'trip': {'originCity': 'Ош', 'destinationCity': 'Бишкек', 'driver': {'name': 'IGNORED'}},
    });
    test('otherName comes from passenger, not driver', () => expect(b.otherName, 'Айгуль'));
  });

  group('MockBooking.fromJson — defaults', () {
    final b = MockBooking.fromJson({'id': 'b3'});
    test('seats defaults 1', () => expect(b.seats, 1));
    test('status defaults pending', () => expect(b.status, 'pending'));
    test('sum defaults 0', () => expect(b.sum, 0));
    test('otherName empty', () => expect(b.otherName, ''));
    test('origin empty', () => expect(b.origin, ''));
    test('dateLabel empty when no departureAt', () => expect(b.dateLabel, ''));
    test('verified false', () => expect(b.verified, false));
    test('phone null', () => expect(b.phone, isNull));
  });

  group('MockBooking.fromJson — sum fallback to trip.pricePerSeat', () {
    test('uses pricePerSeat when totalPrice absent', () {
      final b = MockBooking.fromJson({'id': 'b4', 'trip': {'pricePerSeat': 999}});
      expect(b.sum, 999);
    });
  });

  group('mockBookings sample', () {
    test('is non-empty', () => expect(mockBookings(), isNotEmpty));
    test('first is the accepted booking with a phone', () {
      final first = mockBookings().first;
      expect(first.status, 'accepted');
      expect(first.phone, isNotNull);
    });
  });
}
