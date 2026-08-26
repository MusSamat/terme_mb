import 'package:dio/dio.dart';

import '../../models/pending_rating.dart';

/// Ratings domain — POST /ratings (ТЗ §14). Rate the counterparty after a trip.
class RatingsService {
  RatingsService(this._dio);
  final Dio _dio;

  /// GET /ratings/pending — trips awaiting the current user's rating.
  Future<List<PendingRating>> pending() async {
    final res = await _dio.get<Map<String, dynamic>>('/ratings/pending');
    final rows = (res.data?['data'] as List?) ?? const [];
    return rows.map((e) => PendingRating.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<void> create({
    required String tripId,
    required String rateeId,
    required int score,
    List<String> tags = const [],
    String? comment,
  }) =>
      _dio.post('/ratings', data: {
        'tripId': tripId,
        'rateeId': rateeId,
        'score': score,
        'tags': tags,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
}
