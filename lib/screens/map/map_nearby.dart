import 'dart:math' as math;

import '../../api/services/misc_services.dart';
import '../../models/passenger_request.dart';
import '../../models/place.dart';
import '../../models/trip_card_item.dart';
import '../../utils/location.dart';

/// Great-circle distance in km.
double haversineKm(LatLngPoint a, LatLngPoint b) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) + math.cos(rad(a.lat)) * math.cos(rad(b.lat)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

/// Pickup pin of a listing: its meeting point, else the origin settlement
/// (from the listing, else the searched «Откуда»). Null when nothing has coords.
MapItem? _pin({
  required String id,
  required MeetingPoint? point,
  required Place? origin,
  required Place? fallback,
  required String from,
  required String to,
  required DateTime? at,
  required int seats,
  int? price,
}) {
  final city = origin?.hasPoint == true ? origin : (fallback?.hasPoint == true ? fallback : null);
  if (at == null || (point == null && city == null)) return null;
  return MapItem(
    id: id,
    lat: point?.lat ?? city!.lat!,
    lng: point?.lng ?? city!.lng!,
    exact: point != null,
    originCity: from,
    destinationCity: to,
    departureAt: at,
    seats: seats,
    price: price,
  );
}

MapItem? tripPin(TripCardItem t, {Place? fallback}) => _pin(
      id: t.id,
      point: t.originPoint,
      origin: t.origin,
      fallback: fallback,
      from: t.originCity,
      to: t.destinationCity,
      at: t.departureAt,
      seats: t.seatsAvailable,
      price: t.pricePerSeat,
    );

MapItem? requestPin(PassengerRequestItem r, {Place? fallback}) => _pin(
      id: r.id,
      point: r.originPoint,
      origin: r.origin,
      fallback: fallback,
      from: r.originCity,
      to: r.destinationCity,
      at: r.departureDate,
      seats: r.seatsNeeded,
    );

typedef NearbyItem = ({MapItem item, double? km});

/// Results for the «Рядом» sheet: by distance from [me] (nearest first) when
/// known, else by departure time. (The feed API already hides departed ones.)
List<NearbyItem> sortResults(LatLngPoint? me, Iterable<MapItem> items) {
  final out = [
    for (final it in items) (item: it, km: me == null ? null : haversineKm(me, (lat: it.lat, lng: it.lng))),
  ];
  return out..sort((a, b) => me == null ? a.item.departureAt.compareTo(b.item.departureAt) : a.km!.compareTo(b.km!));
}
