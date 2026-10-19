import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

import '../utils/config.dart';
import 'token_store.dart';

/// Callback that performs the refresh call and returns the new access token.
/// Wired by the auth layer so this file stays free of feature logic.
typedef RefreshFn = Future<String?> Function();

/// Callback that forces a full logout (clear tokens/session + cookie jar) and
/// routes to login. Wired by the auth layer; invoked on token-reuse detection.
typedef ForceLogoutFn = void Function();

/// Builds the shared Dio instance:
///  - Bearer access token on every request
///  - strips manual Content-Type for FormData (multipart boundary)
///  - HttpOnly refresh cookie carried by the cookie jar
///  - on 401 + TOKEN_EXPIRED: refresh once, re-auth, retry the original request
class DioClient {
  DioClient(this._tokens, {required Storage cookieStorage}) : _cookieStorage = cookieStorage;

  final TokenStore _tokens;
  final Storage _cookieStorage;
  RefreshFn? _refresh;
  ForceLogoutFn? _forceLogout;
  // Single-flight: concurrent 401s share ONE refresh and all await the SAME
  // new token — never a stale one. This also stops the client from calling
  // /auth/refresh twice with the same cookie (which tripped reuse detection).
  Future<String?>? _inflight;

  // Persistent so the HttpOnly refresh cookie survives app restarts → the user
  // stays logged in until they explicitly log out (which clears the jar).
  late final CookieJar cookieJar =
      PersistCookieJar(storage: _cookieStorage, persistSession: true);

  late final Dio dio = _build();

  void attachRefresh(RefreshFn fn) => _refresh = fn;
  void attachForceLogout(ForceLogoutFn fn) => _forceLogout = fn;

  /// Runs (or joins) the single-flight refresh — used by the cold-start restore
  /// so requests issued meanwhile wait for its token.
  Future<String?> refreshNow() => _runRefresh();

  Dio _build() {
    final d = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.requestTimeout,
        receiveTimeout: AppConfig.requestTimeout,
        sendTimeout: AppConfig.requestTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    d.interceptors.add(CookieManager(cookieJar));

    d.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Cold start: the cached profile renders the signed-in shell before the
          // first refresh lands. Hold token-less calls until it does, instead of
          // firing them bare and getting 401 no_token.
          if (_tokens.accessToken == null && _inflight != null && !options.path.contains('/auth/')) {
            try {
              await _inflight;
            } catch (_) {/* the call goes out bare; its 401 is handled below */}
          }
          final token = _tokens.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Platform attribution for presence/analytics (web | mini | mobile).
          options.headers['X-Client-Platform'] = 'mobile';
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          if (_isTokenReuse(err)) {
            // Refresh token was replayed — the backend revoked the whole family.
            // Drop the session locally and bounce to login; never retry.
            _forceLogout?.call();
            return handler.next(err);
          }
          if (await _shouldRefresh(err)) {
            try {
              final newToken = await _runRefresh();
              if (newToken != null) {
                final res = await _retry(err.requestOptions, newToken);
                return handler.resolve(res);
              }
            } catch (_) {
              // fall through to original error; auth layer clears session
            }
          }
          handler.next(err);
        },
      ),
    );

    return d;
  }

  /// True when /auth/refresh answered 401 with a token-reuse signal — either
  /// error.details.reason == 'token_reuse_detected' or details.code ==
  /// 'TOKEN_REUSE_DETECTED'. Requires a full logout, not a retry.
  bool _isTokenReuse(DioException err) {
    if (err.response?.statusCode != 401) return false;
    final data = err.response?.data;
    if (data is! Map || data['error'] is! Map) return false;
    final error = data['error'] as Map;
    if (error['code'] == 'TOKEN_REUSE_DETECTED') return true;
    final details = error['details'];
    if (details is! Map) return false;
    return details['reason'] == 'token_reuse_detected' ||
        details['code'] == 'TOKEN_REUSE_DETECTED';
  }

  Future<bool> _shouldRefresh(DioException err) async {
    if (err.response?.statusCode != 401) return false;
    if (err.requestOptions.extra['__retried'] == true) return false;
    final path = err.requestOptions.path;
    if (path.contains('/auth/refresh')) return false;
    final data = err.response?.data;
    final error = data is Map && data['error'] is Map ? data['error'] as Map : null;
    final code = error?['code'];
    final details = error?['details'];
    // A token-less call (the startup refresh failed offline) also recovers via
    // refresh; the auth layer's RefreshFn returns null for guests.
    final noToken = code == 'UNAUTHORIZED' && details is Map && details['reason'] == 'no_token';
    return (code == 'TOKEN_EXPIRED' || noToken) && _refresh != null;
  }

  Future<String?> _runRefresh() {
    // Reuse the in-flight refresh so parallel 401s all get the same fresh token.
    return _inflight ??= _doRefresh();
  }

  Future<String?> _doRefresh() async {
    try {
      return await _refresh!.call();
    } finally {
      _inflight = null;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions req, String token) {
    final options = Options(
      method: req.method,
      headers: {...req.headers, 'Authorization': 'Bearer $token'},
      extra: {...req.extra, '__retried': true},
    );
    return dio.request<dynamic>(
      req.path,
      data: req.data,
      queryParameters: req.queryParameters,
      options: options,
    );
  }
}
