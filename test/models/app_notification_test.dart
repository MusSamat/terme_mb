import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/models/app_notification.dart';

void main() {
  group('notifDeepLink — trip_cancelled', () {
    test('payload {trip: PublicTrip} links to the trip', () {
      expect(notifDeepLink('trip_cancelled', {
        'trip': {'id': 't1', 'originCity': 'Бишкек', 'destinationCity': 'Ош'}
      }), '/trips/t1');
    });
    test('legacy flat tripId still works', () {
      expect(notifDeepLink('trip_cancelled', {'tripId': 't2'}), '/trips/t2');
    });
    test('no id → home', () {
      expect(notifDeepLink('trip_cancelled', const {}), '/');
    });
  });
}
