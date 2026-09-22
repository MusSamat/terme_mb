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

  /// GET /cities?q= — city search/autocomplete. Carries the district/aiyl
  /// context so the client can show «Баткен району, Самаркандек айылы» under
  /// the name. Oblasts are excluded server-side.
  Future<List<CityHit>> search(String query) async {
    final res = await _dio.get<Map<String, dynamic>>('/cities',
        queryParameters: {if (query.isNotEmpty) 'q': query, 'limit': 20});
    final list = (res.data?['data'] as List?) ?? const [];
    return list
        .map((e) {
          final m = e as Map;
          return CityHit(
            name: (m['nameRu'] ?? '') as String,
            type: m['type'] as String?,
            districtRu: m['districtNameRu'] as String?,
            districtKg: m['districtNameKg'] as String?,
            aiylRu: m['aiylAimakNameRu'] as String?,
            aiylKg: m['aiylAimakNameKg'] as String?,
          );
        })
        .where((c) => c.name.isNotEmpty)
        .toList();
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
            minPrice: (m['minPrice'] as num?)?.toInt(),
          );
        })
        .where((r) => r.from.isNotEmpty && r.to.isNotEmpty)
        .toList();
  }
}

/// A popular route chip for the empty feed state (mirrors web PopularRoute).
class PopularRoute {
  const PopularRoute({required this.from, required this.to, required this.tripCount, this.minPrice});
  final String from;
  final String to;
  final int tripCount;
  final int? minPrice;
}

/// A city search hit + its administrative context (район, айыл). Oblast is
/// intentionally omitted — we never show it as a subtitle.
class CityHit {
  const CityHit({
    required this.name,
    this.type,
    this.districtRu,
    this.districtKg,
    this.aiylRu,
    this.aiylKg,
  });

  final String name;
  final String? type; // city | town | village | raion …
  final String? districtRu;
  final String? districtKg;
  final String? aiylRu;
  final String? aiylKg;

  /// Result tag: раион → «район»; settlement → «Баткен району, Самаркандек
  /// айылы»; an oblast-level город with no district → «город/шаар». Distinguishes
  /// homonyms like «Баткен · район» vs «Баткен · город».
  String subtitle(bool kg) {
    if (type == 'raion') return 'район';
    // Oblast-level город → tag «город/шаар» (its district often repeats the name,
    // e.g. «Баткен» город in «Баткен» район — the district would be noise).
    if (type == 'city') return kg ? 'шаар' : 'город';
    final d = (kg ? districtKg : districtRu)?.trim();
    final a = (kg ? aiylKg : aiylRu)?.trim();
    return [d, a].where((s) => s != null && s.isNotEmpty).join(', ');
  }
}
