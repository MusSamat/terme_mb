import 'package:dio/dio.dart';

/// Presence — heartbeat + public online counter.
class PresenceService {
  PresenceService(this._dio);
  final Dio _dio;

  /// Authenticated heartbeat — bumps last_seen_at + last_platform (mobile).
  Future<void> ping() => _dio.post<void>('/presence/ping');

  /// Public online count (server-cached ~10s).
  Future<int> online() async {
    final res = await _dio.get<Map<String, dynamic>>('/presence/online');
    return (res.data?['online'] as num?)?.toInt() ?? 0;
  }
}
