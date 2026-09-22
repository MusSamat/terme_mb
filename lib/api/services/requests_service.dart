import 'package:dio/dio.dart';

import '../../models/passenger_request.dart';
import '../../models/request_response.dart';
import '../../utils/uuid.dart';
import '../paged_result.dart';

/// Passenger-requests domain — /passenger-requests endpoints (ТЗ §5.3).
class RequestsService {
  RequestsService(this._dio);
  final Dio _dio;

  Future<PagedResult<PassengerRequestItem>> list({String? from, String? to, String? date, int? seats, String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>('/passenger-requests', queryParameters: {
      if (from != null && from.isNotEmpty) 'from_city': from,
      if (to != null && to.isNotEmpty) 'to_city': to,
      if (date != null) 'date': date,
      if (seats != null) 'seats': seats.toString(),
      if (cursor != null) 'cursor': cursor,
    });
    return PagedResult.fromJson(res.data!, PassengerRequestItem.fromJson);
  }

  Future<PassengerRequestItem> detail(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/passenger-requests/$id');
    return PassengerRequestItem.fromJson(res.data!);
  }

  /// GET /passenger-requests/calendar?from_city&to_city → per-day open-request
  /// counts for the route. { data: [{date, count}] } → {date: count}.
  Future<Map<String, int>> calendar(String fromCity, String toCity) async {
    final res = await _dio.get<Map<String, dynamic>>('/passenger-requests/calendar', queryParameters: {
      'from_city': fromCity,
      'to_city': toCity,
    });
    final rows = (res.data?['data'] as List?) ?? const [];
    return {for (final r in rows) (r['date'] as String): ((r['count'] as num?)?.toInt() ?? 0)};
  }

  Future<PagedResult<PassengerRequestItem>> mine({String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>('/passenger-requests/my',
        queryParameters: {if (cursor != null) 'cursor': cursor});
    return PagedResult.fromJson(res.data!, PassengerRequestItem.fromJson);
  }

  Future<PassengerRequestItem> create(Map<String, dynamic> body) async {
    final res = await _dio.post<Map<String, dynamic>>('/passenger-requests',
        data: body, options: Options(headers: {'Idempotency-Key': uuidV4()}));
    return PassengerRequestItem.fromJson(res.data!);
  }

  /// POST /passenger-requests/{id}/respond — driver offers price + time.
  Future<void> respond(String requestId, {required int price, String? departureTime, String? message}) =>
      _dio.post('/passenger-requests/$requestId/respond', data: {
        'price': price,
        if (departureTime != null) 'departureTime': departureTime,
        if (message != null) 'message': message,
      });

  Future<void> like(String id) => _dio.post('/passenger-requests/$id/like');
  Future<void> unlike(String id) => _dio.delete('/passenger-requests/$id/like');

  /// PATCH /passenger-requests/{id} — edit own open request (seats/date/comment).
  Future<void> edit(String id, Map<String, dynamic> patch) => _dio.patch('/passenger-requests/$id', data: patch);

  /// DELETE /passenger-requests/{id} — cancel the passenger's own request.
  Future<void> cancel(String id) => _dio.delete('/passenger-requests/$id');

  /// POST /passenger-requests/{id}/view — deduped view tracking.
  Future<void> recordView(String id) => _dio.post('/passenger-requests/$id/view');

  /// POST /passenger-requests/{id}/contact — reveal the passenger's phone.
  Future<String?> revealContact(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/passenger-requests/$id/contact');
    return res.data?['phone'] as String?;
  }

  /// GET /passenger-requests/{id}/responses — driver offers on the request
  /// (owner-only). The backend returns a bare array, not a paged envelope.
  Future<List<RequestResponse>> responses(String requestId) async {
    final res = await _dio.get<List<dynamic>>('/passenger-requests/$requestId/responses');
    return (res.data ?? const [])
        .map((e) => RequestResponse.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// POST /passenger-requests/{requestId}/respond/{responseId}/accept — accept a
  /// driver's offer; the backend creates a booking and returns its id.
  Future<String?> acceptResponse(String requestId, String responseId) async {
    final res = await _dio.post<Map<String, dynamic>>(
        '/passenger-requests/$requestId/respond/$responseId/accept');
    return res.data?['bookingId'] as String?;
  }

  /// POST /passenger-requests/{requestId}/respond/{responseId}/decline.
  Future<void> declineResponse(String requestId, String responseId) =>
      _dio.post('/passenger-requests/$requestId/respond/$responseId/decline');
}
