import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:terme_mb/api/services/misc_services.dart';
import 'package:terme_mb/api/services/profile_service.dart';

class MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T data) => Response<T>(requestOptions: RequestOptions(path: '/x'), statusCode: 200, data: data);

void main() {
  late MockDio dio;
  setUpAll(() => registerFallbackValue(RequestOptions(path: '/')));
  setUp(() => dio = MockDio());

  Map<dynamic, dynamic> captureQuery(String path) => verify(() => dio.get<Map<String, dynamic>>(path,
      queryParameters: captureAny(named: 'queryParameters'))).captured.single as Map;

  void stubGet(Map<String, dynamic> body) =>
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok(body));

  group('CitiesService', () {
    test('search trims q, empty query omits it', () async {
      stubGet({'data': [{'id': 1, 'type': 'capital', 'nameRu': 'Бишкек', 'nameKg': 'Бишкек'}]});
      final r = await CitiesService(dio).search('  ош ');
      expect(r.single.id, 1);
      expect(captureQuery('/cities')['q'], 'ош');
      await CitiesService(dio).search('');
      expect(captureQuery('/cities').containsKey('q'), false);
    });
    test('nearest → Place or null', () async {
      stubGet({'data': {'id': 7, 'type': 'town', 'nameRu': 'Кант', 'nameKg': 'Кант'}});
      expect((await CitiesService(dio).nearest(42.9, 74.8))?.id, 7);
      expect(captureQuery('/cities/nearest'), {'lat': 42.9, 'lng': 74.8});
      stubGet({'data': null});
      expect(await CitiesService(dio).nearest(0, 0), isNull);
    });
    test('spots hits /cities/{id}/spots', () async {
      stubGet({'data': [{'kind': 'area', 'nameRu': 'Асанбай', 'lat': 42.82, 'lng': 74.62}]});
      final r = await CitiesService(dio).spots(1, query: 'аса');
      expect(r.single.kind, 'area');
      expect(r.single.nameKg, 'Асанбай');
      expect(captureQuery('/cities/1/spots')['q'], 'аса');
    });
  });

  group('CitiesService — airports', () {
    test('search sends scope only with a query', () async {
      stubGet({'data': []});
      await CitiesService(dio).search('аламед', scope: 'any');
      expect(captureQuery('/cities')['scope'], 'any');
      await CitiesService(dio).search('', scope: 'any');
      expect(captureQuery('/cities').containsKey('scope'), false);
    });

    test('pickupSuggestion → /airports/{id}/pickup-suggestion with UTC flight time', () async {
      stubGet({
        'data': {
          'pickupAt': '2026-10-20T21:30:00.000Z',
          'travelMin': 30,
          'bufferMin': 150,
          'distanceKm': 24.6,
          'flightType': 'international',
        }
      });
      final s = await CitiesService(dio).pickupSuggestion(900,
          fromId: 1, flightTime: DateTime.utc(2026, 10, 21, 0, 30), flightType: 'international');
      expect(captureQuery('/cities/airports/900/pickup-suggestion'),
          {'from_id': 1, 'flight_time': '2026-10-21T00:30:00.000Z', 'flight_type': 'international'});
      expect((s.travelMin, s.bufferMin), (30, 150));
    });

    test('airports parse titles + popular chips', () async {
      stubGet({
        'data': [
          {
            'id': 900, 'type': 'airport', 'nameRu': 'Манас', 'nameKg': 'Манас',
            'titleRu': 'Манас · Бишкек', 'titleKg': 'Манас · Бишкек', 'flightType': 'international',
            'popularDestinations': [{'id': 1, 'type': 'capital', 'nameRu': 'Бишкек', 'nameKg': 'Бишкек'}],
          }
        ]
      });
      final a = (await CitiesService(dio).airports()).single;
      expect((a.title(true), a.popular.single.id), ('Манас · Бишкек', 1));
    });
  });

  group('CitiesService.popularRoutes — KG names', () {
    test('fromKg/toKg used in kg, places carry them; missing → RU', () async {
      stubGet({'data': [
        {'from': 'Бишкек', 'to': 'Нарын', 'fromKg': 'Бишкек', 'toKg': 'Нарын шаары', 'fromId': 1, 'toId': 7, 'tripCount': 3},
        {'from': 'Ош', 'to': 'Баткен', 'fromId': 2, 'toId': 9, 'tripCount': 1},
      ]});
      final r = await CitiesService(dio).popularRoutes();
      expect(r[0].toName(true), 'Нарын шаары');
      expect(r[0].toName(false), 'Нарын');
      expect(r[0].toPlace.nameKg, 'Нарын шаары');
      expect(r[1].fromName(true), 'Ош');
    });
  });

  group('MapService', () {
    test('bbox w,s,e,n + clamped zoom + filters', () async {
      stubGet({'items': [], 'clusters': []});
      await MapService(dio).listings(
        kind: 'requests',
        bbox: (west: 69.2, south: 39.1, east: 80.3, north: 43.3),
        zoom: 1,
        toId: 5,
        ride: 'airport',
      );
      final q = captureQuery('/map');
      expect(q['kind'], 'requests');
      expect(q['bbox'], '69.20000,39.10000,80.30000,43.30000');
      expect(q['zoom'], 3);
      expect(q['to_id'], 5);
      expect(q['ride'], 'airport');
      expect(q.containsKey('date'), false);
    });

    Map<String, dynamic> routeItem(String id, {required bool exact, int? seatsFree, int? passengers, int? price}) => {
          'id': id,
          'kind': seatsFree != null ? 'trip' : 'request',
          'lat': 42.87,
          'lng': 74.59,
          'exact': exact,
          'departureAt': '2026-10-20T03:00:00.000Z',
          'seatsFree': seatsFree,
          'passengers': passengers,
          'price': price,
          'origin': {'id': 1, 'nameRu': 'Бишкек', 'nameKg': 'Бишкек'},
          'destination': {'id': 7, 'nameRu': 'Нарын', 'nameKg': 'Нарын шаары'},
          'user': {'id': 'u1', 'name': 'Азамат', 'avatarUrl': null, 'rating': null, 'ratingCount': 0},
        };

    test('route → GET /map/route with route, date, ride; parses items + flags', () async {
      stubGet({
        'kind': 'trips',
        'truncated': true,
        'nearby': true,
        'items': [routeItem('t1', exact: false, seatsFree: 3, price: 1200)],
      });
      final r = await MapService(dio)
          .route(kind: 'trips', fromId: 1, toId: 7, date: '2026-10-20T00:00:00+06:00', ride: 'intercity');
      expect(captureQuery('/map/route'),
          {'kind': 'trips', 'from_id': 1, 'to_id': 7, 'date': '2026-10-20T00:00:00+06:00', 'ride': 'intercity'});
      expect((r.truncated, r.nearby), (true, true));
      final it = r.items.single;
      expect((it.exact, it.seats, it.price, it.lat), (false, 3, 1200, 42.87));
      expect(it.destinationName(true), 'Нарын шаары');
      expect(it.destinationName(false), 'Нарын');
    });

    test('route: requests carry passengers, no price; optional params omitted; empty body', () async {
      stubGet({'items': [routeItem('r1', exact: true, passengers: 2)]});
      final r = await MapService(dio).route(kind: 'requests', fromId: 1, toId: 7);
      final q = captureQuery('/map/route');
      expect(q.containsKey('date') || q.containsKey('ride') || q.containsKey('target_time'), false);
      await MapService(dio).route(kind: 'trips', fromId: 1, toId: 7, targetTime: '2026-10-19T21:30:00.000Z');
      expect(captureQuery('/map/route')['target_time'], '2026-10-19T21:30:00.000Z');
      expect((r.items.single.seats, r.items.single.price, r.truncated, r.nearby), (2, null, false, false));
      expect(MapRoute.fromJson(const {}).items, isEmpty);
    });
  });

  group('ProfileService — phone change via WhatsApp code', () {
    test('start → PATCH /users/me/phone {newPhone}', () async {
      when(() => dio.patch<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok<dynamic>({}));
      await ProfileService(dio).startPhoneChange('+996555000111');
      verify(() => dio.patch<dynamic>('/users/me/phone', data: {'newPhone': '+996555000111'})).called(1);
    });
    test('confirm → PATCH /users/me/phone/confirm, returns new access token', () async {
      when(() => dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok<Map<String, dynamic>>({'accessToken': 'new'}));
      expect(await ProfileService(dio).confirmPhoneChange('+996555000111', '123456'), 'new');
      final body = verify(() => dio.patch<Map<String, dynamic>>('/users/me/phone/confirm',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body, {'newPhone': '+996555000111', 'code': '123456', 'channel': 'web'});
    });
    test('preferredMode is sent on PATCH /users/me', () async {
      when(() => dio.patch<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok<Map<String, dynamic>>({'id': 'u1', 'name': 'A', 'preferredMode': 'driver'}));
      final u = await ProfileService(dio).update(preferredMode: 'driver');
      expect(u.preferredMode, 'driver');
      final body = verify(() => dio.patch<Map<String, dynamic>>('/users/me', data: captureAny(named: 'data')))
          .captured
          .single as Map;
      expect(body, {'preferredMode': 'driver'});
    });
  });
}
