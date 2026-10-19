import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/api/dio_client.dart';
import 'package:terme_mb/api/token_store.dart';

class _MemStorage extends Storage {
  final _m = <String, String>{};
  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}
  @override
  Future<String?> read(String key) async => _m[key];
  @override
  Future<void> write(String key, String value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
  @override
  Future<void> deleteAll(List<String> keys) async => keys.forEach(_m.remove);
}

/// Answers /me with 401 no_token unless a Bearer token is present.
class _Adapter implements HttpClientAdapter {
  final seenAuth = <String?>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? _, Future<void>? __) async {
    final auth = o.headers['Authorization'] as String?;
    seenAuth.add(auth);
    if (auth == null) {
      return ResponseBody.fromString(
        jsonEncode({
          'error': {'code': 'UNAUTHORIZED', 'message': '', 'details': {'reason': 'no_token'}}
        }),
        401,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    return ResponseBody.fromString(jsonEncode({'ok': true}), 200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late TokenStore tokens;
  late DioClient client;
  late _Adapter adapter;

  setUp(() {
    tokens = TokenStore();
    client = DioClient(tokens, cookieStorage: _MemStorage());
    adapter = _Adapter();
    client.dio.httpClientAdapter = adapter;
  });

  test('a token-less session recovers: 401 no_token → refresh → retry', () async {
    client.attachRefresh(() async {
      tokens.set('fresh');
      return 'fresh';
    });
    final res = await client.dio.get<dynamic>('/me');
    expect(res.statusCode, 200);
    expect(adapter.seenAuth, [null, 'Bearer fresh']);
  });

  test('guest (refresh returns null) gets the original 401, no retry', () async {
    client.attachRefresh(() async => null);
    await expectLater(client.dio.get<dynamic>('/me'), throwsA(isA<DioException>()));
    expect(adapter.seenAuth, [null]);
  });

  test('calls made during the startup refresh wait for its token', () async {
    client.attachRefresh(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      tokens.set('t1');
      return 't1';
    });
    final refresh = client.refreshNow();
    final res = await client.dio.get<dynamic>('/me');
    await refresh;
    expect(res.statusCode, 200);
    expect(adapter.seenAuth, ['Bearer t1']);
  });

  test('TOKEN_EXPIRED on ANY request (POST, pre-iss/aud token) → refresh → retry with the body', () async {
    final expiring = _ExpiringAdapter();
    client.dio.httpClientAdapter = expiring;
    tokens.set('old');
    var refreshes = 0;
    client.attachRefresh(() async {
      refreshes++;
      tokens.set('new');
      return 'new';
    });
    final res = await client.dio.post<dynamic>('/bookings', data: {'tripId': 't1', 'seatsCount': 1});
    expect(res.statusCode, 200);
    expect(refreshes, 1);
    expect(expiring.seen, ['POST Bearer old', 'POST Bearer new']);
    expect(expiring.bodies.last, contains('t1'));
  });
}

/// 401 TOKEN_EXPIRED for the stale token, 200 for any other.
class _ExpiringAdapter implements HttpClientAdapter {
  final seen = <String>[];
  final bodies = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? _) async {
    final auth = o.headers['Authorization'] as String?;
    seen.add('${o.method} $auth');
    bodies.add(body == null ? '' : utf8.decode(await body.expand((c) => c).toList()));
    final headers = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    if (auth == 'Bearer old') {
      return ResponseBody.fromString(
          jsonEncode({'error': {'code': 'TOKEN_EXPIRED', 'message': 'Access token has expired'}}), 401,
          headers: headers);
    }
    return ResponseBody.fromString(jsonEncode({'ok': true}), 200, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}
