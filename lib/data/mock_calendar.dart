/// Per-day ride counts for the calendar / date-stepper — derived so the
/// calendar looks populated without a backend. Replaced by the
/// /trips/calendar (and /passenger-requests/calendar) endpoints in ТЗ step 2.
Map<String, int> mockCalendarCounts() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final counts = <String, int>{};
  for (var i = 0; i < 45; i++) {
    final d = today.add(Duration(days: i));
    // Deterministic pseudo-spread: some empty days, weekends busier.
    final base = (d.day * 3 + d.month) % 7;
    final weekend = d.weekday >= 6 ? 2 : 0;
    final n = (base + weekend - 2).clamp(0, 8);
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    counts[key] = n;
  }
  return counts;
}
