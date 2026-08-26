import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tappjet_mb/api/services/requests_service.dart';
import 'package:tappjet_mb/api/services/bookings_service.dart';
import 'package:tappjet_mb/api/services/ratings_service.dart';
import 'package:tappjet_mb/api/services/drivers_service.dart';
import 'package:tappjet_mb/api/services/trips_service.dart';
import 'package:tappjet_mb/api/services/profile_service.dart';
import 'package:tappjet_mb/api/services/misc_services.dart';
import 'package:tappjet_mb/api/services/likes_service.dart';

class MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T? data) =>
    Response<T>(requestOptions: RequestOptions(path: '/x'), statusCode: 200, data: data);

void main() {
  late MockDio dio;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(RequestOptions(path: '/'));
  });
  setUp(() => dio = MockDio());

  // ── RequestsService: responses flow + cancel + view ──────────────────────────
  group('RequestsService parity', () {
    late RequestsService svc;
    setUp(() => svc = RequestsService(dio));

    test('cancel → DELETE /passenger-requests/{id}', () async {
      when(() => dio.delete<dynamic>(any())).thenAnswer((_) async => _ok<dynamic>(null));
      await svc.cancel('r1');
      verify(() => dio.delete<dynamic>('/passenger-requests/r1')).called(1);
    });

    test('recordView → POST /passenger-requests/{id}/view', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => _ok<dynamic>(null));
      await svc.recordView('r1');
      verify(() => dio.post<dynamic>('/passenger-requests/r1/view')).called(1);
    });

    test('responses parses a bare array', () async {
      when(() => dio.get<List<dynamic>>(any())).thenAnswer((_) async => _ok<List<dynamic>>([
            {'id': 'resp1', 'price': 900, 'driver': {'name': 'A'}},
            {'id': 'resp2', 'price': 800, 'driver': {'name': 'B'}},
          ]));
      final rs = await svc.responses('r1');
      expect(rs.map((e) => e.id), ['resp1', 'resp2']);
      expect(rs.first.driver.name, 'A');
      verify(() => dio.get<List<dynamic>>('/passenger-requests/r1/responses')).called(1);
    });

    test('responses tolerates null body → empty', () async {
      when(() => dio.get<List<dynamic>>(any())).thenAnswer((_) async => _ok<List<dynamic>>(null));
      expect(await svc.responses('r1'), isEmpty);
    });

    test('acceptResponse returns bookingId', () async {
      when(() => dio.post<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => _ok<Map<String, dynamic>>({'bookingId': 'bk-1'}));
      final id = await svc.acceptResponse('r1', 'resp1');
      expect(id, 'bk-1');
      verify(() => dio.post<Map<String, dynamic>>('/passenger-requests/r1/respond/resp1/accept')).called(1);
    });

    test('acceptResponse null when body lacks bookingId', () async {
      when(() => dio.post<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => _ok<Map<String, dynamic>>({}));
      expect(await svc.acceptResponse('r1', 'resp1'), isNull);
    });

    test('declineResponse → POST decline', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => _ok<dynamic>(null));
      await svc.declineResponse('r1', 'resp1');
      verify(() => dio.post<dynamic>('/passenger-requests/r1/respond/resp1/decline')).called(1);
    });
  });

  // ── BookingsService: get + markNoShow ────────────────────────────────────────
  group('BookingsService parity', () {
    late BookingsService svc;
    setUp(() => svc = BookingsService(dio));

    test('get → GET /bookings/{id} parses booking', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((_) async =>
          _ok<Map<String, dynamic>>({'id': 'b9', 'status': 'accepted', 'seatsCount': 2, 'trip': {'originCity': 'A'}}));
      final b = await svc.get('b9');
      expect(b.id, 'b9');
      expect(b.seats, 2);
      verify(() => dio.get<Map<String, dynamic>>('/bookings/b9')).called(1);
    });

    test('markNoShow → PATCH /bookings/{id}/no-show', () async {
      when(() => dio.patch<dynamic>(any())).thenAnswer((_) async => _ok<dynamic>(null));
      await svc.markNoShow('b1');
      verify(() => dio.patch<dynamic>('/bookings/b1/no-show')).called(1);
    });
  });

  // ── RatingsService: pending ──────────────────────────────────────────────────
  group('RatingsService parity', () {
    late RatingsService svc;
    setUp(() => svc = RatingsService(dio));

    test('pending parses the data list', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((_) async => _ok<Map<String, dynamic>>({
            'data': [
              {'tripId': 't1', 'counterpartName': 'A', 'direction': 'driver'},
            ],
          }));
      final ps = await svc.pending();
      expect(ps.single.tripId, 't1');
      expect(ps.single.direction, 'driver');
      verify(() => dio.get<Map<String, dynamic>>('/ratings/pending')).called(1);
    });

    test('pending empty when no data', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((_) async => _ok<Map<String, dynamic>>({}));
      expect(await svc.pending(), isEmpty);
    });
  });

  // ── DriversService: stats ────────────────────────────────────────────────────
  group('DriversService parity', () {
    late DriversService svc;
    setUp(() => svc = DriversService(dio));

    test('stats → GET /drivers/me/stats', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((_) async =>
          _ok<Map<String, dynamic>>({'totalTrips': 12, 'rating': 4.7, 'ratingCount': 9, 'cancellations30d': 0}));
      final s = await svc.stats();
      expect(s.totalTrips, 12);
      expect(s.rating, 4.7);
      verify(() => dio.get<Map<String, dynamic>>('/drivers/me/stats')).called(1);
    });
  });

  // ── TripsService: priceSuggestion ────────────────────────────────────────────
  group('TripsService.priceSuggestion', () {
    late TripsService svc;
    setUp(() => svc = TripsService(dio));

    test('GET /routes/price-suggestion with from/to and parses tuple', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok<Map<String, dynamic>>({'suggested': 1000, 'min': 800, 'max': 1500}));
      final r = await svc.priceSuggestion('Бишкек', 'Ош');
      expect(r.suggested, 1000);
      expect(r.min, 800);
      expect(r.max, 1500);
      final q = verify(() => dio.get<Map<String, dynamic>>('/routes/price-suggestion',
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(q['from'], 'Бишкек');
      expect(q['to'], 'Ош');
    });

    test('defaults to 0 when fields missing', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok<Map<String, dynamic>>({}));
      final r = await svc.priceSuggestion('A', 'B');
      expect(r.suggested, 0);
    });
  });

  // ── ProfileService: exportData ───────────────────────────────────────────────
  group('ProfileService.exportData', () {
    late ProfileService svc;
    setUp(() => svc = ProfileService(dio));

    test('GET /users/me/export as bytes', () async {
      when(() => dio.get<List<int>>(any(), options: any(named: 'options')))
          .thenAnswer((_) async => _ok<List<int>>([1, 2, 3]));
      final bytes = await svc.exportData();
      expect(bytes, [1, 2, 3]);
      final opts = verify(() => dio.get<List<int>>('/users/me/export',
          options: captureAny(named: 'options'))).captured.single as Options;
      expect(opts.responseType, ResponseType.bytes);
    });

    test('null body → empty bytes', () async {
      when(() => dio.get<List<int>>(any(), options: any(named: 'options')))
          .thenAnswer((_) async => _ok<List<int>>(null));
      expect(await svc.exportData(), isEmpty);
    });
  });

  // ── ChatService: markAllRead ─────────────────────────────────────────────────
  group('ChatService.markAllRead', () {
    late ChatService svc;
    setUp(() => svc = ChatService(dio));

    test('PATCH /chats/{id}/read-all', () async {
      when(() => dio.patch<dynamic>(any())).thenAnswer((_) async => _ok<dynamic>(null));
      await svc.markAllRead('b1');
      verify(() => dio.patch<dynamic>('/chats/b1/read-all')).called(1);
    });
  });

  // ── LikesService: trips + requests ───────────────────────────────────────────
  group('LikesService', () {
    late LikesService svc;
    setUp(() => svc = LikesService(dio));

    test('trips → GET /users/me/likes?type=trip', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok<Map<String, dynamic>>({
                'data': [
                  {'id': 't1', 'departureAt': '2026-08-10T07:30:00+06:00', 'driver': {'id': 'd', 'name': 'N'}},
                ],
                'nextCursor': 'c1',
              }));
      final page = await svc.trips();
      expect(page.data.single.id, 't1');
      expect(page.nextCursor, 'c1');
      final q = verify(() => dio.get<Map<String, dynamic>>('/users/me/likes',
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(q['type'], 'trip');
      expect(q['limit'], 20);
    });

    test('requests → GET /users/me/likes?type=passenger_request', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok<Map<String, dynamic>>({
                'data': [
                  {'id': 'r1', 'originCity': 'A', 'destinationCity': 'B'},
                ],
              }));
      final page = await svc.requests(cursor: 'cur');
      expect(page.data.single.id, 'r1');
      final q = verify(() => dio.get<Map<String, dynamic>>('/users/me/likes',
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(q['type'], 'passenger_request');
      expect(q['cursor'], 'cur');
    });
  });
}
