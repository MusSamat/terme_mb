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
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (date != null) 'date': date,
      if (cursor != null) 'cursor': cursor,
      ...?filters,
    });
    return PagedResult.fromJson(res.data!, TripCardItem.fromJson);
  }

  /// GET /trips/calendar — per-day availability counts.
  Future<Map<String, int>> calendar({String? from, String? to}) async {
    final res = await _dio.get<Map<String, dynamic>>('/trips/calendar', queryParameters: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return res.data!.map((k, v) => MapEntry(k, (v as num).toInt()));
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

  Future<void> like(String id) => _dio.post('/trips/$id/like');
  Future<void> unlike(String id) => _dio.delete('/trips/$id/like');
  Future<void> recordView(String id) => _dio.post('/trips/$id/view');

  /// POST /trips/{id}/contact — reveal driver phone (after accepted).
  Future<String?> revealContact(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/trips/$id/contact');
    return res.data?['phone'] as String?;
  }
}
