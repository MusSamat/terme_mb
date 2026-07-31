import 'dart:async';

/// Access token lives in memory only (never in Hive/secure storage).
/// The refresh token is carried by an HttpOnly cookie (see DioClient cookie jar).
class TokenStore {
  String? _accessToken;

  final _refreshed = StreamController<String?>.broadcast();

  String? get accessToken => _accessToken;

  /// Notifies listeners (e.g. the socket layer) when the token changes so they
  /// can re-authenticate. Mirrors web `onTokenRefreshed`.
  Stream<String?> get onRefreshed => _refreshed.stream;

  void set(String? token) {
    _accessToken = token;
    _refreshed.add(token);
  }

  void clear() => set(null);

  void dispose() => _refreshed.close();
}
