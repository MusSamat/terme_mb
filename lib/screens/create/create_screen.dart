import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../models/car.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/api_format.dart';
import '../../widgets/action_modal.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/city_picker.dart';
import '../../widgets/intent_toggle.dart';
import '../../widgets/seats_stepper.dart';
import '../profile/cars_card.dart' show showAddCarSheet;

/// Unified create screen — port of tappjet_ft create-screen. Drivers publish a
/// trip, passengers post a ride request; the intent toggle switches copy and
/// accent. Mock (no backend) — submit shows a success toast.
class CreateScreen extends ConsumerStatefulWidget {
  const CreateScreen({super.key});

  @override
  ConsumerState<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends ConsumerState<CreateScreen> {
  late bool _asDriver;
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _price = TextEditingController();
  final _priceFocus = FocusNode();
  final _comment = TextEditingController();
  int _dateIndex = 0;
  DateTime?
      _customDate; // driver/passenger: exact date picked from the calendar
  int _seats = 1;
  TimeOfDay? _time;
  bool _submitting = false;
  String? _carId; // driver: selected car for the trip
  String _luggage = 'small'; // driver: none | small | yes (web default = small)
  bool _priceNegotiable = false; // driver: allow passengers to haggle
  TimeOfDay? _timeEnd; // driver: optional end of the departure window
  bool _more = false; // «Дополнительно» accordion — collapsed by default
  final List<String> _pickup = []; // driver: intermediate pickup cities
  final List<String> _dropoff = []; // driver: intermediate dropoff cities
  final Set<String> _prefs = {};

  /// Selected car id, defaulting to the last car in the garage (web parity).
  String? _selectedCarId(List<Car> cars) {
    if (cars.isEmpty) return null;
    return cars.any((c) => c.id == _carId) ? _carId : cars.last.id;
  }

  // Mobile pref keys → backend preferences keys (mirrors web mapping).
  static const _prefApiKey = {
    'create.pref_clean': 'clean',
    'create.pref_music': 'music',
    'create.pref_no_smoking': 'no_smoking',
    'create.pref_ac': 'ac',
    'create.pref_pets': 'animals',
    'create.pref_quiet': 'quiet',
    'create.pref_chat': 'chat',
    'create.pref_women_only': 'women_only',
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
    _asDriver = ref.read(authProvider).activeMode == ActiveMode.driver;
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _price.dispose();
    _priceFocus.dispose();
    _comment.dispose();
    super.dispose();
  }

  Color get _accent => _asDriver ? GrapeColors.c600 : BrandColors.c600;

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
          IntentToggle(
              driver: _asDriver,
              onChanged: (d) => setState(() => _asDriver = d)),
          const SizedBox(height: 8),
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
            variant:
                _asDriver ? AppButtonVariant.brand : AppButtonVariant.grape,
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
    final iso = DateTime(day.year, day.month, day.day, hour, minute)
        .toUtc()
        .toIso8601String();
    return (iso: iso, flexible: flexible);
  }

  // ISO for the departure-window end, or null when unset / not after the start.
  String? _windowEndIso() {
    if (_timeEnd == null || _time == null) return null;
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
      _from.clear();
      _to.clear();
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
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final from = _from.text.trim();
    final to = _to.text.trim();
    if (from.isEmpty || to.isEmpty) {
      Toasts.error('create.err_route'.tr());
      return;
    }
    if (from == to) {
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
      carId =
          _selectedCarId(ref.read(carsProvider).valueOrNull ?? const <Car>[]);
      if (carId == null) {
        Toasts.error('create.err_no_car'.tr());
        return;
      }
    }

    setState(() => _submitting = true);
    final dep = _departure();
    try {
      if (_asDriver) {
        final prefs = <String, bool>{
          for (final k in _prefs)
            if (_prefApiKey[k] != null) _prefApiKey[k]!: true,
        };
        await ref.read(tripsServiceProvider).create({
          'originCity': from,
          'destinationCity': to,
          'originAddress': from,
          'departureAt': dep.iso,
          'departureFlexible': dep.flexible,
          'seatsTotal': _seats,
          'pricePerSeat': price,
          'priceNegotiable': _priceNegotiable,
          'luggage': _luggage,
          'carId': carId,
          'preferences': prefs,
          if (_pickup.isNotEmpty) 'pickupCities': _pickup,
          if (_dropoff.isNotEmpty) 'dropoffCities': _dropoff,
          if (_windowEndIso() != null) 'departureWindowEnd': _windowEndIso(),
          if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
        });
        ref.invalidate(calendarCountsProvider);
        ref.invalidate(
            myTripsProvider); // show the new trip in «Мои поездки» at once
      } else {
        final budgetNote = price > 0
            ? 'create.budget_note'.tr(namedArgs: {'n': '$price'})
            : '';
        await ref.read(requestsServiceProvider).create({
          'originCity': from,
          'destinationCity': to,
          'seatsNeeded': _seats,
          'departureDate': dep.iso,
          'flexible': dep.flexible,
          if (budgetNote.isNotEmpty) 'comment': budgetNote,
        });
        ref.invalidate(requestsFeedProvider);
        ref.invalidate(
            myRequestsProvider); // show the new request in «Мои заявки» at once
      }
      if (!mounted) return;
      // Publishing as a driver/passenger IS choosing that mode — sync the global
      // active mode so «Мои» shows the matching tab set. Without this, a trip
      // created while the app is in passenger mode is hidden (passenger tabs have
      // no «Поездки»). Then land the user right on their new listing.
      ref
          .read(authProvider.notifier)
          .setActiveMode(_asDriver ? ActiveMode.driver : ActiveMode.passenger);
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
                          strokeWidth: 2.4, color: GrapeColors.c500)))),
          error: (_, __) => const SizedBox.shrink(),
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
        if (_asDriver) ...[
          _zonesSection(dark),
          if (_time != null) ...[const SizedBox(height: 12), _windowRow(dark)],
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
              _field(dark, Icons.trip_origin, _from,
                  'create.from_placeholder'.tr()),
              Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
              _field(dark, Icons.place, _to, 'create.to_placeholder'.tr()),
            ],
          ),
          GestureDetector(
            onTap: () {
              final t = _from.text;
              _from.text = _to.text;
              _to.text = t;
              setState(() {});
            },
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

  Widget _field(
      bool dark, IconData icon, TextEditingController c, String hint) {
    return GestureDetector(
      onTap: () async {
        final city = await showCityPicker(context);
        if (city != null) setState(() => c.text = city);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 18, color: InkColors.c400),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                c.text.isEmpty ? hint : c.text,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.text.isEmpty
                        ? InkColors.c400
                        : (dark ? Colors.white : InkColors.c900)),
              ),
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
          Text('create.zones_title'.tr(),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : InkColors.c900)),
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

  Widget _zoneRow(bool dark, String label, List<String> list) {
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
                Text(city,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _accent)),
                const SizedBox(width: 6),
                Icon(Icons.close, size: 14, color: _accent),
              ]),
            ),
          ),
        _carChip('+ ${'create.zones_add'.tr()}', false, dark, () async {
          final city = await showCityPicker(context);
          if (city != null && !list.contains(city)) {
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
        Row(children: [
          for (final l in _luggageOpts) ...[
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
            const SizedBox(width: 8),
          ],
        ]),
      ]),
    );
  }

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
