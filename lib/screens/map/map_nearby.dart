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

/// Pickup pin of a loaded list item (shown while /map/route loads): its
/// meeting point, else the API's boarding lat/lng (the origin settlement),
/// else the searched «Откуда». Null when nothing has coords.
MapItem? _pin({
  required String id,
  required MeetingPoint? point,
  required double? lat,
  required double? lng,
  required Place? fallback,
  required String Function(bool kg) from,
  required String Function(bool kg) to,
  required DateTime? at,
  required int seats,
  int? price,
}) {
  final ({double lat, double lng})? pt = point != null
      ? (lat: point.lat, lng: point.lng)
      : lat != null && lng != null
          ? (lat: lat, lng: lng)
          : fallback?.hasPoint == true
              ? (lat: fallback!.lat!, lng: fallback.lng!)
              : null;
  if (at == null || pt == null) return null;
  return MapItem(
    id: id,
    lat: pt.lat,
    lng: pt.lng,
    exact: point != null,
    originCity: from(false),
    destinationCity: to(false),
    originKg: from(true),
    destinationKg: to(true),
    departureAt: at,
    seats: seats,
    price: price,
  );
}

MapItem? tripPin(TripCardItem t, {Place? fallback}) => _pin(
      id: t.id,
      point: t.originPoint,
      lat: t.lat,
      lng: t.lng,
      fallback: fallback,
      from: t.originName,
      to: t.destinationName,
      at: t.departureAt,
      seats: t.seatsAvailable,
      price: t.pricePerSeat,
    );

MapItem? requestPin(PassengerRequestItem r, {Place? fallback}) => _pin(
      id: r.id,
      point: r.originPoint,
      lat: r.lat,
      lng: r.lng,
      fallback: fallback,
      from: r.originName,
      to: r.destinationName,
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
