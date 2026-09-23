import 'package:dio/dio.dart';

import '../../models/self_user.dart';

/// Auth domain — mirrors the /auth + /users/me endpoints (ТЗ §5.5).
/// The refresh token rides an HttpOnly cookie (dio cookie jar); the access
/// token is returned in the body and kept in memory by the caller.
class AuthService {
  AuthService(this._dio);
  final Dio _dio;

  /// POST /auth/check-phone → {exists, hasPassword, hasTelegram}.
  Future<Map<String, dynamic>> checkPhone(String phone) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/check-phone', data: {'phone': phone});
    return res.data!;
  }

  /// POST /auth/phone/send-otp → sends the login/registration code to the user's
  /// WhatsApp. Returns {expiresInSec}. Canonical OTP-send channel.
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/phone/send-otp', data: {'phone': phone});
    return res.data!;
  }

  /// POST /auth/phone/verify → AuthResult | ProvisionalAuthResult.
  Future<AuthResult> verifyOtp(String phone, String code) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/phone/verify',
      data: {'phone': phone, 'code': code, 'channel': 'web'},
    );
    return AuthResult.fromJson(res.data!);
  }

  /// POST /auth/phone/login → AuthResult (phone + password).
  Future<AuthResult> loginPassword(String phone, String password) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/phone/login',
      data: {'phone': phone, 'password': password, 'channel': 'web'},
    );
    return AuthResult.fromJson(res.data!);
  }

  /// POST /auth/register → verifies the Telegram OTP and creates the account
  /// with name/surname/password in one call. Returns a full session.
  Future<AuthResult> register({
    required String phone,
    required String code,
    required String name,
    required String surname,
    String? password, // optional: mobile registers passwordless (phone+OTP only)
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'phone': phone,
        'code': code,
        'name': name,
        'surname': surname,
        if (password != null) 'password': password,
        'channel': 'mobile',
      },
    );
    return AuthResult.fromJson(res.data!);
  }

  /// POST /auth/phone/reset-password → set a new password after verifying a
  /// WhatsApp OTP. Requires {phone, code, newPassword} (unauthenticated flow).
  Future<void> resetPassword(String phone, String code, String newPassword) =>
      _dio.post('/auth/phone/reset-password',
          data: {'phone': phone, 'code': code, 'newPassword': newPassword, 'channel': 'web'});

  /// PATCH /users/me/password → change password. `currentPassword` required when
  /// the account already has one.
  Future<void> setPassword(String newPassword, {String? currentPassword}) => _dio.patch(
        '/users/me/password',
        data: {
          'newPassword': newPassword,
          if (currentPassword != null) 'currentPassword': currentPassword,
        },
      );

  // ── Telegram bot deep-link login ───────────────────────────────────────────
  Future<Map<String, dynamic>> botLoginInit() async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/telegram/bot-login/init');
    return res.data!; // {token, deepLink, expiresInSec}
  }

  Future<String> botLoginStatus(String token) async {
    final res = await _dio.get<Map<String, dynamic>>('/auth/telegram/bot-login/status',
        queryParameters: {'token': token});
    return res.data!['status'] as String; // waiting | done | expired | not_found
  }

  Future<AuthResult> botLoginClaim(String token) async {
    final res = await _dio.post<Map<String, dynamic>>('/auth/telegram/bot-login/claim',
        data: {'token': token, 'channel': 'web'});
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

/// POST /auth/* result. `kind == 'full'` carries user + tokens; `provisional`
/// means the client must complete phone verification.
class AuthResult {
  const AuthResult({required this.kind, this.accessToken, this.user, this.provisionalToken});

  final String kind; // full | provisional
  final String? accessToken;
  final SelfUser? user;
  final String? provisionalToken;

  bool get isFull => kind == 'full';

  factory AuthResult.fromJson(Map<String, dynamic> j) => AuthResult(
        kind: (j['kind'] ?? 'full') as String,
        accessToken: j['accessToken'] as String?,
        provisionalToken: j['provisionalToken'] as String?,
        user: j['user'] != null ? SelfUser.fromJson((j['user'] as Map).cast<String, dynamic>()) : null,
      );
}
