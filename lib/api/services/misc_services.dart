import 'package:dio/dio.dart';

import '../../data/mock_app_data.dart';

/// Chat, notifications, loyalty, cities — lean dio wrappers over their
/// respective endpoints (ТЗ §5.3). Grouped to keep the service count down.

class ChatService {
  ChatService(this._dio);
  final Dio _dio;

  /// GET /chats/summaries — conversation list.
  Future<List<MockChat>> summaries() async {
    final res = await _dio.get<Map<String, dynamic>>('/chats/summaries');
    final list = (res.data?['chats'] as List?) ?? const [];
    return list.map((e) => MockChat.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// GET /chats/{bookingId}/messages — history.
  Future<List<Map<String, dynamic>>> messages(String bookingId, {String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>('/chats/$bookingId/messages',
        queryParameters: {if (cursor != null) 'cursor': cursor});
    return ((res.data?['data'] as List?) ?? const []).cast<Map<String, dynamic>>();
  }

  /// POST /chats/{bookingId}/messages — send a message; returns the created row.
  Future<Map<String, dynamic>> sendMessage(String bookingId, String text) async {
    final res = await _dio.post<Map<String, dynamic>>('/chats/$bookingId/messages', data: {'text': text});
    return ((res.data?['message'] as Map?)?.cast<String, dynamic>()) ?? const {};
  }

  Future<void> markRead(String messageId) => _dio.patch('/messages/$messageId/read');

  /// PATCH /chats/{bookingId}/read-all — mark every message in a chat as read.
  Future<void> markAllRead(String bookingId) => _dio.patch('/chats/$bookingId/read-all');

  /// GET /chats/unread-counts → total unread messages across all chats.
  Future<int> unreadTotal() async {
    final res = await _dio.get<Map<String, dynamic>>('/chats/unread-counts');
    final counts = (res.data?['counts'] as Map?)?.cast<String, dynamic>() ?? const {};
    return counts.values.fold<int>(0, (sum, v) => sum + ((v as num?)?.toInt() ?? 0));
  }
}

class NotificationsService {
  NotificationsService(this._dio);
  final Dio _dio;

  Future<List<MockNotif>> list({bool unreadOnly = false, String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>('/notifications', queryParameters: {
      if (unreadOnly) 'unread': 'true',
      if (cursor != null) 'cursor': cursor,
    });
    return ((res.data?['data'] as List?) ?? const [])
        .map((e) => MockNotif.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> markRead(String id) => _dio.patch('/notifications/$id/read');
  Future<void> markAllRead() => _dio.patch('/notifications/read-all');

  /// Unread notification count (from the list response's unreadCount field).
  Future<int> unreadCount() async {
    final res = await _dio.get<Map<String, dynamic>>('/notifications', queryParameters: {'limit': 1});
    return (res.data?['unreadCount'] as num?)?.toInt() ?? 0;
  }
}

class LoyaltyService {
  LoyaltyService(this._dio);
  final Dio _dio;

  Future<MockLoyalty> status() async {
    final status = await _dio.get<Map<String, dynamic>>('/loyalty/status');
    final txs = await _dio.get<Map<String, dynamic>>('/loyalty/transactions');
    return MockLoyalty.fromJson(status.data!, (txs.data?['data'] as List?) ?? const []);
  }
}

class CitiesService {
  CitiesService(this._dio);
  final Dio _dio;

  /// GET /cities?q= — city search/autocomplete.
  Future<List<String>> search(String query) async {
    final res = await _dio.get<Map<String, dynamic>>('/cities',
        queryParameters: {if (query.isNotEmpty) 'q': query, 'limit': 20});
    final list = (res.data?['data'] as List?) ?? const [];
    return list.map((e) => ((e as Map)['nameRu'] ?? '') as String).where((s) => s.isNotEmpty).toList();
  }

  /// GET /cities/popular-routes — curated top routes for the empty feed state.
  Future<List<PopularRoute>> popularRoutes() async {
    final res = await _dio.get<Map<String, dynamic>>('/cities/popular-routes');
    final list = (res.data?['data'] as List?) ?? const [];
    return list
        .map((e) {
          final m = e as Map;
          return PopularRoute(
            from: (m['from'] ?? '') as String,
            to: (m['to'] ?? '') as String,
            tripCount: (m['tripCount'] as num?)?.toInt() ?? 0,
          );
        })
        .where((r) => r.from.isNotEmpty && r.to.isNotEmpty)
        .toList();
  }
}

/// A popular route chip for the empty feed state (mirrors web PopularRoute).
class PopularRoute {
  const PopularRoute({required this.from, required this.to, required this.tripCount});
  final String from;
  final String to;
  final int tripCount;
}
