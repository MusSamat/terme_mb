import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the cookie jar — including the HttpOnly refresh cookie — in the
/// platform secure store (iOS Keychain / Android Keystore-backed encrypted
/// prefs). Replaces the plaintext-Hive storage: the refresh token must never
/// sit in the clear on disk (CLAUDE.md). The session still survives restarts.
class SecureCookieStorage extends Storage {
  SecureCookieStorage({this.prefix = 'cookie:'});

  final String prefix;

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String _k(String key) => '$prefix$key';

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => _secure.read(key: _k(key));

  @override
  Future<void> write(String key, String value) => _secure.write(key: _k(key), value: value);

  @override
  Future<void> delete(String key) => _secure.delete(key: _k(key));

  @override
  Future<void> deleteAll(List<String> keys) async {
    for (final key in keys) {
      await _secure.delete(key: _k(key));
    }
  }
}
