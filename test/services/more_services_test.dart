import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:terme_mb/api/services/cars_service.dart';
import 'package:terme_mb/api/services/requests_service.dart';
import 'package:terme_mb/api/services/users_service.dart';
import 'package:terme_mb/api/services/ratings_service.dart';
import 'package:terme_mb/api/services/misc_services.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> data) =>
    Response(requestOptions: RequestOptions(path: '/x'), statusCode: 200, data: data);

void main() {
  late MockDio dio;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(RequestOptions(path: '/'));
  });
  setUp(() => dio = MockDio());

  // ── CarsService ────────────────────────────────────────────────────────────
  group('CarsService', () {
    late CarsService svc;
    setUp(() => svc = CarsService(dio));

    test('list parses /cars data rows', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((_) async => _ok({
            'data': [
              {'id': 'c1', 'make': 'Kia', 'model': 'Rio', 'plate': 'X'},
            ],
          }));
      final cars = await svc.list();
      expect(cars.single.title, 'Kia Rio');
      verify(() => dio.get<Map<String, dynamic>>('/cars')).called(1);
    });

    test('list tolerates missing data → empty', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((_) async => _ok({}));
      expect(await svc.list(), isEmpty);
    });

    test('create posts the car and parses result', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({'id': 'c9', 'make': 'Toyota', 'model': 'Camry', 'plate': 'P'}));
      final car = await svc.create(make: 'Toyota', model: 'Camry', plate: 'P', color: 'белый', seatsCount: 3);
      expect(car.id, 'c9');
      final body = verify(() => dio.post<Map<String, dynamic>>('/cars', data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['make'], 'Toyota');
      expect(body['color'], 'белый');
      expect(body['seatsCount'], 3);
    });

    test('create omits empty color', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({'id': 'c', 'make': 'A', 'model': 'B', 'plate': 'P'}));
      await svc.create(make: 'A', model: 'B', plate: 'P', color: '');
      final body = verify(() => dio.post<Map<String, dynamic>>(any(), data: captureAny(named: 'data'))).captured.single as Map;
      expect(body.containsKey('color'), false);
    });

    test('create defaults seatsCount to 4', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({'id': 'c', 'make': 'A', 'model': 'B', 'plate': 'P'}));
      await svc.create(make: 'A', model: 'B', plate: 'P');
      final body = verify(() => dio.post<Map<String, dynamic>>(any(), data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['seatsCount'], 4);
    });

    test('remove → DELETE /cars/{id}', () async {
      when(() => dio.delete<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.remove('c1');
      verify(() => dio.delete<dynamic>('/cars/c1')).called(1);
    });
  });

  // ── RequestsService ──────────────────────────────────────────────────────────
  group('RequestsService', () {
    late RequestsService svc;
    setUp(() => svc = RequestsService(dio));

    test('list maps from/to to from_city/to_city', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': []}));
      await svc.list(from: 'Бишкек', to: 'Ош', date: 'd');
      final q = verify(() => dio.get<Map<String, dynamic>>('/passenger-requests',
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(q['from_city'], 'Бишкек');
      expect(q['to_city'], 'Ош');
      expect(q['date'], 'd');
    });

    test('detail → GET /passenger-requests/{id}', () async {
      when(() => dio.get<Map<String, dynamic>>('/passenger-requests/r1'))
          .thenAnswer((_) async => _ok({'id': 'r1', 'originCity': 'A', 'destinationCity': 'B'}));
      final r = await svc.detail('r1');
      expect(r.id, 'r1');
    });

    test('calendar flattens rows', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': [{'date': '2026-08-10', 'count': 4}]}));
      expect(await svc.calendar('A', 'B'), {'2026-08-10': 4});
    });

    test('create carries Idempotency-Key', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data'), options: any(named: 'options')))
          .thenAnswer((_) async => _ok({'id': 'r2', 'originCity': 'A', 'destinationCity': 'B'}));
      await svc.create({'originCity': 'A'});
      final opts = verify(() => dio.post<Map<String, dynamic>>('/passenger-requests',
          data: any(named: 'data'), options: captureAny(named: 'options'))).captured.single as Options;
      expect(opts.headers?['Idempotency-Key'], isNotNull);
    });

    test('respond posts price + optional fields', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.respond('r1', price: 900, departureTime: '08:00', message: 'ок');
      final body = verify(() => dio.post<dynamic>('/passenger-requests/r1/respond',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['price'], 900);
      expect(body['departureTime'], '08:00');
      expect(body['message'], 'ок');
    });

    test('respond omits null optional fields', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.respond('r1', price: 900);
      final body = verify(() => dio.post<dynamic>(any(), data: captureAny(named: 'data'))).captured.single as Map;
      expect(body.containsKey('departureTime'), false);
      expect(body.containsKey('message'), false);
    });

    test('like → POST, unlike → DELETE', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => _ok({}));
      when(() => dio.delete<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.like('r1');
      await svc.unlike('r1');
      verify(() => dio.post<dynamic>('/passenger-requests/r1/like')).called(1);
      verify(() => dio.delete<dynamic>('/passenger-requests/r1/like')).called(1);
    });

    test('revealContact returns phone', () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenAnswer((_) async => _ok({'phone': '+996700'}));
      expect(await svc.revealContact('r1'), '+996700');
    });

    test('revealContact null when no phone', () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenAnswer((_) async => _ok({}));
      expect(await svc.revealContact('r1'), isNull);
    });
  });

  // ── UsersService ─────────────────────────────────────────────────────────────
  group('UsersService', () {
    late UsersService svc;
    setUp(() => svc = UsersService(dio));

    test('publicProfile → GET /users/{id}', () async {
      when(() => dio.get<Map<String, dynamic>>('/users/u1'))
          .thenAnswer((_) async => _ok({'id': 'u1', 'name': 'Тест', 'roles': ['driver']}));
      final u = await svc.publicProfile('u1');
      expect(u.isDriver, true);
    });

    test('ratings parses review rows', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'data': [
                  {'id': 'rev1', 'score': 5, 'rater': {'name': 'M'}},
                ],
              }));
      final rs = await svc.ratings('u1');
      expect(rs.single.score, 5);
      expect(rs.single.raterName, 'M');
    });

    test('ratings forwards cursor', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'data': []}));
      await svc.ratings('u1', cursor: 'c2');
      final q = verify(() => dio.get<Map<String, dynamic>>('/users/u1/ratings',
          queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;
      expect(q['cursor'], 'c2');
    });
  });

  // ── RatingsService ───────────────────────────────────────────────────────────
  group('RatingsService', () {
    late RatingsService svc;
    setUp(() => svc = RatingsService(dio));

    test('create posts trip/ratee/score/tags', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.create(tripId: 't1', rateeId: 'u2', score: 5, tags: ['punctual'], comment: 'спасибо');
      final body = verify(() => dio.post<dynamic>('/ratings', data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['tripId'], 't1');
      expect(body['rateeId'], 'u2');
      expect(body['score'], 5);
      expect(body['tags'], ['punctual']);
      expect(body['comment'], 'спасибо');
    });

    test('create omits empty comment', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.create(tripId: 't1', rateeId: 'u2', score: 4, comment: '');
      final body = verify(() => dio.post<dynamic>(any(), data: captureAny(named: 'data'))).captured.single as Map;
      expect(body.containsKey('comment'), false);
    });

    test('create defaults tags to empty list', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.create(tripId: 't1', rateeId: 'u2', score: 3);
      final body = verify(() => dio.post<dynamic>(any(), data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['tags'], isEmpty);
    });
  });

  // ── ChatService ──────────────────────────────────────────────────────────────
  group('ChatService', () {
    late ChatService svc;
    setUp(() => svc = ChatService(dio));

    test('messages returns the data list', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({
                'data': [
                  {'id': 'm1', 'text': 'hi'},
                ],
              }));
      final msgs = await svc.messages('b1');
      expect(msgs.single['text'], 'hi');
    });

    test('sendMessage posts text and returns the message row', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({'message': {'id': 'm2', 'text': 'yo'}}));
      final m = await svc.sendMessage('b1', 'yo');
      expect(m['id'], 'm2');
      final body = verify(() => dio.post<Map<String, dynamic>>('/chats/b1/messages',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['text'], 'yo');
    });

    test('sendMessage tolerates missing message → empty map', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({}));
      expect(await svc.sendMessage('b1', 'x'), isEmpty);
    });

    test('markRead → PATCH /messages/{id}/read', () async {
      when(() => dio.patch<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.markRead('m1');
      verify(() => dio.patch<dynamic>('/messages/m1/read')).called(1);
    });

    test('unreadTotal sums the counts map', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => _ok({'counts': {'b1': 2, 'b2': 3}}));
      expect(await svc.unreadTotal(), 5);
    });

    test('unreadTotal → 0 when counts absent', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((_) async => _ok({}));
      expect(await svc.unreadTotal(), 0);
    });
  });
}
