import 'package:dio/dio.dart';

import '../../models/review.dart';
import '../../models/self_user.dart';

/// Public user data — /users/{id} profile + /users/{id}/ratings reviews.
class UsersService {
  UsersService(this._dio);
  final Dio _dio;

  Future<SelfUser> publicProfile(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/users/$id');
    return SelfUser.fromJson(res.data!);
  }

  Future<List<Review>> ratings(String id, {String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>('/users/$id/ratings',
        queryParameters: {if (cursor != null) 'cursor': cursor});
    final rows = (res.data?['data'] as List?) ?? const [];
    return rows.map((e) => Review.fromJson((e as Map).cast<String, dynamic>())).toList();
  }
}
