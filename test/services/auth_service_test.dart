import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:terme_mb/api/services/auth_service.dart';

class MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _ok(Map<String, dynamic> data) => Response(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: 200,
      data: data,
    );

void main() {
  late MockDio dio;
  late AuthService svc;

  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(RequestOptions(path: '/'));
  });
  setUp(() {
    dio = MockDio();
    svc = AuthService(dio);
  });

  void stubPost(Map<String, dynamic> resp) {
    when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _ok(resp));
    when(() => dio.post<Map<String, dynamic>>(any())).thenAnswer((_) async => _ok(resp));
  }

  group('phoneExists', () {
    test('POST /auth/check-phone → exists flag', () async {
      stubPost({'exists': true, 'hasPassword': false});
      expect(await svc.phoneExists('+996700'), true);
      final body = verify(() => dio.post<Map<String, dynamic>>('/auth/check-phone',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['phone'], '+996700');
    });
    test('missing flag → false (new number)', () async {
      stubPost({});
      expect(await svc.phoneExists('+996700'), false);
    });
  });

  group('sendOtp', () {
    test('POST /auth/phone/send-otp with phone', () async {
      stubPost({'expiresInSec': 120});
      final r = await svc.sendOtp('+996701');
      expect(r['expiresInSec'], 120);
      verify(() => dio.post<Map<String, dynamic>>('/auth/phone/send-otp', data: {'phone': '+996701'})).called(1);
    });
  });

  group('verifyOtp', () {
    test('POST /auth/phone/verify with phone+code+channel=web (cookie refresh)', () async {
      stubPost({'kind': 'full', 'accessToken': 'tok'});
      final r = await svc.verifyOtp('+996700', '123456');
      expect(r.accessToken, 'tok');
      final body = verify(() => dio.post<Map<String, dynamic>>('/auth/phone/verify',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['phone'], '+996700');
      expect(body['code'], '123456');
      expect(body['channel'], 'web');
    });
  });

  group('register', () {
    test('POST /auth/register with code + name + surname, no password', () async {
      stubPost({'kind': 'full', 'accessToken': 'tok', 'user': {'id': 'u1', 'name': 'A'}});
      final r = await svc.register(phone: '+996700', code: '111111', name: 'Азамат', surname: 'Асанов');
      expect(r.user?.id, 'u1');
      final body = verify(() => dio.post<Map<String, dynamic>>('/auth/register',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['name'], 'Азамат');
      expect(body['surname'], 'Асанов');
      expect(body['code'], '111111');
      expect(body.containsKey('password'), false);
      expect(body['channel'], 'web');
    });
  });

  group('me', () {
    test('GET /users/me → SelfUser', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => _ok({'id': 'u1', 'name': 'Тест', 'roles': ['passenger']}));
      final u = await svc.me();
      expect(u.id, 'u1');
      expect(u.isPassenger, true);
    });
  });

  group('logout verbs', () {
    test('logout → POST /auth/logout', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.logout();
      verify(() => dio.post<dynamic>('/auth/logout')).called(1);
    });
    test('logoutAll → POST /auth/logout/all', () async {
      when(() => dio.post<dynamic>(any())).thenAnswer((_) async => _ok({}));
      await svc.logoutAll();
      verify(() => dio.post<dynamic>('/auth/logout/all')).called(1);
    });
  });

  group('refresh', () {
    test('returns accessToken on success', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({'accessToken': 'fresh'}));
      expect(await svc.refresh(), 'fresh');
    });
    test('returns null when the call throws', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenThrow(DioException(requestOptions: RequestOptions(path: '/x')));
      expect(await svc.refresh(), isNull);
    });
    test('returns null when body has no token', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({}));
      expect(await svc.refresh(), isNull);
    });
  });

  group('AuthResult.fromJson', () {
    test('token + user', () {
      final r = AuthResult.fromJson({'accessToken': 't', 'user': {'id': 'u'}});
      expect(r.accessToken, 't');
      expect(r.user?.id, 'u');
    });
    test('user null when absent', () {
      expect(AuthResult.fromJson({'accessToken': 't'}).user, isNull);
    });
  });
}
