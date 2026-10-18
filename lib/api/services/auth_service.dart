import 'package:dio/dio.dart';

import '../../models/self_user.dart';

/// Auth domain — mirrors the /auth + /users/me endpoints (ТЗ §5.5).
/// The refresh token rides an HttpOnly cookie (dio cookie jar); the access
/// token is returned in the body and kept in memory by the caller.
class AuthService {
  AuthService(this._dio);
  final Dio _dio;

  // Every call sends channel='web': the backend then puts the refresh token in
  // an HttpOnly cookie, which the persistent cookie jar keeps across restarts
  // (Keychain / Keystore). With 'mobile' it would only come back in the body.

  /// POST /auth/check-phone → {exists, hasPassword}. Mobile only needs `exists`
  /// (new number → registration step).
  Future<bool> phoneExists(String phone) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/check-phone', data: {'phone': phone});
    return (res.data?['exists'] as bool?) ?? false;
  }

  /// POST /auth/phone/send-otp → WhatsApp code for login / registration.
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/phone/send-otp', data: {'phone': phone});
    return res.data!;
  }

  /// POST /auth/phone/verify → session for an existing account (mobile login).
  Future<AuthResult> verifyOtp(String phone, String code) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/phone/verify',
      data: {'phone': phone, 'code': code, 'channel': 'web'},
    );
    return AuthResult.fromJson(res.data!);
  }

  /// POST /auth/register → verifies the WhatsApp code and creates the account
  /// (name + surname, no password on mobile) in one call.
  Future<AuthResult> register({
    required String phone,
    required String code,
    required String name,
    required String surname,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'phone': phone, 'code': code, 'name': name, 'surname': surname, 'channel': 'web'},
    );
    return AuthResult.fromJson(res.data!);
  }

  /// GET /users/me — the signed-in user's profile.
  Future<SelfUser> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me');
    return SelfUser.fromJson(res.data!);
  }

  Future<void> logout() => _dio.post('/auth/logout');
  Future<void> logoutAll() => _dio.post('/auth/logout/all');

  /// POST /auth/refresh — silent token refresh (HttpOnly cookie carries the
  /// refresh token). Returns the new access token, or null on failure.
  Future<String?> refresh() async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/auth/refresh', data: {'channel': 'web'});
      return res.data?['accessToken'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// POST /auth/* session result (the refresh token rides the cookie).
class AuthResult {
  const AuthResult({this.accessToken, this.user});

  final String? accessToken;
  final SelfUser? user;

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        accessToken: j['accessToken'] as String?,
        user: j['user'] != null ? SelfUser.fromJson((j['user'] as Map).cast<String, dynamic>()) : null,
      );
}
