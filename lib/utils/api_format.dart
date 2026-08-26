// Pure request-formatting helpers for the API contract. Kept free of Flutter/
// Dio so they're trivially unit-testable — this is where the silent contract
// mismatches (feed date, price) are pinned down by tests.

/// The feed `date` query param.
///
/// - `'any'` → `null` (explicit "no date filter").
/// - empty → today.
/// - otherwise the given `YYYY-MM-DD`.
///
/// Always returned as a full ISO datetime anchored at Kyrgyzstan midnight
/// (`+06:00`). The API validates this field as `z.string().datetime({offset:
/// true})`; a bare `YYYY-MM-DD` is rejected with `VALIDATION_ERROR`. Mirrors the
/// web's `normalizeDate`. `now` is injectable for deterministic tests.
String? apiFeedDate(String date, {DateTime? now}) {
  if (date == 'any') return null;
  final ymd = date.isEmpty ? ymdOf(now ?? DateTime.now()) : date;
  return '${ymd}T00:00:00+06:00';
}

/// `YYYY-MM-DD` for a local date.
String ymdOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Price must not start with `0` — drop leading zeros as the user types.
String stripLeadingZeros(String s) =>
    s.length > 1 && s.startsWith('0') ? s.replaceFirst(RegExp(r'^0+'), '') : s;
