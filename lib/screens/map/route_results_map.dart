import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../api/services/misc_services.dart';
import '../../models/place.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/location.dart';
import '../../widgets/map/map_marker.dart';
import '../../widgets/map/me_marker.dart';
import '../../widgets/osm_map.dart';
import 'map_nearby.dart';
import 'map_overlays.dart';

const _userZoom = 13.0;

/// The user dot joins the initial fit only when this close to the origin.
const _meFitKm = 50.0;

/// «Карта» view of one route's results: spec pins at each pickup point, the
/// user dot, and a «Рядом» sheet with the same results sorted by distance
/// from the user (by time without a location). Pin ↔ row selection is linked.
class RouteResultsMap extends ConsumerStatefulWidget {
  const RouteResultsMap({
    super.key,
    required this.items,
    required this.requests,
    required this.origin,
    required this.onOpen,
  });

  final List<MapItem> items;
  final bool requests;
  final Place? origin;
  final void Function(String id) onOpen;

  @override
  ConsumerState<RouteResultsMap> createState() => _RouteResultsMapState();
}

class _RouteResultsMapState extends ConsumerState<RouteResultsMap> with WidgetsBindingObserver {
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  bool _ready = false;
  double _mapH = 600;

  LocPermission? _perm;
  LatLngPoint? _me; // only a fix inside Kyrgyzstan
  bool _locating = false;
  String? _selected;

  LocationService get _loc => ref.read(locationServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final last = _loc.last;
    if (last != null && inKyrgyzstan(last)) _me = last;
    _checkPermission();
  }

  @override
  void didUpdateWidget(RouteResultsMap old) {
    super.didUpdateWidget(old);
    final ids = widget.items.map((e) => e.id).join(',');
    if (ids != old.items.map((e) => e.id).join(',')) {
      if (!widget.items.any((e) => e.id == _selected)) _selected = null;
      if (_ready) _map.fitCamera(_fit());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _map.dispose();
    _sheet.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  // ── Location ───────────────────────────────────────────────────────────────

  Future<void> _checkPermission() async {
    final s = await _loc.status();
    if (!mounted) return;
    setState(() {
      _perm = s;
      if (s != LocPermission.granted) _me = null;
    });
    if (s == LocPermission.granted) _locate(move: false);
  }

  Future<void> _locate({required bool move}) async {
    if (_locating) return;
    setState(() => _locating = true);
    final known = await _loc.lastKnown();
    if (!mounted) return;
    if (known != null && inKyrgyzstan(known)) {
      setState(() => _me = known);
      if (move) _toMe();
    }
    final fresh = await _loc.refine();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (fresh != null && inKyrgyzstan(fresh)) _me = fresh;
    });
    if (move) _toMe();
  }

  void _toMe() {
    final me = _me;
    if (me != null && _ready) _map.move(LatLng(me.lat, me.lng), math.max(_map.camera.zoom, _userZoom));
  }

  Future<void> _askPermission() async {
    final s = await askLocationPermission(context, _loc, _perm ?? LocPermission.denied);
    if (!mounted) return;
    setState(() => _perm = s);
    if (s == LocPermission.granted) _locate(move: true);
  }

  void _recenter() => _perm == LocPermission.granted ? _locate(move: true) : _askPermission();

  // ── Camera ─────────────────────────────────────────────────────────────────

  LatLng? get _originLatLng {
    final o = widget.origin;
    return o != null && o.hasPoint ? LatLng(o.lat!, o.lng!) : null;
  }

  CameraFit _fit() {
    final pts = [for (final it in widget.items) LatLng(it.lat, it.lng)];
    final o = _originLatLng;
    final me = _me;
    final anchor = pts.isNotEmpty ? pts.first : o;
    if (me != null && anchor != null && haversineKm(me, (lat: anchor.latitude, lng: anchor.longitude)) <= _meFitKm) {
      pts.add(LatLng(me.lat, me.lng));
    }
    if (pts.isEmpty) pts.add(o ?? kgCenter);
    final sheet = (_sheet.isAttached ? _sheet.size : 0.3) * _mapH;
    return CameraFit.coordinates(
      coordinates: pts,
      padding: EdgeInsets.fromLTRB(48, 72, 48, sheet + 40),
      maxZoom: pts.length == 1 ? 12 : 15,
      minZoom: 5,
    );
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void _tapPin(MapItem it) {
    if (_selected == it.id) return widget.onOpen(it.id);
    setState(() => _selected = it.id);
  }

  void _tapRow(MapItem it) {
    if (_selected == it.id) return widget.onOpen(it.id);
    setState(() => _selected = it.id);
    _map.move(LatLng(it.lat, it.lng), math.max(_map.camera.zoom, 14));
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  List<Marker> _markers() {
    Marker pin(MapItem it, bool selected) => Marker(
          key: ValueKey('pin-${it.id}'),
          point: LatLng(it.lat, it.lng),
          width: kMapPinSize.width,
          height: kMapPinSize.height,
          alignment: Alignment.topCenter,
          child: GestureDetector(
            onTap: () => _tapPin(it),
            child: MapMarker(requests: widget.requests, badge: it.seats > 0 ? it.seats : null, selected: selected),
          ),
        );
    MapItem? sel;
    final out = <Marker>[];
    for (final it in widget.items) {
      if (it.id == _selected) {
        sel = it;
      } else {
        out.add(pin(it, false));
      }
    }
    if (_me != null) {
      out.add(Marker(
        point: LatLng(_me!.lat, _me!.lng),
        width: kMeMarkerSize,
        height: kMeMarkerSize,
        child: const IgnorePointer(child: MeMarker()),
      ));
    }
    if (sel != null) out.add(pin(sel, true)); // selected on top
    return out;
  }

  Widget _nearbySheet(double height) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    final safe = MediaQuery.paddingOf(context).bottom;
    final rows = sortResults(_me, widget.items);
    // Peek = header + the first 1–2 rows (one on short screens / big text).
    final peek = (64 + 70.0 * (height < 560 ? 1 : 2)) * scale + safe;
    final minSize = (peek / height).clamp(0.14, 0.55);
    return DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: minSize,
      minChildSize: minSize,
      maxChildSize: 0.88,
      snap: true,
      builder: (context, scroll) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? InkColors.c900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
          boxShadow: const [BoxShadow(color: Color(0x331C1917), blurRadius: 16, offset: Offset(0, -2))],
        ),
        child: CustomScrollView(controller: scroll, slivers: [
          SliverToBoxAdapter(
            child: NearbyHeader(requests: widget.requests, count: rows.length),
          ),
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final e = rows[i];
              final selected = e.item.id == _selected;
              return NearbyTile(
                key: ValueKey('near-${e.item.id}'),
                item: e.item,
                requests: widget.requests,
                selected: selected,
                showOpen: selected,
                km: e.km,
                onTap: () => _tapRow(e.item),
              );
            },
          ),
          SliverToBoxAdapter(child: SizedBox(height: 12 + safe)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noPermission = _perm != null && _perm != LocPermission.granted;
    return LayoutBuilder(builder: (context, box) {
      _mapH = box.maxHeight;
      return Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCameraFit: _fit(),
            minZoom: 5,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () => _ready = true,
            onTap: (_, __) {
              if (_selected != null) setState(() => _selected = null);
            },
          ),
          children: [
            osmTiles(),
            if (_me != null && (_loc.accuracy ?? 1e9) < 1000)
              CircleLayer(circles: [
                CircleMarker(
                  point: LatLng(_me!.lat, _me!.lng),
                  radius: _loc.accuracy!,
                  useRadiusInMeter: true,
                  color: BrandColors.c600.withValues(alpha: 0.08),
                ),
              ]),
            MarkerLayer(markers: _markers()),
          ],
        ),
        if (noPermission) Positioned(top: 10, left: 12, right: 12, child: LocationBanner(onEnable: _askPermission)),
        _nearbySheet(box.maxHeight),
        ListenableBuilder(
          listenable: _sheet,
          builder: (context, _) {
            final frac = _sheet.isAttached ? _sheet.size : 0.0;
            final bottom = frac * box.maxHeight;
            return Positioned.fill(
              child: Stack(children: [
                Positioned(left: 0, bottom: bottom, child: const OsmCredit()),
                // Recenter rides above the sheet until it covers half the map.
                if (frac <= 0.5)
                  Positioned(
                    right: 12,
                    bottom: bottom + 12,
                    child: FloatingActionButton.small(
                      heroTag: 'map_me',
                      tooltip: 'map.recenter'.tr(),
                      backgroundColor: Colors.white,
                      onPressed: _recenter,
                      child: _locating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded, color: BrandColors.c600),
                    ),
                  ),
              ]),
            );
          },
        ),
      ]);
    });
  }
}
