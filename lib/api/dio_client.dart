import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

import '../utils/config.dart';
import 'token_store.dart';

/// Callback that performs the refresh call and returns the new access token.
/// Wired by the auth layer so this file stays free of feature logic.
typedef RefreshFn = Future<String?> Function();

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
  bool _isRefreshing = false;

  // Persistent so the HttpOnly refresh cookie survives app restarts → the user
  // stays logged in until they explicitly log out (which clears the jar).
  late final CookieJar cookieJar =
      PersistCookieJar(storage: _cookieStorage, persistSession: true);

  late final Dio dio = _build();

  void attachRefresh(RefreshFn fn) => _refresh = fn;

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
        onRequest: (options, handler) {
          final token = _tokens.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }
          handler.next(options);
        },
        onError: (err, handler) async {
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

  Future<bool> _shouldRefresh(DioException err) async {
    if (err.response?.statusCode != 401) return false;
    if (err.requestOptions.extra['__retried'] == true) return false;
    final path = err.requestOptions.path;
    if (path.contains('/auth/refresh')) return false;
    final data = err.response?.data;
    final code = data is Map && data['error'] is Map ? data['error']['code'] : null;
    return code == 'TOKEN_EXPIRED' && _refresh != null;
  }

  Future<String?> _runRefresh() async {
    if (_isRefreshing) return _tokens.accessToken;
    _isRefreshing = true;
    try {
      final token = await _refresh!.call();
      return token;
    } finally {
      _isRefreshing = false;
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
