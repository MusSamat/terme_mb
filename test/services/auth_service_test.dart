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

  group('checkPhone', () {
    test('POST /auth/check-phone with phone, returns raw map', () async {
      stubPost({'exists': true, 'hasPassword': false});
      final r = await svc.checkPhone('+996700');
      expect(r['exists'], true);
      final body = verify(() => dio.post<Map<String, dynamic>>('/auth/check-phone',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['phone'], '+996700');
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
    test('POST /auth/phone/verify with phone+code+channel', () async {
      stubPost({'kind': 'full', 'accessToken': 'tok'});
      final r = await svc.verifyOtp('+996700', '123456');
      expect(r.isFull, true);
      expect(r.accessToken, 'tok');
      final body = verify(() => dio.post<Map<String, dynamic>>('/auth/phone/verify',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['phone'], '+996700');
      expect(body['code'], '123456');
      expect(body['channel'], 'web');
    });
  });

  group('loginPassword', () {
    test('POST /auth/phone/login with credentials', () async {
      stubPost({'kind': 'full', 'accessToken': 'tok'});
      await svc.loginPassword('+996700', 'secret');
      final body = verify(() => dio.post<Map<String, dynamic>>('/auth/phone/login',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['password'], 'secret');
      expect(body['channel'], 'web');
    });
  });

  group('register', () {
    test('POST /auth/register with all fields', () async {
      stubPost({'kind': 'full', 'accessToken': 'tok', 'user': {'id': 'u1', 'name': 'A'}});
      final r = await svc.register(
          phone: '+996700', code: '111111', name: 'Азамат', surname: 'Асанов', password: 'p');
      expect(r.user?.id, 'u1');
      final body = verify(() => dio.post<Map<String, dynamic>>('/auth/register',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['name'], 'Азамат');
      expect(body['surname'], 'Асанов');
      expect(body['code'], '111111');
      expect(body['password'], 'p');
      expect(body['channel'], 'web');
    });
  });

  group('resetPassword', () {
    test('POST /auth/phone/reset-password with phone, code, newPassword', () async {
      when(() => dio.post<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.resetPassword('+996701', '111111', 'newpass');
      final body = verify(() => dio.post<dynamic>('/auth/phone/reset-password',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['phone'], '+996701');
      expect(body['code'], '111111');
      expect(body['newPassword'], 'newpass');
    });
  });

  group('setPassword', () {
    test('PATCH /users/me/password includes currentPassword when given', () async {
      when(() => dio.patch<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.setPassword('new', currentPassword: 'old');
      final body = verify(() => dio.patch<dynamic>('/users/me/password',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body['newPassword'], 'new');
      expect(body['currentPassword'], 'old');
    });
    test('omits currentPassword when null', () async {
      when(() => dio.patch<dynamic>(any(), data: any(named: 'data'))).thenAnswer((_) async => _ok({}));
      await svc.setPassword('new');
      final body = verify(() => dio.patch<dynamic>('/users/me/password',
          data: captureAny(named: 'data'))).captured.single as Map;
      expect(body.containsKey('currentPassword'), false);
    });
  });

  group('bot login', () {
    test('botLoginInit → POST init', () async {
      when(() => dio.post<Map<String, dynamic>>(any()))
          .thenAnswer((_) async => _ok({'token': 't', 'deepLink': 'tg://x'}));
      final r = await svc.botLoginInit();
      expect(r['token'], 't');
      verify(() => dio.post<Map<String, dynamic>>('/auth/telegram/bot-login/init')).called(1);
    });
    test('botLoginStatus returns the status field', () async {
      when(() => dio.get<Map<String, dynamic>>(any(), queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => _ok({'status': 'waiting'}));
      expect(await svc.botLoginStatus('tk'), 'waiting');
    });
    test('botLoginClaim → AuthResult', () async {
      when(() => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => _ok({'kind': 'full', 'accessToken': 'z'}));
      final r = await svc.botLoginClaim('tk');
      expect(r.accessToken, 'z');
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
    test('full kind', () {
      final r = AuthResult.fromJson({'kind': 'full', 'accessToken': 't', 'user': {'id': 'u'}});
      expect(r.isFull, true);
      expect(r.user?.id, 'u');
    });
    test('provisional kind', () {
      final r = AuthResult.fromJson({'kind': 'provisional', 'provisionalToken': 'p'});
      expect(r.isFull, false);
      expect(r.provisionalToken, 'p');
    });
    test('kind defaults to full', () {
      expect(AuthResult.fromJson({}).isFull, true);
    });
    test('user null when absent', () {
      expect(AuthResult.fromJson({'kind': 'full'}).user, isNull);
    });
  });
}
