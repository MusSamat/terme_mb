import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/models/booking.dart';

void main() {
  group('Booking.fromJson — as passenger (other = trip.driver)', () {
    final b = Booking.fromJson({
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
        'driver': {'name': 'Азамат', 'ratingCount': 5, 'phone': '+996700'},
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
    test('verified = driver has ratings', () => expect(b.verified, true));
    test('phone from driver', () => expect(b.phone, '+996700'));
    test('comment', () => expect(b.comment, 'у автовокзала'));
  });

  group('Booking.fromJson — tripId (for pending-rating match)', () {
    test('reads trip.id when tripId absent', () {
      final b = Booking.fromJson({'id': 'b1', 'trip': {'id': 't9'}});
      expect(b.tripId, 't9');
    });
    test('top-level tripId wins', () {
      final b = Booking.fromJson({'id': 'b1', 'tripId': 't-top', 'trip': {'id': 't9'}});
      expect(b.tripId, 't-top');
    });
    test('null when neither present', () {
      expect(Booking.fromJson({'id': 'b1'}).tripId, isNull);
    });
  });

  group('Booking.fromJson — counterpart side', () {
    final j = {
      'id': 'b2',
      'passengerId': 'me',
      'passenger': {'name': 'Айгуль', 'phone': '+996555'},
      'trip': {'originCity': 'Ош', 'destinationCity': 'Бишкек', 'driver': {'name': 'Азамат', 'phone': '+996700'}},
    };
    test('/bookings/my → driver (the DTO also carries me as passenger)', () {
      final b = Booking.fromJson(j);
      expect(b.otherName, 'Азамат');
      expect(b.phone, '+996700');
    });
    test('incoming → passenger', () => expect(Booking.fromJson(j, incoming: true).otherName, 'Айгуль'));
    test('selfId = passenger → driver', () => expect(Booking.fromJson(j, selfId: 'me').otherName, 'Азамат'));
    test('selfId = driver → passenger', () => expect(Booking.fromJson(j, selfId: 'drv').otherName, 'Айгуль'));
  });

  group('Booking.fromJson — defaults', () {
    final b = Booking.fromJson({'id': 'b3'});
    test('seats defaults 1', () => expect(b.seats, 1));
    test('status defaults pending', () => expect(b.status, 'pending'));
    test('sum defaults 0', () => expect(b.sum, 0));
    test('otherName empty', () => expect(b.otherName, ''));
    test('origin empty', () => expect(b.origin, ''));
    test('dateLabel empty when no departureAt', () => expect(b.dateLabel, ''));
    test('verified false', () => expect(b.verified, false));
    test('phone null', () => expect(b.phone, isNull));
  });

  group('Booking.fromJson — sum fallback to trip.pricePerSeat', () {
    test('uses pricePerSeat when totalPrice absent', () {
      final b = Booking.fromJson({'id': 'b4', 'trip': {'pricePerSeat': 999}});
      expect(b.sum, 999);
    });
  });

  group('Booking.fromJson — trip place refs (RU/KG names)', () {
    final b = Booking.fromJson({
      'id': 'b2',
      'trip': {
        'originCity': 'Бишкек',
        'destinationCity': 'Нарын',
        'originCityId': 1,
        'destinationCityId': 7,
        'origin': {'id': 1, 'type': 'capital', 'nameRu': 'Бишкек', 'nameKg': 'Бишкек'},
        'destination': {'id': 7, 'type': 'city', 'nameRu': 'Нарын', 'nameKg': 'Нарын шаары'},
      },
    });
    test('kg → nameKg', () => expect(b.destinationName(true), 'Нарын шаары'));
    test('ru → nameRu', () => expect(b.destinationName(false), 'Нарын'));
    test('origin place parsed', () => expect(b.originPlace?.id, 1));

    test('legacy DTO without refs falls back to the RU snapshot', () {
      final old = Booking.fromJson({'id': 'b3', 'trip': {'originCity': 'Ош', 'destinationCity': 'Баткен'}});
      expect(old.originName(true), 'Ош');
      expect(old.destinationName(true), 'Баткен');
    });
  });
}

