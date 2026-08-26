import 'package:cookie_jar/cookie_jar.dart';
import 'package:hive/hive.dart';

/// Persists the PersistCookieJar to the app's Hive box (keeps the HttpOnly
/// refresh cookie across restarts, so the session survives app relaunch).
/// Backed by Hive to avoid pulling in path_provider / a new dependency.
class HiveCookieStorage extends Storage {
  HiveCookieStorage(this._box, {this.prefix = 'cookie:'});

  final Box<dynamic> _box;
  final String prefix;

  String _k(String key) => '$prefix$key';

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) async => _box.get(_k(key)) as String?;

  @override
  Future<void> write(String key, String value) async => _box.put(_k(key), value);

  @override
  Future<void> delete(String key) async => _box.delete(_k(key));

  @override
  Future<void> deleteAll(List<String> keys) async => _box.deleteAll(keys.map(_k));
}
