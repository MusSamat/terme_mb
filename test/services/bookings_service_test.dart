import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tappjet_mb/api/services/bookings_service.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> data, {int status = 200}) => Response(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
      data: data,
    );

void main() {
  late MockDio dio;
  late BookingsService svc;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    dio = MockDio();
    svc = BookingsService(dio);
  });

  group('mine', () {
    test('GET /bookings/my with status + cursor', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': []}));
      await svc.mine(status: 'accepted', cursor: 'c1');
      final q = verify(() => dio.get<Map<String, dynamic>>('/bookings/my',
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(q['status'], 'accepted');
      expect(q['cursor'], 'c1');
    });

    test('omits null status/cursor', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': []}));
      await svc.mine();
      final q = verify(() => dio.get<Map<String, dynamic>>('/bookings/my',
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(q.isEmpty, true);
    });

    test('parses booking rows', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'data': [
                  {'id': 'b1', 'status': 'pending', 'seatsCount': 2, 'trip': {'originCity': 'A', 'destinationCity': 'B'}},
                ],
              }));
      final page = await svc.mine();
      expect(page.data.single.id, 'b1');
      expect(page.data.single.seats, 2);
    });
  });

  group('incoming', () {
    test('GET /bookings/incoming with tripId', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': []}));
      await svc.incoming(tripId: 't1');
      final q = verify(() => dio.get<Map<String, dynamic>>('/bookings/incoming',
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(q['tripId'], 't1');
    });
  });

  group('create', () {
    test('returns the created booking id', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok({'id': 'bk-42'}, status: 201));
      final id = await svc.create(tripId: 't1', seats: 2);
      expect(id, 'bk-42');
    });

    test('sends tripId + seatsCount in the body', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok({'id': 'x'}));
      await svc.create(tripId: 't7', seats: 3);
      final body = verify(() => dio.post<Map<String, dynamic>>('/bookings',
          data: captureAny(named: 'data'), options: any(named: 'options'))).captured.single as Map;
      expect(body['tripId'], 't7');
      expect(body['seatsCount'], 3);
    });

    test('includes comment only when provided', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok({'id': 'x'}));
      await svc.create(tripId: 't1', seats: 1, comment: 'hi');
      final body = verify(() => dio.post<Map<String, dynamic>>(any(),
          data: captureAny(named: 'data'), options: any(named: 'options'))).captured.single as Map;
      expect(body['comment'], 'hi');
    });

    test('omits comment when null', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok({'id': 'x'}));
      await svc.create(tripId: 't1', seats: 1);
      final body = verify(() => dio.post<Map<String, dynamic>>(any(),
          data: captureAny(named: 'data'), options: any(named: 'options'))).captured.single as Map;
      expect(body.containsKey('comment'), false);
    });

    test('carries an Idempotency-Key header', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok({'id': 'x'}));
      await svc.create(tripId: 't1', seats: 1);
      final opts = verify(() => dio.post<Map<String, dynamic>>(any(),
          data: any(named: 'data'), options: captureAny(named: 'options'))).captured.single as Options;
      expect(opts.headers?['Idempotency-Key'], isNotNull);
    });

    test('null id tolerated (returns null)', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok({}));
      expect(await svc.create(tripId: 't1', seats: 1), isNull);
    });
  });

  group('lifecycle verbs', () {
    test('accept → PATCH /bookings/{id}/accept', () async {
      when(() => dio.patch<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.accept('b1');
      verify(() => dio.patch<dynamic>('/bookings/b1/accept')).called(1);
    });
    test('reject → PATCH /bookings/{id}/reject', () async {
      when(() => dio.patch<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.reject('b1');
      verify(() => dio.patch<dynamic>('/bookings/b1/reject')).called(1);
    });
    test('cancel → PATCH /bookings/{id}/cancel', () async {
      when(() => dio.patch<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.cancel('b1');
      verify(() => dio.patch<dynamic>('/bookings/b1/cancel')).called(1);
    });
  });
}
