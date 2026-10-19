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
import '../../utils/airport.dart';
import '../../utils/api_format.dart';
import '../../utils/date_format.dart';
import '../../utils/locale.dart';
import '../../widgets/app_button.dart';
import '../../widgets/city_picker.dart';
import '../../widgets/map/plane_glyph.dart';
import '../../widgets/query_error.dart';
import '../create/create_screen.dart' show CreatePrefill;

/// Airport transfers in three steps: the airport (two cards) → direction →
/// the other end (served city by default, popular chips, any place). Then the
/// flight: date + time (+ international / domestic to the airport) → the
/// suggested pickup («Выезд в 03:30 — успеете к регистрации», editable) or the
/// landing time → optional flight number → «Найти трансфер» (results ranked
/// around that time). Drivers / passengers can publish from the same answers.
class AirportScreen extends ConsumerStatefulWidget {
  const AirportScreen({super.key});

  @override
  ConsumerState<AirportScreen> createState() => _AirportScreenState();
}

class _AirportScreenState extends ConsumerState<AirportScreen> {
  Airport? _airport;
  bool _toAirport = true;
  Place? _other;
  late DateTime _day = _today;
  TimeOfDay? _flightTime;
  String _flightType = 'domestic';
  TimeOfDay? _pickupOverride;
  final _flight = TextEditingController();

  static DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _flight.dispose();
    super.dispose();
  }

  void _selectAirport(Airport a) => setState(() {
        _airport = a;
        _other = a.serves;
        _flightType = a.flightType;
        _pickupOverride = null;
      });

  void _setOther(Place p) => setState(() {
        _other = p;
        _pickupOverride = null;
      });

  DateTime? get _flightAt {
    final t = _flightTime;
    return t == null ? null : DateTime(_day.year, _day.month, _day.day, t.hour, t.minute);
  }

  PickupKey? get _pickupKey {
    final a = _airport, o = _other, at = _flightAt;
    if (!_toAirport || a == null || o == null || at == null || o.id == a.place.id) return null;
    return (airportId: a.place.id, fromId: o.id, flightTime: at, flightType: _flightType);
  }

  /// When the transfer leaves: to the airport — the edited / suggested pickup
  /// (else departure − check-in buffer); from it — landing + slack.
  DateTime? _departure(PickupSuggestion? s) {
    final at = _flightAt;
    if (at == null) return null;
    if (!_toAirport) return departureAfterArrival(at);
    final base = s?.pickupAt ??
        at.subtract(Duration(minutes: _airport?.bufferMin[_flightType] ?? (_flightType == 'international' ? 150 : 90)));
    final o = _pickupOverride;
    return o == null ? base : DateTime(base.year, base.month, base.day, o.hour, o.minute);
  }

  ({Place from, Place to})? get _route {
    final a = _airport?.place, o = _other;
    if (a == null || o == null || a.id == o.id) return null;
    return _toAirport ? (from: o, to: a) : (from: a, to: o);
  }

  bool get _driver => ref.read(authProvider).activeMode == ActiveMode.driver;

  void _search(DateTime target) {
    final r = _route!;
    // From the airport the listings sit around the landing time.
    final t = _toAirport ? target : _flightAt!;
    context.push('/results?mode=${_driver ? 'requests' : 'trips'}',
        extra: FeedFilters(
          from: r.from,
          to: r.to,
          kind: 'airport',
          date: ymdOf(t),
          targetTime: t.toUtc().toIso8601String(),
        ));
  }

  void _publish(DateTime departure) {
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      context.push('/auth/login');
      return;
    }
    final r = _route!;
    final flight = _flight.text.trim();
    context.push('/trips/create?kind=${_driver ? 'trip' : 'request'}',
        extra: CreatePrefill(
          from: r.from,
          to: r.to,
          departureAt: departure,
          flightNumber: flight.isEmpty ? null : flight,
        ));
  }

  Future<void> _pickDay() async {
    final now = _today;
    final d = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
      initialDate: _day,
    );
    if (d == null || !mounted) return;
    setState(() {
      _day = d;
      _pickupOverride = null;
    });
  }

  Future<void> _pickFlightTime() async {
    final t = await showTimePicker(context: context, initialTime: _flightTime ?? const TimeOfDay(hour: 9, minute: 0));
    if (t == null || !mounted) return;
    setState(() {
      _flightTime = t;
      _pickupOverride = null;
    });
  }

  Future<void> _editPickup(DateTime current) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (t != null && mounted) setState(() => _pickupOverride = t);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final airports = ref.watch(airportsProvider);
    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        title: Text('airport.title'.tr(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      ),
      body: airports.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500)),
        error: (e, _) => QueryError(error: e, onRetry: () => ref.invalidate(airportsProvider)),
        data: (list) => _form(dark, list),
      ),
    );
  }

  Widget _form(bool dark, List<Airport> list) {
    final kg = isKg(context);
    final a = _airport;
    final key = _pickupKey;
    final suggestion = key == null ? null : ref.watch(pickupSuggestionProvider(key));
    final departure = _departure(suggestion?.valueOrNull);
    final ready = _route != null && departure != null;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.paddingOf(context).bottom),
      children: [
        _label('airport.choose_airport'.tr()),
        Row(children: [
          for (final (i, x) in list.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: AirportCard(
                key: ValueKey('airport-${x.place.id}'),
                airport: x,
                selected: a?.place.id == x.place.id,
                onTap: () => _selectAirport(x),
              ),
            ),
          ],
        ]),
        if (a != null) ...[
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.flight_takeoff_rounded, size: 18),
                  label: Text('airport.to'.tr())),
              ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.flight_land_rounded, size: 18),
                  label: Text('airport.from'.tr())),
            ],
            selected: {_toAirport},
            onSelectionChanged: (s) => setState(() {
              _toAirport = s.first;
              _pickupOverride = null;
            }),
          ),
          const SizedBox(height: 16),
          _label((_toAirport ? 'airport.other_to' : 'airport.other_from').tr()),
          _otherField(dark, kg, list),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in a.popular)
              ChoiceChip(
                key: ValueKey('popular-${p.id}'),
                label: _chipLabel(p, kg, list),
                selected: _other?.id == p.id,
                onSelected: (_) => _setOther(p),
              ),
          ]),
          const SizedBox(height: 16),
          _label('airport.flight_date'.tr()),
          _dayChips(),
          const SizedBox(height: 10),
          _row(
            dark,
            icon: _toAirport ? Icons.flight_takeoff_rounded : Icons.flight_land_rounded,
            text: _flightTime == null
                ? null
                : '${(_toAirport ? 'airport.flight_dep_time' : 'airport.flight_arr_time').tr()} · ${hhmm(_flightAt!)}',
            hint: (_toAirport ? 'airport.flight_dep_time' : 'airport.flight_arr_time').tr(),
            onTap: _pickFlightTime,
          ),
          if (_toAirport) ...[
            const SizedBox(height: 10),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'international', label: Text('airport.intl'.tr())),
                ButtonSegment(value: 'domestic', label: Text('airport.domestic'.tr())),
              ],
              selected: {_flightType},
              onSelectionChanged: (s) => setState(() {
                _flightType = s.first;
                _pickupOverride = null;
              }),
            ),
          ],
          if (departure != null) ...[
            const SizedBox(height: 12),
            _toAirport
                ? PickupHint(
                    departure: departure,
                    suggestion: suggestion?.valueOrNull,
                    loading: suggestion?.isLoading ?? false,
                    edited: _pickupOverride != null,
                    onEdit: () => _editPickup(departure),
                  )
                : _ArrivalHint(arrival: _flightAt!, departure: departure),
          ],
          const SizedBox(height: 12),
          _flightField(dark),
          const SizedBox(height: 20),
          AppButton(
            key: const ValueKey('airport-find'),
            label: 'airport.find'.tr(),
            icon: Icons.search_rounded,
            onPressed: ready ? () => _search(departure) : null,
          ),
          const SizedBox(height: 8),
          AppButton(
            label: (_driver ? 'airport.publish' : 'airport.leave_request').tr(),
            variant: AppButtonVariant.outline,
            onPressed: ready ? () => _publish(departure) : null,
          ),
        ],
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: InkColors.c400)),
      );

  Widget _chipLabel(Place p, bool kg, List<Airport> list) {
    final sub = collidesWithAirport(p, list, kg) ? p.subtitle(kg) : '';
    if (sub.isEmpty) return Text(p.name(kg));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(p.name(kg)),
      Text(sub, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: InkColors.c400)),
    ]);
  }

  Widget _otherField(bool dark, bool kg, List<Airport> list) {
    final o = _other;
    final sub = o == null ? '' : o.subtitle(kg);
    return _card(
      dark,
      InkWell(
        key: const ValueKey('airport-other'),
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        onTap: () async {
          final p = await showCityPicker(context, nearMe: true, scope: 'any');
          if (p != null && mounted) _setOther(p);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(o == null ? Icons.search_rounded : placeIcon(o.type), size: 20, color: BrandColors.c600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o?.name(kg) ?? 'airport.other_hint'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: o == null ? InkColors.c400 : (dark ? Colors.white : InkColors.c900))),
                if (sub.isNotEmpty)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
              ]),
            ),
            const Icon(Icons.chevron_right, size: 20, color: InkColors.c400),
          ]),
        ),
      ),
    );
  }

  Widget _dayChips() {
    final today = _today;
    final tomorrow = today.add(const Duration(days: 1));
    final custom = _day != today && _day != tomorrow;
    void set(DateTime d) => setState(() {
          _day = d;
          _pickupOverride = null;
        });
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ChoiceChip(label: Text('feed.today'.tr()), selected: _day == today, onSelected: (_) => set(today)),
      ChoiceChip(label: Text('feed.tomorrow'.tr()), selected: _day == tomorrow, onSelected: (_) => set(tomorrow)),
      ChoiceChip(
        avatar: const Icon(Icons.event_rounded, size: 16),
        label: Text(custom
            ? '${_day.day.toString().padLeft(2, '0')}.${_day.month.toString().padLeft(2, '0')}'
            : 'map.pick_date'.tr()),
        selected: custom,
        onSelected: (_) => _pickDay(),
      ),
    ]);
  }

  Widget _row(bool dark, {required IconData icon, String? text, required String hint, required VoidCallback onTap}) =>
      _card(
        dark,
        InkWell(
          borderRadius: BorderRadius.circular(AppRadii.xl3),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, size: 20, color: BrandColors.c600),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text ?? hint,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: text == null ? InkColors.c400 : (dark ? Colors.white : InkColors.c900))),
              ),
              const Icon(Icons.access_time_rounded, size: 18, color: InkColors.c400),
            ]),
          ),
        ),
      );

  Widget _flightField(bool dark) => _card(
        dark,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            const Icon(Icons.confirmation_number_outlined, size: 20, color: BrandColors.c600),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _flight,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900),
                decoration: InputDecoration(
                  counterText: '',
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'airport.flight_hint'.tr(),
                  hintStyle: const TextStyle(color: InkColors.c400, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _card(bool dark, Widget child) => Material(
        color: dark ? InkColors.c900 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl3),
          side: BorderSide(color: dark ? InkColors.c800 : InkColors.c100),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

/// Step 1: a big airport card — plane, title («Манас · Бишкек»), flight type.
class AirportCard extends StatelessWidget {
  const AirportCard({super.key, required this.airport, required this.selected, required this.onTap});

  final Airport airport;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final kg = isKg(context);
    return Material(
      color: selected ? (dark ? BrandColors.c900 : BrandColors.c50) : (dark ? InkColors.c900 : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        side: BorderSide(
            color: selected ? BrandColors.c600 : (dark ? InkColors.c800 : InkColors.c100), width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: selected ? BrandColors.c600 : BrandColors.c50, shape: BoxShape.circle),
              child: PlaneGlyph(size: 22, color: selected ? Colors.white : BrandColors.c600),
            ),
            const SizedBox(height: 12),
            Text(airport.title(kg),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    color: dark ? Colors.white : InkColors.c900)),
            const SizedBox(height: 2),
            Text((airport.flightType == 'international' ? 'airport.intl' : 'airport.domestic').tr(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: InkColors.c400)),
          ]),
        ),
      ),
    );
  }
}

/// «Выезд в 03:30 — успеете к регистрации» + distance / travel time, editable.
class PickupHint extends StatelessWidget {
  const PickupHint({
    super.key,
    required this.departure,
    required this.suggestion,
    required this.loading,
    required this.edited,
    required this.onEdit,
  });

  final DateTime departure;
  final PickupSuggestion? suggestion;
  final bool loading;
  final bool edited;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final title = (s == null && !edited ? 'airport.pickup_fallback' : 'airport.pickup_hint')
        .tr(namedArgs: {'time': hhmm(departure)});
    final sub = s == null
        ? null
        : 'airport.pickup_route'.tr(namedArgs: {'km': s.distanceKm.round().toString(), 'min': '${s.travelMin}'});
    return _HintBox(
      icon: Icons.directions_car_rounded,
      title: title,
      subtitle: sub,
      loading: loading && s == null,
      action: TextButton(
        onPressed: onEdit,
        style: TextButton.styleFrom(foregroundColor: BrandColors.c700),
        child: Text('airport.pickup_edit'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _ArrivalHint extends StatelessWidget {
  const _ArrivalHint({required this.arrival, required this.departure});
  final DateTime arrival;
  final DateTime departure;

  @override
  Widget build(BuildContext context) => _HintBox(
        icon: Icons.flight_land_rounded,
        title: 'airport.arrival'.tr(namedArgs: {'time': hhmm(arrival)}),
        subtitle: 'airport.arrival_hint'.tr(),
      );
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.icon, required this.title, this.subtitle, this.loading = false, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: dark ? BrandColors.c900 : BrandColors.c50,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(children: [
        loading
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.c600))
            : Icon(icon, size: 18, color: BrandColors.c700),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: dark ? BrandColors.c100 : BrandColors.c800)),
            if (subtitle != null)
              Text(subtitle!,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: dark ? BrandColors.c200 : BrandColors.c700)),
          ]),
        ),
        if (action != null) action!,
      ]),
    );
  }
}
