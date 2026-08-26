/// Car catalog brand (GET /cars/catalog/brands).
class CarBrand {
  const CarBrand({required this.id, required this.name});
  final int id;
  final String name;
  factory CarBrand.fromJson(Map<String, dynamic> j) =>
      CarBrand(id: (j['id'] as num).toInt(), name: (j['name'] ?? '') as String);
}

/// Car catalog model (GET /cars/catalog/brands/{id}/models).
class CarModel {
  const CarModel({required this.id, required this.name, this.bodyType});
  final int id;
  final String name;
  final String? bodyType;
  factory CarModel.fromJson(Map<String, dynamic> j) => CarModel(
        id: (j['id'] as num).toInt(),
        name: (j['name'] ?? '') as String,
        bodyType: j['bodyType'] as String?,
      );
}

/// Car catalog colour (GET /cars/catalog/colors).
class CarColor {
  const CarColor({required this.id, required this.nameRu, required this.nameKy, required this.hex});
  final int id;
  final String nameRu;
  final String nameKy;
  final String hex; // e.g. #FFFFFF

  factory CarColor.fromJson(Map<String, dynamic> j) => CarColor(
        id: (j['id'] as num).toInt(),
        nameRu: (j['nameRu'] ?? '') as String,
        nameKy: (j['nameKy'] ?? '') as String,
        hex: (j['hex'] ?? '#000000') as String,
      );
}

/// A driver's registered vehicle (/cars).
class Car {
  const Car({
    required this.id,
    required this.make,
    required this.model,
    required this.plate,
    this.color,
    this.year,
    this.seatsCount = 4,
  });

  final String id;
  final String make;
  final String model;
  final String plate;
  final String? color;
  final int? year;
  final int seatsCount;

  String get title => '$make $model';

  factory Car.fromJson(Map<String, dynamic> j) => Car(
        id: (j['id'] ?? '') as String,
        make: (j['make'] ?? '') as String,
        model: (j['model'] ?? '') as String,
        plate: (j['plate'] ?? '') as String,
        color: j['color'] as String?,
        year: (j['year'] as num?)?.toInt(),
        seatsCount: (j['seatsCount'] ?? 4) as int,
      );
}
