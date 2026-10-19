import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:terme_mb/api/services/trips_service.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> data) => Response(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: 200,
      data: data,
    );

Map<String, dynamic> _tripJson(String id) => {
      'id': id,
      'originCity': 'Бишкек',
      'destinationCity': 'Ош',
      'departureAt': '2026-08-10T07:30:00+06:00',
      'seatsAvailable': 3,
      'seatsTotal': 4,
      'pricePerSeat': 1000,
      'driver': {'id': 'd1', 'name': 'Азамат'},
    };

void main() {
  late MockDio dio;
  late TripsService svc;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(RequestOptions(path: '/'));
  });

  setUp(() {
    dio = MockDio();
    svc = TripsService(dio);
  });

  group('list — query params', () {
    setUp(() {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'data': [_tripJson('t1')],
                'nextCursor': 'c1',
              }));
    });

    test('hits /trips and parses paged result', () async {
      final page = await svc.list(const {});
      expect(page.data.single.id, 't1');
      expect(page.nextCursor, 'c1');
      verify(() => dio.get<Map<String, dynamic>>('/trips', queryParameters: any(named: 'queryParameters'))).called(1);
    });

    test('query map is forwarded as-is (place ids, filters)', () async {
      await svc.list({'from_id': 1, 'to_id': 2, 'kind': 'airport', 'sort': 'price_asc'});
      final captured = verify(() => dio.get<Map<String, dynamic>>(any(),
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(captured['from_id'], 1);
      expect(captured['to_id'], 2);
      expect(captured['kind'], 'airport');
      expect(captured['sort'], 'price_asc');
      expect(captured.containsKey('cursor'), false);
    });

    test('cursor is appended', () async {
      await svc.list({'date': '2026-08-10T00:00:00+06:00'}, cursor: 'cur');
      final captured = verify(() => dio.get<Map<String, dynamic>>(any(),
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(captured['date'], '2026-08-10T00:00:00+06:00');
      expect(captured['cursor'], 'cur');
    });
  });

  group('calendar', () {
    test('flattens {date,count} rows into a map', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'data': [
                  {'date': '2026-08-10', 'count': 3},
                  {'date': '2026-08-11', 'count': 0},
                ],
              }));
      final cal = await svc.calendar(1, 2);
      expect(cal, {'2026-08-10': 3, '2026-08-11': 0});
      final q = verify(() => dio.get<Map<String, dynamic>>('/trips/calendar',
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(q, {'from_id': 1, 'to_id': 2});
    });

    test('empty data → empty map', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': []}));
      expect(await svc.calendar(1, 2), isEmpty);
    });
  });

  group('detail', () {
    test('GET /trips/{id} parses a single trip', () async {
      when(() => dio.get<Map<String, dynamic>>('/trips/t9')).thenAnswer((_) async => _ok(_tripJson('t9')));
      final t = await svc.detail('t9');
      expect(t.id, 't9');
      verify(() => dio.get<Map<String, dynamic>>('/trips/t9')).called(1);
    });
  });

  group('mine', () {
    test('forwards tab + cursor', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': []}));
      await svc.mine(tab: 'active', cursor: 'c');
      final captured = verify(() => dio.get<Map<String, dynamic>>('/trips/my',
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(captured['tab'], 'active');
      expect(captured['cursor'], 'c');
    });
  });

  group('create — idempotency', () {
    test('POST /trips carries an Idempotency-Key header', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok(_tripJson('new')));
      final t = await svc.create({'originCity': 'A'});
      expect(t.id, 'new');
      final opts = verify(() => dio.post<Map<String, dynamic>>('/trips',
          data: any(named: 'data'), options: captureAny(named: 'options'))).captured.single as Options;
      expect(opts.headers?['Idempotency-Key'], isNotNull);
      expect((opts.headers!['Idempotency-Key'] as String).length, greaterThan(10));
    });

    test('a caller-supplied key is sent as-is (retry reuses it)', () async {
      when(() => dio.post<Map<String, dynamic>>(any(),
              data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok(_tripJson('new')));
      await svc.create({'originCity': 'A'}, idempotencyKey: 'key-123');
      final opts = verify(() => dio.post<Map<String, dynamic>>('/trips',
          data: any(named: 'data'), options: captureAny(named: 'options'))).captured.single as Options;
      expect(opts.headers?['Idempotency-Key'], 'key-123');
    });
  });

  group('like / unlike / view verbs', () {
    test('like → POST /trips/{id}/like', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.like('t1');
      verify(() => dio.post<dynamic>('/trips/t1/like')).called(1);
    });
    test('unlike → DELETE /trips/{id}/like', () async {
      when(() => dio.delete<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.unlike('t1');
      verify(() => dio.delete<dynamic>('/trips/t1/like')).called(1);
    });
    test('recordView → POST /trips/{id}/view', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.recordView('t1');
      verify(() => dio.post<dynamic>('/trips/t1/view')).called(1);
    });
  });

  group('owner management verbs', () {
    test('edit → PATCH /trips/{id} with patch body', () async {
      when(() => dio.patch<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.edit('t1', {'pricePerSeat': 1500});
      verify(() => dio.patch<dynamic>('/trips/t1', data: {'pricePerSeat': 1500})).called(1);
    });
    test('cancel → DELETE /trips/{id} with reason', () async {
      when(() => dio.delete<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.cancel('t1', reason: 'no passengers');
      final data = verify(() => dio.delete<dynamic>('/trips/t1', data: captureAny(named: 'data'))).captured.single as Map;
      expect(data['reason'], 'no passengers');
    });
    test('cancel without reason omits it', () async {
      when(() => dio.delete<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.cancel('t1');
      final data = verify(() => dio.delete<dynamic>('/trips/t1', data: captureAny(named: 'data'))).captured.single as Map;
      expect(data.containsKey('reason'), false);
    });
    test('complete → PATCH /trips/{id}/complete', () async {
      when(() => dio.patch<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.complete('t1');
      verify(() => dio.patch<dynamic>('/trips/t1/complete')).called(1);
    });
  });
}
