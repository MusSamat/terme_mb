import '../models/place.dart';

/// Minutes after landing before a transfer leaves (passport control, luggage).
const kArrivalSlackMin = 30;

/// target_time results split for the «Подходят по времени» / «Остальные в
/// этот день» sections. Order inside each group is kept (the API ranks them).
({List<T> near, List<T> rest}) groupByTarget<T>(Iterable<T> items, bool? Function(T) nearOf) {
  final near = <T>[], rest = <T>[];
  for (final it in items) {
    (nearOf(it) == true ? near : rest).add(it);
  }
  return (near: near, rest: rest);
}

/// Listing time for a ride from the airport: landing + [kArrivalSlackMin].
DateTime departureAfterArrival(DateTime arrival) => arrival.add(const Duration(minutes: kArrivalSlackMin));

/// A chip / row name that reads like an airport title (Жалал-Абад oblast's
/// town «Манас» next to the «Манас · Бишкек» airport) needs its raion /
/// oblast line to tell them apart. The served city (Ош ↔ «Ош») never does.
bool collidesWithAirport(Place p, Iterable<Airport> airports, bool kg) {
  if (p.isAirport) return false;
  final n = p.name(kg).trim().toLowerCase();
  for (final a in airports) {
    if (a.place.id == p.id || a.serves?.id == p.id) continue; // the served city is the same place
    final names = {a.place.name(kg), a.title(kg), a.title(kg).split('·').first}.map((s) => s.trim().toLowerCase());
    if (names.contains(n)) return true;
  }
  return false;
}
