import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../api/friendly_error.dart';
import '../../models/car.dart';
import '../../models/place.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/api_format.dart';
import '../../widgets/action_modal.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../utils/locale.dart';
import '../../utils/location.dart';
import '../../utils/uuid.dart';
import '../../widgets/city_picker.dart';
import '../../widgets/meeting_point_field.dart';
import '../../widgets/query_error.dart';
import '../../widgets/seats_stepper.dart';
import '../profile/cars_card.dart' show showAddCarSheet;

/// Optional prefill for the create form (airport screen, «create similar»…).
class CreatePrefill {
  const CreatePrefill({this.from, this.to});
  final Place? from;
  final Place? to;
}

/// Unified create screen: drivers publish a trip, passengers post a ride
/// request. Which one comes from the entry point (`kind` = trip | request);
/// without it the form follows the current mode. It never changes the mode.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key, this.kind, this.prefill});

  final String? kind;
  final CreatePrefill? prefill;

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  late bool _asDriver;
  Place? _from;
  Place? _to;
  MeetingPoint? _fromPoint; // driver: boarding spot · passenger: where I wait
  MeetingPoint? _toPoint;
  final _flight = TextEditingController(); // passenger ↔ airport only
  final _price = TextEditingController();
  final _priceFocus = FocusNode();
  final _comment = TextEditingController();
  int _dateIndex = 0;
  DateTime?
      _customDate; // driver/passenger: exact date picked from the calendar
  int _seats = 1;
  TimeOfDay? _time;
  bool _submitting = false;
  // One key per publish attempt: a retry after a lost response (timeout) reuses
  // it so the server returns the trip it already created instead of a dupe.
  String _idemKey = uuidV4();
  String? _carId; // driver: selected car for the trip
  String _luggage = 'small'; // driver: none | small | yes (web default = small)
  bool _priceNegotiable = false; // driver: allow passengers to haggle
  TimeOfDay? _timeEnd; // driver: optional end of the departure window
  bool _more = false; // «Дополнительно» accordion — collapsed by default
  final List<Place> _pickup = []; // driver: intermediate pickup places
  final List<Place> _dropoff = []; // driver: intermediate dropoff places
  final Set<String> _prefs = {};

  /// Selected car id, defaulting to the last car in the garage (web parity).
  String? _selectedCarId(List<Car> cars) {
    if (cars.isEmpty) return null;
    return cars.any((c) => c.id == _carId) ? _carId : cars.last.id;
  }

  // Pref chips → backend TripPreferences (no smoking = smoking:false).
  static const _prefApi = <String, (String, bool)>{
    'create.pref_clean': ('clean', true),
    'create.pref_music': ('music', true),
    'create.pref_no_smoking': ('smoking', false),
    'create.pref_ac': ('ac', true),
    'create.pref_pets': ('animals', true),
    'create.pref_quiet': ('quiet', true),
    'create.pref_chat': ('chat', true),
    'create.pref_women_only': ('women_only', true),
  };

  static const _dateKeys = [
    'create.date_today',
    'create.date_tomorrow',
    'create.date_dayafter',
    'create.date_flexible',
  ];
  static const _prefKeys = [
    'create.pref_clean',
    'create.pref_music',
    'create.pref_no_smoking',
    'create.pref_ac',
    'create.pref_pets',
    'create.pref_quiet',
    'create.pref_chat',
    'create.pref_women_only',
  ];

  @override
  void initState() {
    super.initState();
    _asDriver = switch (widget.kind) {
      'trip' => true,
      'request' => false,
      _ => ref.read(authProvider).activeMode == ActiveMode.driver,
    };
    _from = widget.prefill?.from;
    _to = widget.prefill?.to;
    if (_from == null) _prefillOrigin();
  }

  // «Откуда» = where the user is (best effort, never blocks the form).
  Future<void> _prefillOrigin() async {
    final me = await ref.read(locationServiceProvider).current(ask: false);
    if (me == null || !inKyrgyzstan(me) || !mounted || _from != null) return;
    try {
      final place = await ref.read(citiesServiceProvider).nearest(me.lat, me.lng);
      if (mounted && _from == null && place != null && place.id != _to?.id) setState(() => _from = place);
    } catch (_) {/* the user picks it */}
  }

  bool get _airport => (_from?.isAirport ?? false) || (_to?.isAirport ?? false);

  @override
  void dispose() {
    _flight.dispose();
    _price.dispose();
    _priceFocus.dispose();
    _comment.dispose();
    super.dispose();
  }

  Color get _accent => BrandColors.c600;

  Widget _timeRow(bool dark) {
    final label = _time == null
        ? 'create.time_pick'.tr()
        : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
            context: context,
            initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0));
        if (picked != null) setState(() => _time = picked);
      },
      behavior: HitTestBehavior.opaque,
      child: _card(
          dark,
          Row(children: [
            Icon(Icons.access_time, size: 18, color: _accent),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _time == null
                        ? InkColors.c400
                        : (dark ? Colors.white : InkColors.c900))),
            const Spacer(),
            const Icon(Icons.chevron_right, size: 18, color: InkColors.c400),
          ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(
            _asDriver
                ? 'create.title_driver'.tr()
                : 'create.title_passenger'.tr(),
            style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          Text(
              _asDriver
                  ? 'create.intro_driver'.tr()
                  : 'create.intro_passenger'.tr(),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: InkColors.c400)),
          const SizedBox(height: 16),
          // ── Essentials — the minimal happy path ──────────────────────────
          _routeCard(dark),
          const SizedBox(height: 10),
          MeetingPointField(
            place: _from,
            value: _fromPoint,
            accent: _accent,
            label: (_asDriver ? 'point.label_driver' : 'point.label_passenger').tr(),
            pickerTitle: (_asDriver ? 'point.title_driver' : 'point.title_passenger').tr(),
            onChanged: (p) => setState(() => _fromPoint = p),
          ),
          if (!_asDriver && _airport) ...[
            const SizedBox(height: 10),
            _flightField(dark),
          ],
          const SizedBox(height: 16),
          _sectionLabel('create.time_label'.tr(), dark),
          const SizedBox(height: 8),
          _dateChips(dark),
          // Exact time is a driver-only field; passengers just pick a day / «Гибко».
          if (_asDriver && (_customDate != null || _dateIndex != 3)) ...[
            const SizedBox(height: 10),
            _timeRow(dark),
          ],
          const SizedBox(height: 16),
          _seatsRow(dark),
          if (_asDriver) ...[
            const SizedBox(height: 16),
            _priceField(dark),
            const SizedBox(height: 10),
            _carRow(dark),
          ],
          // ── «Дополнительно» — everything optional, collapsed by default ───
          const SizedBox(height: 16),
          _moreSection(dark),
          const SizedBox(height: 20),
          Text('create.consent_phone'.tr(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: InkColors.c400)),
          const SizedBox(height: 12),
          AppButton(
            label: _asDriver
                ? 'create.submit_driver'.tr()
                : 'create.submit_passenger'.tr(),
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  // Concrete departure instant from the date chip + a default time (09:00, or
  // 12:00 when flexible) — mirrors the web create form.
  ({String iso, bool flexible}) _departure() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final flexible = _customDate == null && _dateIndex == 3;
    final DateTime day;
    if (_customDate != null) {
      day = _customDate!;
    } else {
      day = switch (_dateIndex) {
        0 => base, // today
        2 => base.add(const Duration(days: 2)), // day after tomorrow
        _ => base.add(const Duration(days: 1)), // tomorrow · flexible→tomorrow
      };
    }
    final hour = flexible ? 12 : (_time?.hour ?? 9);
    final minute = flexible ? 0 : (_time?.minute ?? 0);
    var at = DateTime(day.year, day.month, day.day, hour, minute);
    // No explicit time (passengers never pick one): the 09:00 default may have
    // passed today — use the next quarter hour at least 40 min ahead (the API
    // wants ≥30 min for trips and a future time for requests).
    final earliest = now.add(const Duration(minutes: 40));
    if (_time == null && at.isBefore(earliest)) {
      at = DateTime(earliest.year, earliest.month, earliest.day, earliest.hour, (earliest.minute ~/ 15 + 1) * 15);
    }
    return (iso: at.toUtc().toIso8601String(), flexible: flexible);
  }

  // ISO for the departure-window end, or null when unset / not after the start.
  String? _windowEndIso() {
    if (_timeEnd == null || _time == null) return null;
    if (_customDate == null && _dateIndex == 3) return null; // «Гибко» → 12:00, no window
    if (_timeEnd!.hour * 60 + _timeEnd!.minute <=
        _time!.hour * 60 + _time!.minute) {
      return null;
    }
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final day = _customDate ??
        switch (_dateIndex) {
          0 => base,
          2 => base.add(const Duration(days: 2)),
          _ => base.add(const Duration(days: 1)),
        };
    return DateTime(
            day.year, day.month, day.day, _timeEnd!.hour, _timeEnd!.minute)
        .toUtc()
        .toIso8601String();
  }

  /// Clears the form so «Создать ещё» starts fresh (keeps the current intent).
  void _resetForm() {
    if (!mounted) return;
    setState(() {
      _from = null;
      _to = null;
      _fromPoint = null;
      _toPoint = null;
      _flight.clear();
      _price.clear();
      _comment.clear();
      _dateIndex = 0;
      _customDate = null;
      _seats = 1;
      _time = null;
      _timeEnd = null;
      _luggage = 'small';
      _priceNegotiable = false;
      _pickup.clear();
      _dropoff.clear();
      _prefs.clear();
      _idemKey = uuidV4();
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final from = _from;
    final to = _to;
    if (from == null || to == null) {
      Toasts.error('create.err_route'.tr());
      return;
    }
    if (from.id == to.id) {
      Toasts.error('create.err_same_city'.tr());
      return;
    }
    final price = int.tryParse(_price.text.trim()) ?? 0;
    if (_asDriver && (price < 50 || price > 10000)) {
      Toasts.error('create.err_price'.tr());
      return;
    }
    // Driver: a trip needs a car (web parity gate).
    String? carId;
    if (_asDriver) {
      final cars = ref.read(carsProvider);
      if (!cars.hasValue) {
        // Still loading or failed — not «add a car».
        if (cars.hasError) Toasts.error(friendlyError(cars.error!));
        return;
      }
      carId = _selectedCarId(cars.value!);
      if (carId == null) {
        Toasts.error('create.err_no_car'.tr());
        return;
      }
    }

    final dep = _departure();
    // A time the driver picked explicitly must still be ≥30 min ahead.
    if (_asDriver && DateTime.parse(dep.iso).isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      Toasts.error('api_errors.departure_too_soon'.tr());
      return;
    }
    // Normalise «su-1882» / «SU  1882» to the API format (SU 1882).
    final flight = _flight.text.trim().toUpperCase().replaceAll('-', ' ').replaceAll(RegExp(r'\s+'), ' ');
    if (!_asDriver && _airport && flight.isNotEmpty && !RegExp(r'^[A-Z0-9]{2}\s?\d{1,4}[A-Z]?$').hasMatch(flight)) {
      Toasts.error('create.err_flight'.tr());
      return;
    }
    setState(() => _submitting = true);
    try {
      if (_asDriver) {
        final prefs = <String, bool>{
          for (final k in _prefs)
            if (_prefApi[k] != null) _prefApi[k]!.$1: _prefApi[k]!.$2,
        };
        await ref.read(tripsServiceProvider).create({
          'originCityId': from.id,
          'destinationCityId': to.id,
          if (_fromPoint != null) 'originPoint': _fromPoint!.toBody(),
          if (_toPoint != null) 'destinationPoint': _toPoint!.toBody(),
          'departureAt': dep.iso,
          'departureFlexible': dep.flexible,
          'seatsTotal': _seats,
          'pricePerSeat': price,
          'priceNegotiable': _priceNegotiable,
          'luggage': _luggage,
          'carId': carId,
          'preferences': prefs,
          if (_pickup.isNotEmpty) 'pickupCityIds': [for (final p in _pickup) p.id],
          if (_dropoff.isNotEmpty) 'dropoffCityIds': [for (final p in _dropoff) p.id],
          if (_windowEndIso() != null) 'departureWindowEnd': _windowEndIso(),
          if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
        }, idempotencyKey: _idemKey);
        _idemKey = uuidV4();
        if (!mounted) return;
        ref.invalidate(calendarCountsProvider);
        ref.invalidate(
            myTripsProvider); // show the new trip in «Мои поездки» at once
      } else {
        // Requests carry no price field — an optional budget rides in the
        // comment, after whatever the passenger wrote.
        final comment = [
          _comment.text.trim(),
          if (price > 0) 'create.budget_note'.tr(namedArgs: {'n': '$price'}),
        ].where((s) => s.isNotEmpty).join('\n');
        await ref.read(requestsServiceProvider).create({
          'originCityId': from.id,
          'destinationCityId': to.id,
          if (_fromPoint != null) 'originPoint': _fromPoint!.toBody(),
          if (_toPoint != null) 'destinationPoint': _toPoint!.toBody(),
          if (_airport && flight.isNotEmpty) 'flightNumber': flight,
          'seatsNeeded': _seats,
          'departureDate': dep.iso,
          'flexible': dep.flexible,
          if (comment.isNotEmpty) 'comment': comment,
        });
        if (!mounted) return;
        ref.invalidate(requestsFeedProvider);
        ref.invalidate(
            myRequestsProvider); // show the new request in «Мои заявки» at once
      }
      if (!mounted) return;
      final wasDriver = _asDriver;
      showSuccessModal(
        context,
        title: 'create.published_title'.tr(),
        body: wasDriver
            ? 'create.published_body_driver'.tr()
            : 'create.published_body_passenger'.tr(),
        primaryLabel: wasDriver
            ? 'create.published_cta_driver'.tr()
            : 'create.published_cta_passenger'.tr(),
        onPrimary: () => context.go(
            wasDriver ? '/my/bookings?tab=trips' : '/my/bookings?tab=requests'),
        secondaryLabel: 'create.publish_another'.tr(),
        onSecondary: _resetForm, // stay on Create with a clean form
      );
    } catch (e) {
      Toasts.error(friendlyError(e));
      // Keep the key only for a transport failure (the trip may exist); any
      // answered error means a corrected body needs a fresh key.
      if (extractError(e).code != AppException.networkOffline) _idemKey = uuidV4();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Driver: the trip rides on a car. Compact row → opens a selection sheet
  // (best practice: many-option selectors are focused sheets, not inline lists).
  Widget _carRow(bool dark) {
    return ref.watch(carsProvider).when(
          loading: () => _card(
              dark,
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: BrandColors.c500)))),
          error: (e, _) => QueryError(error: e, onRetry: () => ref.invalidate(carsProvider)),
          data: (cars) {
            final selected = _selectedCarId(cars);
            Car? car;
            for (final c in cars) {
              if (c.id == selected) car = c;
            }
            return GestureDetector(
              onTap: () => _showCarSheet(dark, cars, selected),
              behavior: HitTestBehavior.opaque,
              child: _card(
                  dark,
                  Row(children: [
                    Icon(Icons.directions_car_filled, size: 18, color: _accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        car != null
                            ? '${car.make} ${car.model}'
                            : 'create.car_choose'.tr(),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: car != null
                                ? (dark ? Colors.white : InkColors.c900)
                                : InkColors.c400),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 18, color: InkColors.c400),
                  ])),
            );
          },
        );
  }

  void _showCarSheet(bool dark, List<Car> cars, String? selected) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.xl4))),
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 16 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: InkColors.c300,
                          borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 14),
              Text('create.car_title'.tr(),
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : InkColors.c900)),
              const SizedBox(height: 12),
              for (final c in cars)
                GestureDetector(
                  onTap: () {
                    setState(() => _carId = c.id);
                    Navigator.pop(ctx);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.id == selected
                          ? _accent.withValues(alpha: dark ? 0.22 : 0.1)
                          : (dark ? InkColors.c800 : InkColors.c50),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(
                          color:
                              c.id == selected ? _accent : Colors.transparent),
                    ),
                    child: Row(children: [
                      Icon(Icons.directions_car_filled,
                          size: 18, color: _accent),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('${c.make} ${c.model} · ${c.plate}',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      dark ? Colors.white : InkColors.c900))),
                      if (c.id == selected)
                        Icon(Icons.check_circle, size: 20, color: _accent),
                    ]),
                  ),
                ),
              if (cars.length < 3)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    showAddCarSheet(context, dark: dark);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                            color: _accent, style: BorderStyle.solid)),
                    child: Text('+ ${'profile.add_car'.tr()}',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _accent)),
                  ),
                ),
            ]),
      ),
    );
  }

  // «Дополнительно» — an inline accordion holding every optional field. Collapsed
  // by default so the essentials stay uncluttered; role decides the contents.
  Widget _moreSection(bool dark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GestureDetector(
        onTap: () => setState(() => _more = !_more),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: dark ? 0.14 : 0.07),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: _accent.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(Icons.tune, size: 18, color: _accent),
            const SizedBox(width: 8),
            Text('create.more'.tr(),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _accent)),
            const Spacer(),
            Icon(_more ? Icons.expand_less : Icons.expand_more,
                size: 20, color: _accent),
          ]),
        ),
      ),
      if (_more) ...[
        const SizedBox(height: 12),
        MeetingPointField(
          place: _to,
          value: _toPoint,
          accent: _accent,
          label: 'point.label_drop'.tr(),
          pickerTitle: 'point.title_drop'.tr(),
          onChanged: (p) => setState(() => _toPoint = p),
        ),
        const SizedBox(height: 12),
        if (_asDriver) ...[
          _zonesSection(dark),
          if (_time != null && !(_customDate == null && _dateIndex == 3)) ...[
            const SizedBox(height: 12),
            _windowRow(dark),
          ],
          const SizedBox(height: 12),
          _negotiableRow(dark),
          const SizedBox(height: 16),
          _luggageSection(dark),
          const SizedBox(height: 16),
          _prefsSection(dark),
          const SizedBox(height: 16),
          _commentCard(dark),
        ] else ...[
          _priceField(dark), // passenger budget — optional (drivers bid)
          const SizedBox(height: 16),
          _commentCard(dark),
        ],
      ],
    ]);
  }

  Widget _commentCard(bool dark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('book_form.comment_label'.tr(), dark),
      const SizedBox(height: 8),
      _card(
          dark,
          TextField(
            controller: _comment,
            maxLines: 2,
            maxLength: 300,
            style: TextStyle(
                fontSize: 14, color: dark ? Colors.white : InkColors.c900),
            decoration: InputDecoration(
                counterText: '',
                hintText: 'book_form.comment_placeholder'.tr(),
                hintStyle: const TextStyle(color: InkColors.c400),
                border: InputBorder.none,
                isCollapsed: true),
          )),
    ]);
  }

  Widget _carChip(String label, bool active, bool dark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? _accent.withValues(alpha: dark ? 0.25 : 0.12)
              : (dark ? InkColors.c800 : InkColors.c100),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _accent : Colors.transparent),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active
                    ? _accent
                    : (dark ? InkColors.c200 : InkColors.c700))),
      ),
    );
  }

  Widget _routeCard(bool dark) {
    return _card(
      dark,
      Stack(
        alignment: Alignment.centerRight,
        children: [
          Column(
            children: [
              _field(dark, Icons.trip_origin, _from, 'create.from_placeholder'.tr(), (p) {
                setState(() {
                  _from = p;
                  _fromPoint = null; // a pin belongs to its place
                });
              }),
              Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
              _field(dark, Icons.place, _to, 'create.to_placeholder'.tr(), (p) {
                setState(() {
                  _to = p;
                  _toPoint = null;
                });
              }),
            ],
          ),
          GestureDetector(
            onTap: () => setState(() {
              final t = _from;
              _from = _to;
              _to = t;
              final tp = _fromPoint;
              _fromPoint = _toPoint;
              _toPoint = tp;
            }),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: dark ? InkColors.c800 : InkColors.c100,
                shape: BoxShape.circle,
                border:
                    Border.all(color: dark ? InkColors.c700 : InkColors.c200),
              ),
              child: Icon(Icons.swap_vert,
                  size: 18, color: dark ? InkColors.c200 : InkColors.c600),
            ),
          ),
        ],
      ),
      padding: EdgeInsets.zero,
    );
  }

  Widget _field(bool dark, IconData icon, Place? value, String hint, ValueChanged<Place> onPick) {
    final kg = isKg(context);
    final sub = value?.subtitle(kg) ?? '';
    return GestureDetector(
      onTap: () async {
        final place = await showCityPicker(context, nearMe: true);
        if (place != null) onPick(place);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(value == null ? icon : placeIcon(value.type), size: 18, color: InkColors.c400),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  value == null ? hint : value.name(kg),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: value == null ? InkColors.c400 : (dark ? Colors.white : InkColors.c900)),
                ),
                if (sub.isNotEmpty)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: InkColors.c400)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChips(bool dark) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _dateKeys.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == _dateKeys.length) {
            final label = _customDate == null
                ? 'create.date_pick'.tr()
                : '${_customDate!.day.toString().padLeft(2, '0')}.${_customDate!.month.toString().padLeft(2, '0')}';
            return _chip(label, _customDate != null, dark, _pickCustomDate,
                icon: Icons.calendar_today);
          }
          return _chip(
              _dateKeys[i].tr(),
              _customDate == null && i == _dateIndex,
              dark,
              () => setState(() {
                    _dateIndex = i;
                    _customDate = null;
                  }));
        },
      ),
    );
  }

  Widget _chip(String label, bool active, bool dark, VoidCallback onTap,
      {IconData? icon}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? _accent : (dark ? InkColors.c900 : Colors.white),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13, color: active ? Colors.white : InkColors.c400),
              const SizedBox(width: 6)
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: active
                        ? Colors.white
                        : (dark ? InkColors.c200 : InkColors.c700))),
          ],
        ),
      ),
    );
  }

  Widget _seatsRow(bool dark) {
    return _card(
      dark,
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
              _asDriver
                  ? 'create.seats_label_driver'.tr()
                  : 'create.seats_label_passenger'.tr(),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : InkColors.c900)),
          SeatsStepper(
            value: _seats,
            max: 7,
            accent: _accent,
            onChanged: (v) => setState(() => _seats = v),
          ),
        ],
      ),
    );
  }

  Widget _priceField(bool dark) {
    // Whole row is tappable, so tapping the label focuses the price input.
    return GestureDetector(
      onTap: _priceFocus.requestFocus,
      behavior: HitTestBehavior.opaque,
      child: _card(
        dark,
        Row(
          children: [
            Expanded(
              child: Text(
                  _asDriver
                      ? 'create.price_label_driver'.tr()
                      : 'create.price_label_passenger'.tr(),
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : InkColors.c900)),
            ),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _price,
                focusNode: _priceFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  // Price can't start with 0 — strip leading zeros as they type.
                  TextInputFormatter.withFunction((old, nw) {
                    final t = stripLeadingZeros(nw.text);
                    return t == nw.text
                        ? nw
                        : TextEditingValue(
                            text: t,
                            selection:
                                TextSelection.collapsed(offset: t.length));
                  }),
                ],
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white : InkColors.c900),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: const TextStyle(color: InkColors.c400),
                  suffixText: ' ${'create.som'.tr()}',
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prefsSection(bool dark) {
    return _card(
      dark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('create.prefs_title'.tr(),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : InkColors.c900)),
          const SizedBox(height: 4),
          Text(
              _asDriver
                  ? 'create.prefs_hint_driver'.tr()
                  : 'create.prefs_hint_passenger'.tr(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: InkColors.c400)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in _prefKeys)
                _prefChip(key, _prefs.contains(key), dark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _prefChip(String key, bool active, bool dark) {
    return GestureDetector(
      onTap: () =>
          setState(() => active ? _prefs.remove(key) : _prefs.add(key)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? _accent.withValues(alpha: dark ? 0.25 : 0.12)
              : (dark ? InkColors.c800 : InkColors.c100),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _accent : Colors.transparent),
        ),
        child: Text(key.tr(),
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active
                    ? _accent
                    : (dark ? InkColors.c200 : InkColors.c700))),
      ),
    );
  }

  // Driver: optional intermediate stops. Passengers post a plain request, so the
  // trip contract carries pickup/dropoff — this section is driver-only.
  Widget _zonesSection(bool dark) {
    return _card(
      dark,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.alt_route, size: 18, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text('create.zones_title'.tr(),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : InkColors.c900)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('create.zones_hint'.tr(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: InkColors.c400)),
        const SizedBox(height: 12),
        _zoneRow(dark, 'create.zones_pickup'.tr(), _pickup),
        const SizedBox(height: 12),
        _zoneRow(dark, 'create.zones_dropoff'.tr(), _dropoff),
      ]),
    );
  }

  Widget _zoneRow(bool dark, String label, List<Place> list) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: InkColors.c400)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final city in list)
          GestureDetector(
            onTap: () => setState(() => list.remove(city)),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: _accent.withValues(alpha: dark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _accent)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(city.name(isKg(context)),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _accent)),
                const SizedBox(width: 6),
                Icon(Icons.close, size: 14, color: _accent),
              ]),
            ),
          ),
        if (list.length < 5) // API cap per list
        _carChip('+ ${'create.zones_add'.tr()}', false, dark, () async {
          final city = await showCityPicker(context);
          if (city != null && !list.contains(city) && city.id != _from?.id && city.id != _to?.id) {
            setState(() => list.add(city));
          }
        }),
      ]),
    ]);
  }

  // Optional departure window end — «выезжаем 06:00–08:00». Only when a start
  // time is set; sending it is gated on end > start in _submit.
  Widget _windowRow(bool dark) {
    if (_time == null) return const SizedBox.shrink();
    final label = _timeEnd == null
        ? 'create.window_add'.tr()
        : '${'create.window_to'.tr()} ${_timeEnd!.hour.toString().padLeft(2, '0')}:${_timeEnd!.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: _timeEnd ??
                TimeOfDay(hour: (_time!.hour + 3) % 24, minute: _time!.minute),
          );
          if (picked != null) setState(() => _timeEnd = picked);
        },
        behavior: HitTestBehavior.opaque,
        child: _card(
            dark,
            Row(children: [
              Icon(Icons.more_time,
                  size: 18, color: _timeEnd == null ? InkColors.c400 : _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _timeEnd == null
                            ? InkColors.c400
                            : (dark ? Colors.white : InkColors.c900))),
              ),
              if (_timeEnd != null)
                GestureDetector(
                  onTap: () => setState(() => _timeEnd = null),
                  behavior: HitTestBehavior.opaque,
                  child:
                      const Icon(Icons.close, size: 18, color: InkColors.c400),
                )
              else
                const Icon(Icons.chevron_right,
                    size: 18, color: InkColors.c400),
            ])),
      ),
    );
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? today.add(const Duration(days: 1)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(
          () => _customDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  // Driver: let passengers propose another price — a compact card toggle.
  Widget _negotiableRow(bool dark) {
    return GestureDetector(
      onTap: () => setState(() => _priceNegotiable = !_priceNegotiable),
      behavior: HitTestBehavior.opaque,
      child: _card(
          dark,
          Row(children: [
            Icon(Icons.handshake_outlined, size: 18, color: _accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text('create.price_negotiable'.tr(),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : InkColors.c900)),
            ),
            Switch(
              value: _priceNegotiable,
              activeTrackColor: _accent,
              onChanged: (v) => setState(() => _priceNegotiable = v),
            ),
          ])),
    );
  }

  static const _luggageOpts = ['no', 'small', 'yes'];
  static String _luggageLabel(String l) => switch (l) {
        'yes' => 'trips.luggage_ok'.tr(),
        'no' => 'trips.luggage_none'.tr(),
        _ => 'trips.luggage_small'.tr(),
      };

  Widget _luggageSection(bool dark) {
    return _card(
      dark,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('create.luggage_label'.tr(),
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : InkColors.c900)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final l in _luggageOpts)
            GestureDetector(
              onTap: () => setState(() => _luggage = l),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _luggage == l
                      ? _accent.withValues(alpha: dark ? 0.25 : 0.12)
                      : (dark ? InkColors.c800 : InkColors.c100),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: _luggage == l ? _accent : Colors.transparent),
                ),
                child: Text(_luggageLabel(l),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _luggage == l
                            ? _accent
                            : (dark ? InkColors.c200 : InkColors.c700))),
              ),
            ),
        ]),
      ]),
    );
  }

  // Arriving / departing flight — lets the driver meet the passenger in time.
  Widget _flightField(bool dark) => _card(
        dark,
        Row(children: [
          Icon(Icons.flight_rounded, size: 18, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _flight,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900),
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
      );

  Widget _sectionLabel(String text, bool dark) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: InkColors.c400));
  }

  Widget _card(bool dark, Widget child,
      {EdgeInsets padding = const EdgeInsets.all(14)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}
