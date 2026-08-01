import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/mock_calendar.dart';
import '../models/feed_filters.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import 'app_chip.dart';
import 'city_picker.dart';
import 'date_picker_modal.dart';

/// Filters sheet — 1:1 port of tappjet_ft FiltersBody. Applies live to a
/// [FeedFilters] via [onChanged], exactly like the web (URL params update the
/// feed as you tap).
Future<void> showFiltersSheet(
  BuildContext context, {
  required FeedFilters initial,
  required ValueChanged<FeedFilters> onChanged,
  ChipAccent accent = ChipAccent.brand,
}) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _FiltersSheet(initial: initial, onChanged: onChanged, accent: accent),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial, required this.onChanged, required this.accent});
  final FeedFilters initial;
  final ValueChanged<FeedFilters> onChanged;
  final ChipAccent accent;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late FeedFilters _f = widget.initial;
  String _from = '', _to = '';
  late final _priceFrom = TextEditingController(text: _f.minPrice?.toString() ?? '');
  late final _priceTo = TextEditingController(text: _f.maxPrice?.toString() ?? '');

  static final _todayYmd = ymd(DateTime.now());
  static final _tomorrowYmd = ymd(DateTime.now().add(const Duration(days: 1)));

  @override
  void dispose() {
    _priceFrom.dispose();
    _priceTo.dispose();
    super.dispose();
  }

  void _set(FeedFilters next) {
    setState(() => _f = next);
    widget.onChanged(next);
  }

  void _reset() {
    _priceFrom.clear();
    _priceTo.clear();
    _from = _to = '';
    _set(const FeedFilters());
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final acc = widget.accent;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: dark ? InkColors.c950 : InkColors.c50,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('search_filters.title'.tr(),
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
                  const Spacer(),
                  if (_f.activeCount > 0)
                    GestureDetector(
                      onTap: _reset,
                      child: Text('search_filters.reset'.tr(),
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800, color: dark ? BrandColors.c300 : BrandColors.c600)),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _label(dark, 'search_filters.route_label'.tr()),
                  _cityRow(dark),
                  const SizedBox(height: 18),
                  _label(dark, 'search_filters.date_label'.tr()),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    AppChip(label: 'search_filters.date_any'.tr(), selected: _f.date == 'any', accent: acc, onTap: () => _set(_f.copyWith(date: 'any'))),
                    AppChip(label: 'search_filters.date_today'.tr(), selected: _f.date == _todayYmd || _f.date == '', accent: acc, onTap: () => _set(_f.copyWith(date: _todayYmd))),
                    AppChip(label: 'search_filters.date_tomorrow'.tr(), selected: _f.date == _tomorrowYmd, accent: acc, onTap: () => _set(_f.copyWith(date: _tomorrowYmd))),
                  ]),
                  const SizedBox(height: 8),
                  _calendarField(dark),
                  const SizedBox(height: 18),
                  _label(dark, 'search_filters.sort_label'.tr()),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final o in const [('time', 'sort_time'), ('price_asc', 'sort_price_asc'), ('rating_desc', 'sort_rating_desc')])
                      AppChip(label: 'search_filters.${o.$2}'.tr(), selected: _f.sort == o.$1, accent: acc, onTap: () => _set(_f.copyWith(sort: o.$1))),
                  ]),
                  const SizedBox(height: 18),
                  _label(dark, 'search_filters.rating_label'.tr()),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    AppChip(label: 'search_filters.rating_any'.tr(), selected: _f.minRating == 0, accent: acc, onTap: () => _set(_f.copyWith(minRating: 0))),
                    for (final r in const [4.0, 4.5, 4.8])
                      AppChip(label: '$r+', selected: _f.minRating == r, accent: acc, onTap: () => _set(_f.copyWith(minRating: r))),
                  ]),
                  const SizedBox(height: 18),
                  _label(dark, 'search_filters.luggage_label'.tr()),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final o in const [('', 'luggage_any'), ('yes', 'luggage_big'), ('small', 'luggage_small'), ('no', 'luggage_none')])
                      AppChip(label: 'search_filters.${o.$2}'.tr(), selected: _f.luggage == o.$1, accent: acc, onTap: () => _set(_f.copyWith(luggage: o.$1))),
                  ]),
                  const SizedBox(height: 18),
                  _label(dark, 'search_filters.price_label'.tr()),
                  Row(children: [
                    Expanded(child: _priceInput(dark, _priceFrom, 'search_filters.price_from'.tr(), (v) => _set(_f.copyWith(minPrice: v, clearMinPrice: v == null)))),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: InkColors.c400))),
                    Expanded(child: _priceInput(dark, _priceTo, 'search_filters.price_to'.tr(), (v) => _set(_f.copyWith(maxPrice: v, clearMaxPrice: v == null)))),
                  ]),
                  const SizedBox(height: 18),
                  _label(dark, 'search_filters.prefs_label'.tr()),
                  _prefRow(dark, Icons.person, 'search_filters.pref_women_only'.tr(), _f.womenOnly, (v) => _set(_f.copyWith(womenOnly: v))),
                  _prefRow(dark, Icons.smoke_free, 'search_filters.pref_no_smoking'.tr(), _f.noSmoking, (v) => _set(_f.copyWith(noSmoking: v))),
                  _prefRow(dark, Icons.pets, 'search_filters.pref_pets'.tr(), _f.pets, (v) => _set(_f.copyWith(pets: v))),
                  _prefRow(dark, Icons.verified_user, 'search_filters.only_verified'.tr(), _f.onlyVerified, (v) => _set(_f.copyWith(onlyVerified: v))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(bool dark, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: InkColors.c400)),
      );

  Widget _cityRow(bool dark) {
    Widget field(String value, String hint, ValueChanged<String> onPick) => GestureDetector(
          onTap: () async {
            final c = await showCityPicker(context);
            if (c != null) onPick(c);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: dark ? InkColors.c900 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
            ),
            child: Text(value.isEmpty ? hint : value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: value.isEmpty ? InkColors.c400 : (dark ? Colors.white : InkColors.c900))),
          ),
        );

    return Column(children: [
      field(_from, 'search_filters.from_placeholder'.tr(), (v) => setState(() => _from = v)),
      Row(children: [
        Expanded(child: Container(height: 1, color: dark ? InkColors.c800 : InkColors.c100)),
        GestureDetector(
          onTap: () => setState(() {
            final t = _from;
            _from = _to;
            _to = t;
          }),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            width: 24,
            height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: dark ? InkColors.c700 : InkColors.c200)),
            child: const Icon(Icons.swap_horiz, size: 12, color: InkColors.c400),
          ),
        ),
        Expanded(child: Container(height: 1, color: dark ? InkColors.c800 : InkColors.c100)),
      ]),
      field(_to, 'search_filters.to_placeholder'.tr(), (v) => setState(() => _to = v)),
    ]);
  }

  Widget _calendarField(bool dark) {
    final isCustom = _f.date.isNotEmpty && _f.date != 'any' && _f.date != _todayYmd && _f.date != _tomorrowYmd;
    return GestureDetector(
      onTap: () => showDatePickerModal(
        context,
        value: isCustom ? _f.date : '',
        min: _todayYmd,
        dayCounts: mockCalendarCounts(),
        onChange: (v) => _set(_f.copyWith(date: v.isEmpty ? '' : v)),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today, size: 15, color: isCustom ? BrandColors.c600 : InkColors.c400),
          const SizedBox(width: 8),
          Text(isCustom ? _f.date : 'search_filters.date_pick'.tr(),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isCustom ? (dark ? Colors.white : InkColors.c900) : InkColors.c400)),
        ]),
      ),
    );
  }

  Widget _priceInput(bool dark, TextEditingController c, String hint, ValueChanged<int?> onChanged) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) => onChanged(v.isEmpty ? null : int.tryParse(v)),
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: InkColors.c400),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true,
          fillColor: dark ? InkColors.c900 : Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200)),
        ),
      );

  Widget _prefRow(bool dark, IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dark ? InkColors.c800 : InkColors.c100))),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: value ? BrandColors.c600 : InkColors.c400),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: dark ? InkColors.c200 : InkColors.c700)),
          ),
          Switch(value: value, onChanged: onChanged, activeTrackColor: BrandColors.c600),
        ],
      ),
    );
  }
}
