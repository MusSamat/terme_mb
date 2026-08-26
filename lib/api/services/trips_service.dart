import 'package:dio/dio.dart';

import '../../models/trip_card_item.dart';
import '../../utils/uuid.dart';
import '../paged_result.dart';

/// Trips domain — mirrors the /trips endpoints in openapi.json (ТЗ §5.3).
class TripsService {
  TripsService(this._dio);
  final Dio _dio;

  /// GET /trips — browse/search (cursor-paginated).
  Future<PagedResult<TripCardItem>> list({
    String? from,
    String? to,
    String? date,
    String? cursor,
    Map<String, dynamic>? filters,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>('/trips', queryParameters: {
      if (from != null && from.isNotEmpty) 'from_city': from,
      if (to != null && to.isNotEmpty) 'to_city': to,
      if (date != null) 'date': date,
      if (cursor != null) 'cursor': cursor,
      ...?filters,
    });
    return PagedResult.fromJson(res.data!, TripCardItem.fromJson);
  }

  /// GET /trips/calendar?from_city&to_city → per-day active-trip counts for the
  /// route. Response is { data: [{date, count}] } → flattened to {date: count}.
  Future<Map<String, int>> calendar(String fromCity, String toCity) async {
    final res = await _dio.get<Map<String, dynamic>>('/trips/calendar', queryParameters: {
      'from_city': fromCity,
      'to_city': toCity,
    });
    final rows = (res.data?['data'] as List?) ?? const [];
    return {for (final r in rows) (r['date'] as String): ((r['count'] as num?)?.toInt() ?? 0)};
  }

  /// GET /trips/{id} — full detail.
  Future<TripCardItem> detail(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/trips/$id');
    return TripCardItem.fromJson(res.data!);
  }

  /// GET /trips/my — the driver's own trips.
  Future<PagedResult<TripCardItem>> mine({String? tab, String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>('/trips/my', queryParameters: {
      if (tab != null) 'tab': tab,
      if (cursor != null) 'cursor': cursor,
    });
    return PagedResult.fromJson(res.data!, TripCardItem.fromJson);
  }

  /// POST /trips — publish a trip (idempotent).
  Future<TripCardItem> create(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/trips',
      data: body,
      options: Options(headers: {'Idempotency-Key': uuidV4()}),
    );
    return TripCardItem.fromJson(res.data!);
  }

  /// GET /routes/price-suggestion?from&to → { suggested, min, max } price hints
  /// for the create-trip form.
  Future<({int suggested, int min, int max})> priceSuggestion(String from, String to) async {
    final res = await _dio.get<Map<String, dynamic>>('/routes/price-suggestion',
        queryParameters: {'from': from, 'to': to});
    final d = res.data ?? const {};
    return (
      suggested: ((d['suggested'] ?? 0) as num).toInt(),
      min: ((d['min'] ?? 0) as num).toInt(),
      max: ((d['max'] ?? 0) as num).toInt(),
    );
  }

  Future<void> like(String id) => _dio.post('/trips/$id/like');
  Future<void> unlike(String id) => _dio.delete('/trips/$id/like');
  Future<void> recordView(String id) => _dio.post('/trips/$id/view');

  // ── Owner trip management ────────────────────────────────────────────────
  /// PATCH /trips/{id} — edit price / comment / luggage / preferences.
  Future<void> edit(String id, Map<String, dynamic> patch) => _dio.patch('/trips/$id', data: patch);

  /// DELETE /trips/{id} — cancel the trip (optional reason).
  Future<void> cancel(String id, {String? reason}) =>
      _dio.delete('/trips/$id', data: {if (reason != null) 'reason': reason});

  /// PATCH /trips/{id}/complete — mark the trip finished.
  Future<void> complete(String id) => _dio.patch('/trips/$id/complete');

  /// POST /trips/{id}/seats — adjust available seats by +1 / -1.
  Future<void> adjustSeats(String id, int delta) => _dio.post('/trips/$id/seats', data: {'delta': delta});

  /// POST /trips/{id}/contact — reveal driver phone (after accepted).
  Future<String?> revealContact(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/trips/$id/contact');
    return res.data?['phone'] as String?;
  }
}
