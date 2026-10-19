import 'package:dio/dio.dart';

import '../../models/place.dart';

import '../../models/app_notification.dart';
import '../../models/chat.dart';
import '../../models/loyalty.dart';

/// Chat, notifications, loyalty, cities — lean dio wrappers over their
/// respective endpoints (ТЗ §5.3). Grouped to keep the service count down.

class ChatService {
  ChatService(this._dio);
  final Dio _dio;

  /// GET /chats/summaries — conversation list.
  Future<List<ChatSummary>> summaries() async {
    final res = await _dio.get<Map<String, dynamic>>('/chats/summaries');
    final list = (res.data?['chats'] as List?) ?? const [];
    return list.map((e) => ChatSummary.fromJson((e as Map).cast<String, dynamic>())).toList();
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

  Future<List<AppNotification>> list({bool unreadOnly = false, String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>('/notifications', queryParameters: {
      if (unreadOnly) 'unread': 'true',
      if (cursor != null) 'cursor': cursor,
    });
    return ((res.data?['data'] as List?) ?? const [])
        .map((e) => AppNotification.fromJson((e as Map).cast<String, dynamic>()))
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

  Future<LoyaltyStatus> status() async {
    final status = await _dio.get<Map<String, dynamic>>('/loyalty/status');
    final txs = await _dio.get<Map<String, dynamic>>('/loyalty/transactions');
    return LoyaltyStatus.fromJson(status.data!, (txs.data?['data'] as List?) ?? const []);
  }
}

class CitiesService {
  CitiesService(this._dio);
  final Dio _dio;

  /// GET /cities?q= — SOATE directory autocomplete (RU / KG / Latin / wrong
  /// layout all match server-side). Empty query → the most prominent places.
  Future<List<Place>> search(String query, {int limit = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>('/cities',
        queryParameters: {if (query.trim().isNotEmpty) 'q': query.trim(), 'limit': limit});
    return _places(res.data?['data']);
  }

  /// GET /cities/nearest — the settlement a GPS point is in (prefills «Откуда»).
  Future<Place?> nearest(double lat, double lng) async {
    final res = await _dio.get<Map<String, dynamic>>('/cities/nearest',
        queryParameters: {'lat': lat, 'lng': lng});
    return Place.maybe(res.data?['data']);
  }

  /// GET /cities/{id}/spots — departure spots + жилмассивы (Бишкек / Ош only).
  Future<List<MeetingSpot>> spots(int cityId, {String? query}) async {
    final res = await _dio.get<Map<String, dynamic>>('/cities/$cityId/spots',
        queryParameters: {if (query != null && query.trim().isNotEmpty) 'q': query.trim()});
    return ((res.data?['data'] as List?) ?? const [])
        .map((e) => MeetingSpot.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// GET /cities/airports — airports with the city each one serves.
  Future<List<Airport>> airports() async {
    final res = await _dio.get<Map<String, dynamic>>('/cities/airports');
    return ((res.data?['data'] as List?) ?? const [])
        .map((e) => Airport.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// GET /cities/popular-routes — curated top routes with live trip counts.
  Future<List<PopularRoute>> popularRoutes() async {
    final res = await _dio.get<Map<String, dynamic>>('/cities/popular-routes');
    final list = (res.data?['data'] as List?) ?? const [];
    return list
        .map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return PopularRoute(
            from: (m['from'] ?? '') as String,
            to: (m['to'] ?? '') as String,
            fromKg: m['fromKg'] as String?,
            toKg: m['toKg'] as String?,
            fromId: (m['fromId'] as num?)?.toInt() ?? 0,
            toId: (m['toId'] as num?)?.toInt() ?? 0,
            tripCount: (m['tripCount'] as num?)?.toInt() ?? 0,
            minPrice: (m['minPrice'] as num?)?.toInt(),
          );
        })
        .where((r) => r.fromId > 0 && r.toId > 0)
        .toList();
  }

  static List<Place> _places(dynamic list) => ((list as List?) ?? const [])
      .map((e) => Place.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
}

/// A popular route chip (RU + KG names; ids drive the search).
class PopularRoute {
  const PopularRoute({
    required this.from,
    required this.to,
    String? fromKg,
    String? toKg,
    required this.fromId,
    required this.toId,
    required this.tripCount,
    this.minPrice,
  })  : fromKg = fromKg ?? from,
        toKg = toKg ?? to;
  final String from;
  final String to;
  final String fromKg;
  final String toKg;
  final int fromId;
  final int toId;
  final int tripCount;
  final int? minPrice;

  String fromName(bool kg) => kg ? fromKg : from;
  String toName(bool kg) => kg ? toKg : to;

  // Minimal places for the search filters (names are completed by the detail).
  Place get fromPlace => Place(id: fromId, type: 'city', nameRu: from, nameKg: fromKg);
  Place get toPlace => Place(id: toId, type: 'city', nameRu: to, nameKg: toKg);
}

/// GET /map — listings inside a viewport, grid-clustered server-side.
class MapService {
  MapService(this._dio);
  final Dio _dio;

  Future<MapListings> listings({
    required String kind, // trips | requests
    required ({double west, double south, double east, double north}) bbox,
    required int zoom,
    int? toId,
    String? ride, // intercity | airport
    String? date,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>('/map', queryParameters: {
      'kind': kind,
      'bbox': [bbox.west, bbox.south, bbox.east, bbox.north].map((v) => v.toStringAsFixed(5)).join(','),
      'zoom': zoom.clamp(3, 20),
      if (toId != null) 'to_id': toId,
      if (ride != null) 'ride': ride,
      if (date != null) 'date': date,
    });
    return MapListings.fromJson(res.data ?? const {});
  }

  /// GET /map/route — all listings of from→to (same date / ride as the list).
  Future<MapRoute> route({
    required String kind, // trips | requests
    required int fromId,
    required int toId,
    String? date,
    String? ride,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>('/map/route', queryParameters: {
      'kind': kind,
      'from_id': fromId,
      'to_id': toId,
      if (date != null) 'date': date,
      if (ride != null) 'ride': ride,
    });
    return MapRoute.fromJson(res.data ?? const {});
  }
}

class MapItem {
  const MapItem({
    required this.id,
    required this.lat,
    required this.lng,
    required this.exact,
    required this.originCity,
    required this.destinationCity,
    String? originKg,
    String? destinationKg,
    required this.departureAt,
    required this.seats,
    this.price,
  })  : originKg = originKg ?? originCity,
        destinationKg = destinationKg ?? destinationCity;
  final String id;
  final double lat;
  final double lng;
  final bool exact;
  final String originCity;
  final String destinationCity;
  final String originKg;
  final String destinationKg;
  final DateTime departureAt;
  /// Trips: free seats; requests: passengers.
  final int seats;
  final int? price;

  String originName(bool kg) => kg ? originKg : originCity;
  String destinationName(bool kg) => kg ? destinationKg : destinationCity;

  /// Parses both the /map/route item ({origin:{nameRu,nameKg}}, seatsFree |
  /// passengers) and the legacy /map item (originCity, seats).
  factory MapItem.fromJson(Map<String, dynamic> j) {
    final o = (j['origin'] as Map?)?.cast<String, dynamic>();
    final d = (j['destination'] as Map?)?.cast<String, dynamic>();
    return MapItem(
      id: j['id'] as String,
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      exact: (j['exact'] ?? false) as bool,
      originCity: (o?['nameRu'] ?? j['originCity'] ?? '') as String,
      destinationCity: (d?['nameRu'] ?? j['destinationCity'] ?? '') as String,
      originKg: o?['nameKg'] as String?,
      destinationKg: d?['nameKg'] as String?,
      departureAt: DateTime.parse(j['departureAt'] as String).toLocal(),
      seats: ((j['seatsFree'] ?? j['passengers'] ?? j['seats']) as num?)?.toInt() ?? 0,
      price: (j['price'] as num?)?.toInt(),
    );
  }
}

/// GET /map/route — every active listing of one route (cap 500).
class MapRoute {
  const MapRoute({this.items = const [], this.truncated = false, this.nearby = false});
  final List<MapItem> items;
  /// More than the cap exist — only the earliest are shown.
  final bool truncated;
  /// Nothing on the exact places → nearby settlements (25 km) were used.
  final bool nearby;

  factory MapRoute.fromJson(Map<String, dynamic> j) => MapRoute(
        items: ((j['items'] as List?) ?? const [])
            .map((e) => MapItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        truncated: (j['truncated'] ?? false) as bool,
        nearby: (j['nearby'] ?? false) as bool,
      );
}

class MapCluster {
  const MapCluster({required this.lat, required this.lng, required this.count});
  final double lat;
  final double lng;
  final int count;
}

class MapListings {
  const MapListings({this.items = const [], this.clusters = const []});
  final List<MapItem> items;
  final List<MapCluster> clusters;

  factory MapListings.fromJson(Map<String, dynamic> j) => MapListings(
        items: ((j['items'] as List?) ?? const [])
            .map((e) => MapItem.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        clusters: ((j['clusters'] as List?) ?? const []).map((e) {
          final m = e as Map;
          return MapCluster(
            lat: (m['lat'] as num).toDouble(),
            lng: (m['lng'] as num).toDouble(),
            count: (m['count'] as num).toInt(),
          );
        }).toList(),
      );
}
