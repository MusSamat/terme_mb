import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/feed_filters.dart';
import '../../models/place.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/api_format.dart';
import '../../utils/locale.dart';
import '../../utils/location.dart';
import '../../widgets/app_button.dart';
import '../../widgets/date_picker_modal.dart';
import '../../widgets/route_search_sheet.dart';
import 'map_overlays.dart';

/// Map entry = route form first (BlaBlaCar-style): «Откуда» + «Куда» (+ date),
/// then the route's results open on the «Карта» view. Location only helps:
/// after the pre-permission card it pre-fills «Откуда» with the nearest
/// settlement (marked «Рядом с вами», editable); the form never waits for it.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.requests, this.to, this.ride});

  /// null → by active mode (passenger → trips, driver → requests).
  final bool? requests;
  final Place? to;
  final String? ride; // intercity | airport

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with WidgetsBindingObserver {
  late bool _requests = widget.requests ?? ref.read(authProvider).activeMode == ActiveMode.driver;
  Place? _from;
  late Place? _to = widget.to;
  bool _fromNearby = false; // «Откуда» was filled from the location
  String _date = 'any'; // 'any' | '' (today) | YYYY-MM-DD
  bool _filling = false;

  LocationService get _loc => ref.read(locationServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onOpen());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the settings with the permission now on → fill «Откуда».
    if (state == AppLifecycleState.resumed && _from == null) {
      _loc.status().then((s) {
        if (s == LocPermission.granted) _fillFrom();
      });
    }
  }

  /// Every open while not granted shows the card (it asks the OS only from
  /// «Разрешить», so the prompt never loops).
  Future<void> _onOpen() async {
    if (!mounted) return;
    var s = await _loc.status();
    if (!mounted) return;
    if (s != LocPermission.granted) s = await askLocationPermission(context, _loc, s);
    if (s == LocPermission.granted) _fillFrom();
  }

  Future<void> _fillFrom() async {
    if (_from != null || _filling || !mounted) return;
    setState(() => _filling = true);
    try {
      final me = _loc.last ?? await _loc.lastKnown() ?? await _loc.refine();
      if (me == null || !inKyrgyzstan(me)) return;
      final place = await ref.read(citiesServiceProvider).nearest(me.lat, me.lng);
      if (!mounted || place == null || _from != null) return;
      setState(() {
        _from = place;
        _fromNearby = true;
      });
    } catch (_) {
      // best-effort: the user picks «Откуда» by hand
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  Future<void> _editRoute({required bool focusTo}) async {
    final r = await showRouteSearchSheet(context, from: _from, to: _to, focusTo: focusTo);
    if (r == null || !mounted) return;
    setState(() {
      if (r.from?.id != _from?.id) _fromNearby = false;
      _from = r.from;
      _to = r.to;
    });
  }

  void _swap() => setState(() {
        final f = _from;
        _from = _to;
        _to = f;
        _fromNearby = false;
      });

  void _submit() => context.push(
        '/results?mode=${_requests ? 'requests' : 'trips'}&view=map',
        extra: FeedFilters(from: _from, to: _to, date: _date, kind: widget.ride),
      );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ready = _from != null && _to != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('map.title'.tr(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.directions_car_rounded, size: 18),
                      label: Text('map.trips'.tr())),
                  ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.person_pin_circle_rounded, size: 18),
                      label: Text('map.requests'.tr())),
                ],
                selected: {_requests},
                onSelectionChanged: (s) => setState(() => _requests = s.first),
              ),
              const SizedBox(height: 14),
              _routeCard(dark),
              const SizedBox(height: 14),
              _dates(),
              if (!ready) ...[
                const SizedBox(height: 40),
                const Icon(Icons.map_outlined, size: 56, color: BrandColors.c300),
                const SizedBox(height: 12),
                Text('map.form_hint'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, height: 1.35, fontWeight: FontWeight.w600, color: InkColors.c500)),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: AppButton(label: 'map.show_on_map'.tr(), icon: Icons.map_rounded, onPressed: ready ? _submit : null),
          ),
        ]),
      ),
    );
  }

  Widget _routeCard(bool dark) {
    final kg = isKg(context);
    Widget row({required IconData icon, required Place? place, required String hint, required bool to}) => InkWell(
          onTap: () => _editRoute(focusTo: to),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 60, 14),
            child: Row(children: [
              Icon(icon, size: 20, color: to ? InkColors.c700 : BrandColors.c600),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(place?.name(kg) ?? hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: place == null ? InkColors.c400 : (dark ? Colors.white : InkColors.c900))),
                  if (!to && _fromNearby && place != null)
                    Row(children: [
                      const Icon(Icons.near_me_rounded, size: 13, color: BrandColors.c600),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text('map.near_you'.tr(),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: BrandColors.c700)),
                      ),
                    ]),
                ]),
              ),
              if (!to && _filling)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
          ),
        );
    return Material(
      color: dark ? InkColors.c900 : Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.xl2),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Column(children: [
          row(icon: Icons.trip_origin_rounded, place: _from, hint: 'feed.from_placeholder'.tr(), to: false),
          Divider(height: 1, indent: 46, color: dark ? InkColors.c800 : InkColors.c200),
          row(icon: Icons.place_rounded, place: _to, hint: 'feed.to_placeholder'.tr(), to: true),
        ]),
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: Center(
            child: IconButton.filledTonal(
              tooltip: 'map.swap'.tr(),
              onPressed: _from == null && _to == null ? null : _swap,
              icon: const Icon(Icons.swap_vert_rounded, size: 20),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _dates() {
    final today = ymdOf(DateTime.now());
    final tomorrow = ymdOf(DateTime.now().add(const Duration(days: 1)));
    final picked = _date != 'any' && _date.isNotEmpty && _date != today && _date != tomorrow;
    Widget chip(String label, bool selected, String value) => ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => setState(() => _date = value),
        );
    return Wrap(spacing: 8, runSpacing: 8, children: [
      chip('map.any_date'.tr(), _date == 'any', 'any'),
      chip('feed.today'.tr(), _date == '' || _date == today, ''),
      chip('feed.tomorrow'.tr(), _date == tomorrow, tomorrow),
      ChoiceChip(
        avatar: const Icon(Icons.calendar_month_rounded, size: 16),
        label: Text(picked ? _date.split('-').reversed.take(2).join('.') : 'map.pick_date'.tr()),
        selected: picked,
        showCheckmark: false,
        onSelected: (_) => showDatePickerModal(
          context,
          value: picked ? _date : '',
          min: today,
          onChange: (v) => setState(() => _date = v),
        ),
      ),
    ]);
  }
}
