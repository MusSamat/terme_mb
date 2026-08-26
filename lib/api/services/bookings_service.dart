import 'package:dio/dio.dart';

import '../../data/mock_app_data.dart';
import '../../utils/uuid.dart';
import '../paged_result.dart';

/// Bookings domain — /bookings endpoints (ТЗ §5.3).
class BookingsService {
  BookingsService(this._dio);
  final Dio _dio;

  Future<PagedResult<MockBooking>> mine({String? status, String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>('/bookings/my', queryParameters: {
      if (status != null) 'status': status,
      if (cursor != null) 'cursor': cursor,
    });
    return PagedResult.fromJson(res.data!, MockBooking.fromJson);
  }

  Future<PagedResult<MockBooking>> incoming({String? tripId, String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>('/bookings/incoming', queryParameters: {
      if (tripId != null) 'tripId': tripId,
      if (cursor != null) 'cursor': cursor,
    });
    return PagedResult.fromJson(res.data!, MockBooking.fromJson);
  }

  /// Returns the created booking's id so the UI can link straight to it
  /// (the waiting screen used to hardcode a fake "b1").
  Future<String?> create({required String tripId, required int seats, String? comment}) async {
    final res = await _dio.post<Map<String, dynamic>>('/bookings',
        data: {'tripId': tripId, 'seatsCount': seats, if (comment != null) 'comment': comment},
        options: Options(headers: {'Idempotency-Key': uuidV4()}));
    return res.data?['id'] as String?;
  }

  /// GET /bookings/{id} — a single booking's full detail.
  Future<MockBooking> get(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/bookings/$id');
    return MockBooking.fromJson(res.data!);
  }

  Future<void> accept(String id) => _dio.patch('/bookings/$id/accept');
  Future<void> reject(String id) => _dio.patch('/bookings/$id/reject');
  Future<void> cancel(String id) => _dio.patch('/bookings/$id/cancel');

  /// PATCH /bookings/{id}/no-show — driver marks the passenger as a no-show.
  Future<void> markNoShow(String id) => _dio.patch('/bookings/$id/no-show');
}
