import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../api/services/misc_services.dart';
import '../../models/place.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/api_format.dart';
import '../../utils/date_format.dart';
import '../../utils/locale.dart';
import '../../utils/location.dart';
import '../../widgets/app_button.dart';
import '../../widgets/city_picker.dart';
import '../../widgets/osm_map.dart';

/// Listings on the map (GET /v1/map): trips or requests inside the visible
/// area, grid-clustered by the server. Bubbles zoom in, markers open a short
/// preview → the listing. Filters: destination, date, ride kind.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.requests = false, this.to, this.ride});

  final bool requests;
  final Place? to;
  final String? ride; // intercity | airport

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _map = MapController();
  late bool _requests = widget.requests;
  late Place? _to = widget.to;
  String? _date; // YYYY-MM-DD, null = any upcoming
  MapListings _data = const MapListings();
  bool _loading = false;
  bool _failed = false;
  bool _locating = false;
  bool _ready = false;
  Timer? _debounce;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _locate(silent: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Color get _accent => _requests ? GrapeColors.c600 : BrandColors.c600;

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _load() async {
    final cam = _map.camera;
    final b = cam.visibleBounds;
    final seq = ++_seq;
    setState(() => _loading = true);
    try {
      final r = await ref.read(mapServiceProvider).listings(
            kind: _requests ? 'requests' : 'trips',
            bbox: (west: b.west, south: b.south, east: b.east, north: b.north),
            zoom: cam.zoom.round(),
            toId: _to?.id,
            ride: widget.ride,
            date: _date == null ? null : apiFeedDate(_date!),
          );
      if (!mounted || seq != _seq) return;
      setState(() {
        _data = r;
        _failed = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _locate({bool silent = false}) async {
    setState(() => _locating = true);
    final me = await ref.read(locationServiceProvider).current(ask: !silent);
    if (!mounted) return;
    setState(() => _locating = false);
    if (me == null || !inKyrgyzstan(me) || !_ready) return;
    _map.move(LatLng(me.lat, me.lng), 11);
    _load();
  }

  Future<void> _pickTo() async {
    final p = await showCityPicker(context);
    if (p == null || !mounted) return;
    setState(() => _to = p);
    _load();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 60)),
      initialDate: _date != null ? DateTime.parse(_date!) : now,
    );
    if (d == null || !mounted) return;
    setState(() => _date = ymdOf(d));
    _load();
  }

  void _openItem(MapItem it) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ItemSheet(item: it, requests: _requests),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final kg = isKg(context);
    final me = ref.read(locationServiceProvider).last;
    final empty = !_loading && !_failed && _data.items.isEmpty && _data.clusters.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('map.title'.tr(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, icon: const Icon(Icons.directions_car_rounded, size: 18), label: Text('map.trips'.tr())),
              ButtonSegment(value: true, icon: const Icon(Icons.person_pin_circle_rounded, size: 18), label: Text('map.requests'.tr())),
            ],
            selected: {_requests},
            onSelectionChanged: (s) {
              setState(() => _requests = s.first);
              _load();
            },
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              InputChip(
                avatar: const Icon(Icons.flag_rounded, size: 16),
                label: Text(_to == null ? 'map.any_destination'.tr() : '${'map.to'.tr()} ${_to!.name(kg)}'),
                onPressed: _pickTo,
                onDeleted: _to == null
                    ? null
                    : () {
                        setState(() => _to = null);
                        _load();
                      },
              ),
              const SizedBox(width: 8),
              InputChip(
                avatar: const Icon(Icons.event_rounded, size: 16),
                label: Text(_date == null ? 'map.any_date'.tr() : departureLabel(DateTime.parse(_date!)).date),
                onPressed: _pickDate,
                onDeleted: _date == null
                    ? null
                    : () {
                        setState(() => _date = null);
                        _load();
                      },
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: me != null && inKyrgyzstan(me) ? LatLng(me.lat, me.lng) : kgCenter,
                initialZoom: me != null && inKyrgyzstan(me) ? 11 : 6.5,
                minZoom: 5,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                onMapReady: () {
                  _ready = true;
                  _load();
                },
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture) _schedule();
                },
                onMapEvent: (e) {
                  if (e is MapEventMoveEnd && e.source != MapEventSource.dragEnd) _schedule();
                },
              ),
              children: [
                osmTiles(),
                MarkerLayer(markers: [
                  for (final c in _data.clusters)
                    Marker(
                      point: LatLng(c.lat, c.lng),
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: () => _map.move(LatLng(c.lat, c.lng), (_map.camera.zoom + 2).clamp(5, 18)),
                        child: _Bubble(count: c.count, color: _accent),
                      ),
                    ),
                  for (final it in _data.items)
                    Marker(
                      point: LatLng(it.lat, it.lng),
                      width: 74,
                      height: 34,
                      child: GestureDetector(
                        onTap: () => _openItem(it),
                        child: _PriceMarker(item: it, color: _accent, requests: _requests),
                      ),
                    ),
                  if (me != null)
                    Marker(
                      point: LatLng(me.lat, me.lng),
                      width: 18,
                      height: 18,
                      child: const PinDot(color: Color(0xFF2F80ED), size: 18),
                    ),
                ]),
              ],
            ),
            if (_loading)
              const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
            if (_failed || empty)
              Positioned(
                top: 12,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _failed ? _load : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: dark ? InkColors.c900 : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: AppShadows.card,
                      ),
                      child: Text(
                        _failed ? 'map.load_failed'.tr() : (_requests ? 'map.empty_requests'.tr() : 'map.empty_trips'.tr()),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _failed ? CoralColors.c600 : InkColors.c500),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 12,
              bottom: 24,
              child: FloatingActionButton.small(
                heroTag: 'map_me',
                backgroundColor: Colors.white,
                onPressed: _locating ? null : _locate,
                child: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.my_location_rounded, color: _accent),
              ),
            ),
            const OsmCredit(),
          ]),
        ),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.count, required this.color});
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Text(count > 99 ? '99+' : '$count',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
      );
}

class _PriceMarker extends StatelessWidget {
  const _PriceMarker({required this.item, required this.color, required this.requests});
  final MapItem item;
  final Color color;
  final bool requests;

  @override
  Widget build(BuildContext context) {
    final label = !requests && item.price != null ? '${item.price} ${'card.som'.tr()}' : hhmm(item.departureAt);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Text(label,
            maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: color)),
      ),
    );
  }
}

class _ItemSheet extends StatelessWidget {
  const _ItemSheet({required this.item, required this.requests});
  final MapItem item;
  final bool requests;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final when = departureLabel(item.departureAt);
    final seats = requests
        ? 'map.seats_needed'.tr(namedArgs: {'n': '${item.seats}'})
        : 'map.seats_free'.tr(namedArgs: {'n': '${item.seats}'});
    return Container(
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999))),
          ),
          const SizedBox(height: 14),
          Text('${item.originCity} → ${item.destinationCity}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
          const SizedBox(height: 6),
          Text(
            [
              '${when.date}, ${when.time}',
              seats,
              if (!requests && item.price != null) '${item.price} ${'map.som_per_seat'.tr()}',
            ].join(' · '),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500),
          ),
          if (!item.exact) ...[
            const SizedBox(height: 4),
            Text('map.approx_point'.tr(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
          ],
          const SizedBox(height: 16),
          AppButton(
            label: requests ? 'map.open_request'.tr() : 'map.open_trip'.tr(),
            onPressed: () {
              Navigator.of(context).pop();
              context.push(requests ? '/requests/${item.id}' : '/trips/${item.id}');
            },
          ),
        ]),
      ),
    );
  }
}
