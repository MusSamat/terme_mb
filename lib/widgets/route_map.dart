import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import 'osm_map.dart';

/// Small read-only route map for detail screens: the boarding pin (or the
/// settlement), stops and the destination, framed automatically. Renders
/// nothing when no coordinates are known.
class RouteMap extends StatelessWidget {
  const RouteMap({
    super.key,
    this.origin,
    this.destination,
    this.originPoint,
    this.destinationPoint,
    this.stops = const [],
    this.height = 170,
    this.accent = BrandColors.c600,
  });

  final Place? origin;
  final Place? destination;
  final MeetingPoint? originPoint;
  final MeetingPoint? destinationPoint;
  final List<Place> stops;
  final double height;
  final Color accent;

  static LatLng? _at(Place? p, MeetingPoint? pin) {
    if (pin != null) return LatLng(pin.lat, pin.lng);
    if (p != null && p.hasPoint) return LatLng(p.lat!, p.lng!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final a = _at(origin, originPoint);
    final b = _at(destination, destinationPoint);
    final mids = [for (final s in stops) if (s.hasPoint) LatLng(s.lat!, s.lng!)];
    final pts = [if (a != null) a, ...mids, if (b != null) b];
    if (pts.isEmpty) return const SizedBox.shrink();
    final line = [if (a != null) a, ...mids, if (b != null) b];
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl2),
      child: SizedBox(
        height: height,
        child: Stack(children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: pts.first,
              initialZoom: 13,
              initialCameraFit: pts.length > 1
                  ? CameraFit.coordinates(coordinates: pts, padding: const EdgeInsets.all(34), maxZoom: 15)
                  : null,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              osmTiles(),
              if (line.length > 1)
                PolylineLayer(polylines: [
                  Polyline(points: line, strokeWidth: 3.5, color: accent.withValues(alpha: 0.8)),
                ]),
              MarkerLayer(markers: [
                for (final m in mids)
                  Marker(point: m, width: 16, height: 16, child: const PinDot(color: InkColors.c500, size: 16)),
                if (a != null)
                  Marker(point: a, width: 30, height: 30, child: PinDot(color: accent, icon: Icons.trip_origin)),
                if (b != null)
                  Marker(
                    point: b,
                    width: 30,
                    height: 30,
                    child: PinDot(
                        color: AccentColors.c500,
                        icon: (destination?.isAirport ?? false) ? Icons.flight_rounded : Icons.flag_rounded),
                  ),
              ]),
            ],
          ),
          const OsmCredit(),
        ]),
      ),
    );
  }
}
