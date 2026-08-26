import 'dart:io';

import 'package:dio/dio.dart';

/// Complaints domain — POST /complaints (ТЗ §16). Multipart: text fields plus up
/// to 5 image attachments. One of targetUserId / targetTripId is required.
class ComplaintsService {
  ComplaintsService(this._dio);
  final Dio _dio;

  Future<void> create({
    required String category,
    required String description,
    String? targetUserId,
    String? targetTripId,
    List<File> attachments = const [],
  }) async {
    final form = FormData.fromMap({
      'category': category,
      'description': description,
      if (targetUserId != null) 'targetUserId': targetUserId,
      if (targetTripId != null) 'targetTripId': targetTripId,
    });
    for (final f in attachments.take(5)) {
      form.files.add(MapEntry(
        'attachments',
        await MultipartFile.fromFile(
          f.path,
          filename: f.path.split('/').last,
          contentType: DioMediaType('image', 'jpeg'),
        ),
      ));
    }
    await _dio.post('/complaints', data: form);
  }
}
