import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/driver_stats.dart';

/// Driver verification domain — /drivers/* (become a driver, upload docs).
class DriversService {
  DriversService(this._dio);
  final Dio _dio;

  /// GET /drivers/me/stats → total trips, rating, 30-day cancellations.
  Future<DriverStats> stats() async {
    final res = await _dio.get<Map<String, dynamic>>('/drivers/me/stats');
    return DriverStats.fromJson(res.data ?? const {});
  }

  /// The six document slots the backend requires for a verification submission.
  static const docCategories = [
    'license',
    'license_back',
    'car_passport',
    'car_passport_back',
    'car_photo',
    'selfie',
  ];

  /// GET /drivers/verification/status → { status, ... }.
  Future<Map<String, dynamic>> status() async {
    final res = await _dio.get<Map<String, dynamic>>('/drivers/verification/status');
    return res.data ?? const {};
  }

  Future<MultipartFile> _file(File f) => MultipartFile.fromFile(
        f.path,
        filename: f.path.split('/').last,
        contentType: DioMediaType('image', 'jpeg'),
      );

  /// POST /drivers/verification — atomic submission: 6 doc images + car fields.
  Future<void> submit({
    required String carMake,
    required String carModel,
    required int carYear,
    required String carColor,
    required String carPlate,
    required int seatsCount,
    required Map<String, File> docs, // keyed by docCategories
  }) async {
    final form = FormData.fromMap({
      'carMake': carMake,
      'carModel': carModel,
      'carYear': carYear,
      'carColor': carColor,
      'carPlate': carPlate,
      'seatsCount': seatsCount,
    });
    for (final cat in docCategories) {
      final f = docs[cat];
      if (f != null) form.files.add(MapEntry(cat, await _file(f)));
    }
    await _dio.post('/drivers/verification', data: form);
  }

  /// POST /drivers/verification/upload?category=... — replace one document.
  Future<void> uploadDoc(String category, File image) async {
    final form = FormData.fromMap({'file': await _file(image)});
    await _dio.post('/drivers/verification/upload', data: form, queryParameters: {'category': category});
  }

  /// PATCH /drivers/car-photo — swap the car photo.
  Future<void> updateCarPhoto(File image) async {
    final form = FormData.fromMap({'file': await _file(image)});
    await _dio.patch('/drivers/car-photo', data: form);
  }
}
