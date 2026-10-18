import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../models/place.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/locale.dart';
import '../../utils/location.dart';
import '../../widgets/app_button.dart';
import '../../widgets/osm_map.dart';

/// Pick an exact meeting point inside [place] (Yandex-style): the pin stays in
/// the centre and the map moves under it. Бишкек / Ош get quick spots and
/// жилмассив search on top. Returns the point, or null if dismissed.
Future<MeetingPoint?> pickMeetingPoint(
  BuildContext context, {
  required Place place,
  MeetingPoint? initial,
  required String title,
  Color accent = BrandColors.c600,
}) =>
    Navigator.of(context, rootNavigator: true).push<MeetingPoint>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PointPickerScreen(place: place, initial: initial, title: title, accent: accent),
    ));

class PointPickerScreen extends ConsumerStatefulWidget {
  const PointPickerScreen({
    super.key,
    required this.place,
    this.initial,
    required this.title,
    this.accent = BrandColors.c600,
  });

  final Place place;
  final MeetingPoint? initial;
  final String title;
  final Color accent;

  @override
  ConsumerState<PointPickerScreen> createState() => _PointPickerScreenState();
}

class _PointPickerScreenState extends ConsumerState<PointPickerScreen> {
  final _map = MapController();
  late final _note = TextEditingController(text: widget.initial?.address ?? '');
  final _search = TextEditingController();
  late LatLng _center = widget.initial != null
      ? LatLng(widget.initial!.lat, widget.initial!.lng)
      : (widget.place.hasPoint ? LatLng(widget.place.lat!, widget.place.lng!) : kgCenter);
  List<MeetingSpot> _spots = const [];
  Timer? _debounce;
  bool _locating = false;

  bool get _bigCity => widget.place.isCapital;

  @override
  void initState() {
    super.initState();
    if (_bigCity) _loadSpots('');
    // No saved pin yet → start where the user is, when they're in this place.
    if (widget.initial == null) _jumpToMe(silent: true);
  }

  @override
  void dispose() {
    _note.dispose();
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSpots(String q) async {
    try {
      final r = await ref.read(citiesServiceProvider).spots(widget.place.id, query: q);
      if (mounted) setState(() => _spots = r);
    } catch (_) {/* spots are a convenience */}
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _loadSpots(v));
  }

  Future<void> _jumpToMe({bool silent = false}) async {
    setState(() => _locating = true);
    final me = await ref.read(locationServiceProvider).current(ask: !silent);
    if (!mounted) return;
    setState(() => _locating = false);
    if (me == null) return;
    final p = LatLng(me.lat, me.lng);
    // Only snap when the user is inside (≈ 30 km of) the chosen settlement.
    if (widget.place.hasPoint &&
        const Distance().as(LengthUnit.Kilometer, p, LatLng(widget.place.lat!, widget.place.lng!)) > 30) {
      return;
    }
    _map.move(p, 16);
    setState(() => _center = p);
  }

  void _goTo(MeetingSpot s) {
    final p = LatLng(s.lat, s.lng);
    _map.move(p, 16);
    setState(() {
      _center = p;
      if (_note.text.trim().isEmpty && s.kind == 'spot') _note.text = s.name(isKg(context));
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final kg = isKg(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          if (widget.initial != null)
            TextButton(
              onPressed: () => Navigator.of(context).pop(const MeetingPoint(lat: double.nan, lng: double.nan)),
              child: Text('point.remove'.tr(), style: const TextStyle(color: CoralColors.c600, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: Column(children: [
        if (_bigCity)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'point.search_area'.tr(),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: InkColors.c100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide.none),
              ),
            ),
          ),
        if (_spots.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _spots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final s = _spots[i];
                return ActionChip(
                  avatar: Icon(s.kind == 'spot' ? Icons.directions_bus_rounded : Icons.home_work_outlined,
                      size: 16, color: widget.accent),
                  label: Text(s.name(kg), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  onPressed: () => _goTo(s),
                );
              },
            ),
          ),
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: widget.initial != null ? 16 : (_bigCity ? 12 : 14),
                onPositionChanged: (camera, _) => _center = camera.center,
              ),
              children: [osmTiles()],
            ),
            // Fixed centre pin — the map moves under it.
            IgnorePointer(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Icon(Icons.location_on_rounded, size: 44, color: widget.accent),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'picker_me',
                backgroundColor: Colors.white,
                onPressed: _locating ? null : _jumpToMe,
                child: _locating
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.my_location_rounded, color: widget.accent),
              ),
            ),
            const OsmCredit(),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: _note,
                maxLength: 200,
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  hintText: 'point.note_hint'.tr(),
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  filled: true,
                  fillColor: InkColors.c100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'point.done'.tr(),
                onPressed: () => Navigator.of(context).pop(MeetingPoint(
                  lat: _center.latitude,
                  lng: _center.longitude,
                  address: _note.text.trim().isEmpty ? null : _note.text.trim(),
                )),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// A NaN point is the picker's «remove» signal.
extension MeetingPointRemoval on MeetingPoint {
  bool get isRemoval => lat.isNaN;
}
