import 'package:dio/dio.dart';

import '../../models/passenger_request.dart';
import '../../utils/uuid.dart';
import '../paged_result.dart';

/// Passenger-requests domain — /passenger-requests endpoints (ТЗ §5.3).
class RequestsService {
  RequestsService(this._dio);
  final Dio _dio;

  Future<PagedResult<PassengerRequestItem>> list({String? from, String? to, String? date, String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>('/passenger-requests', queryParameters: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (date != null) 'date': date,
      if (cursor != null) 'cursor': cursor,
    });
    return PagedResult.fromJson(res.data!, PassengerRequestItem.fromJson);
  }

  Future<PassengerRequestItem> detail(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/passenger-requests/$id');
    return PassengerRequestItem.fromJson(res.data!);
  }

  Future<Map<String, int>> calendar() async {
    final res = await _dio.get<Map<String, dynamic>>('/passenger-requests/calendar');
    return res.data!.map((k, v) => MapEntry(k, (v as num).toInt()));
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
}
