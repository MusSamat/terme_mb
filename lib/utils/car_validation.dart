/// Single source of truth for car-details validation — shared by the driver
/// verification wizard AND the add-car block (garage / create). Mirrors the web
/// `lib/utils/plate.ts` + backend rules so the client never sends data the server
/// will reject. Pure (no Flutter / no l10n) so it's trivially unit-testable.
class CarValidation {
  CarValidation._();

  static const int minYear = 2000;

  /// Uppercase, keep only A–Z / 0–9, clamp to 10 chars (KG plate standard).
  static String normalizePlate(String raw) {
    final norm = raw.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    return norm.length > 10 ? norm.substring(0, 10) : norm;
  }

  /// Valid KG plate: 4–10 alphanumerics (covers 2016+ `01KG123ABC` and old ones).
  static bool plateValid(String plate) => RegExp(r'^[A-Z0-9]{4,10}$').hasMatch(normalizePlate(plate));

  static bool makeValid(String s) => s.trim().isNotEmpty;
  static bool modelValid(String s) => s.trim().isNotEmpty;
  static bool colorValid(String s) => s.trim().isNotEmpty;

  /// Real year between [minYear] and [maxYear] (defaults to the current year).
  static bool yearValid(String year, {int? maxYear}) {
    final y = int.tryParse(year.trim());
    final max = maxYear ?? DateTime.now().year;
    return y != null && y >= minYear && y <= max;
  }

  static bool seatsValid(int seats) => seats >= 1 && seats <= 7;
}
