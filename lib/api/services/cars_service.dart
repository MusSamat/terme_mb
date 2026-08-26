import 'package:dio/dio.dart';

import '../../models/car.dart';

/// Cars domain — /cars CRUD (driver's vehicles).
class CarsService {
  CarsService(this._dio);
  final Dio _dio;

  Future<List<Car>> list() async {
    final res = await _dio.get<Map<String, dynamic>>('/cars');
    final rows = (res.data?['data'] as List?) ?? const [];
    return rows.map((e) => Car.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// GET /cars/catalog/brands — cached reference data for the make picker.
  Future<List<CarBrand>> brands() async {
    final res = await _dio.get<Map<String, dynamic>>('/cars/catalog/brands');
    final rows = (res.data?['data'] as List?) ?? const [];
    return rows.map((e) => CarBrand.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// GET /cars/catalog/brands/{id}/models — models for the selected brand.
  Future<List<CarModel>> models(int brandId) async {
    final res = await _dio.get<Map<String, dynamic>>('/cars/catalog/brands/$brandId/models');
    final rows = (res.data?['data'] as List?) ?? const [];
    return rows.map((e) => CarModel.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  /// GET /cars/catalog/colors — reference colours (name + hex swatch).
  Future<List<CarColor>> colors() async {
    final res = await _dio.get<Map<String, dynamic>>('/cars/catalog/colors');
    final rows = (res.data?['data'] as List?) ?? const [];
    return rows.map((e) => CarColor.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Car> create({
    required String make,
    required String model,
    required String plate,
    String? color,
    int? year,
    int seatsCount = 4,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/cars', data: {
      'make': make,
      'model': model,
      'plate': plate,
      if (color != null && color.isNotEmpty) 'color': color,
      if (year != null) 'year': year,
      'seatsCount': seatsCount,
    });
    return Car.fromJson(res.data!);
  }

  Future<void> remove(String id) => _dio.delete('/cars/$id');
}
