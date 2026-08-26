import 'package:dio/dio.dart';

import '../../models/passenger_request.dart';
import '../../models/trip_card_item.dart';
import '../paged_result.dart';

/// Liked listings — GET /users/me/likes?type=trip|passenger_request.
/// Cursor-paginated; item shapes match trips-search / passenger-requests-list
/// (backend hydrates through the same mappers). Powers the «Избранное» tab.
class LikesService {
  LikesService(this._dio);
  final Dio _dio;

  Future<PagedResult<TripCardItem>> trips({String? cursor, int limit = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me/likes', queryParameters: {
      'type': 'trip',
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    });
    return PagedResult.fromJson(res.data!, TripCardItem.fromJson);
  }

  Future<PagedResult<PassengerRequestItem>> requests({String? cursor, int limit = 20}) async {
    final res = await _dio.get<Map<String, dynamic>>('/users/me/likes', queryParameters: {
      'type': 'passenger_request',
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    });
    return PagedResult.fromJson(res.data!, PassengerRequestItem.fromJson);
  }
}
