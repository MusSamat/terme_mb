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
import '../../widgets/city_picker.dart';
import '../../widgets/query_error.dart';
import '../../widgets/request_card.dart';
import '../../widgets/trip_card.dart';
import '../create/create_screen.dart' show CreatePrefill;
import '../trip/trip_detail_screen.dart' show showTripDetailSheet;

/// Airport transfers: to / from an airport, with the city it serves prefilled.
/// Lists kind=airport trips and requests for the pair; shortcuts open the
/// create form prefilled (the flight number is asked there).
class AirportScreen extends ConsumerStatefulWidget {
  const AirportScreen({super.key});

  @override
  ConsumerState<AirportScreen> createState() => _AirportScreenState();
}

class _AirportScreenState extends ConsumerState<AirportScreen> {
  bool _toAirport = true;
  Airport? _airport;
  Place? _city;
  bool _requests = false;
  String _date = 'any'; // '' = today, 'any', YYYY-MM-DD

  void _select(Airport a) => setState(() {
        _airport = a;
        _city = a.serves ?? _city;
      });

  Future<void> _pickCity() async {
    final p = await showCityPicker(context, nearMe: true);
    if (p != null && mounted) setState(() => _city = p);
  }

  FeedFilters? get _filters {
    final a = _airport?.place;
    if (a == null) return null;
    return FeedFilters(
      from: _toAirport ? _city : a,
      to: _toAirport ? a : _city,
      kind: 'airport',
      date: _date,
    );
  }

  void _create(bool asDriver) {
    final f = _filters;
    final prefill = CreatePrefill(from: f?.from, to: f?.to);
    final authed = ref.read(authProvider).status == AuthStatus.authenticated;
    final path = '/trips/create?kind=${asDriver ? 'trip' : 'request'}';
    if (!authed) {
      context.push('/auth/login');
      return;
    }
    context.push(path, extra: prefill);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final kg = isKg(context);
    final airports = ref.watch(airportsProvider);
    if (_airport == null && (airports.valueOrNull?.isNotEmpty ?? false)) {
      final list = airports.value!;
      // Default: Манас (or whatever the directory lists first).
      final a = list.firstWhere((x) => x.place.nameRu.contains('Манас'), orElse: () => list.first);
      _airport = a;
      _city ??= a.serves;
    }
    final f = _filters;

    return Scaffold(
      appBar: AppBar(
        title: Text('airport.title'.tr(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          IconButton(
            tooltip: 'map.title'.tr(),
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push('/map?kind=${_requests ? 'requests' : 'trips'}&ride=airport',
                extra: _toAirport ? _airport?.place : _city),
          ),
        ],
      ),
      body: airports.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500)),
        error: (e, _) => QueryError(error: e, onRetry: () => ref.invalidate(airportsProvider)),
        data: (list) => CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverList.list(children: [
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: true, icon: const Icon(Icons.flight_takeoff_rounded, size: 18), label: Text('airport.to'.tr())),
                  ButtonSegment(value: false, icon: const Icon(Icons.flight_land_rounded, size: 18), label: Text('airport.from'.tr())),
                ],
                selected: {_toAirport},
                onSelectionChanged: (s) => setState(() => _toAirport = s.first),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in list)
                  ChoiceChip(
                    avatar: const Icon(Icons.flight_rounded, size: 16),
                    label: Text(a.place.name(kg)),
                    selected: _airport?.place.id == a.place.id,
                    onSelected: (_) => _select(a),
                  ),
              ]),
              const SizedBox(height: 12),
              _RouteBox(
                dark: dark,
                top: _toAirport ? _city?.name(kg) : _airport?.place.name(kg),
                topHint: 'airport.city_hint'.tr(),
                bottom: _toAirport ? _airport?.place.name(kg) : _city?.name(kg),
                bottomHint: 'airport.city_hint'.tr(),
                cityOnTop: _toAirport,
                onCity: _pickCity,
              ),
              const SizedBox(height: 12),
              _DateChips(value: _date, onChanged: (v) => setState(() => _date = v)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _Shortcut(
                    icon: Icons.directions_car_rounded,
                    label: 'airport.offer_ride'.tr(),
                    color: GrapeColors.c600,
                    onTap: () => _create(true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Shortcut(
                    icon: Icons.hail_rounded,
                    label: 'airport.need_ride'.tr(),
                    color: BrandColors.c600,
                    onTap: () => _create(false),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text('map.trips'.tr())),
                  ButtonSegment(value: true, label: Text('map.requests'.tr())),
                ],
                selected: {_requests},
                onSelectionChanged: (s) => setState(() => _requests = s.first),
              ),
              const SizedBox(height: 12),
            ]),
          ),
          if (f != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: _requests ? _requestList(f) : _tripList(f),
            ),
        ]),
      ),
    );
  }

  Widget _tripList(FeedFilters f) => ref.watch(tripsFeedProvider(f)).when(
        loading: () => const SliverToBoxAdapter(child: _Loading()),
        error: (e, _) => SliverToBoxAdapter(
            child: QueryError(error: e, onRetry: () => ref.invalidate(tripsFeedProvider(f)))),
        data: (trips) => trips.isEmpty
            ? SliverToBoxAdapter(child: _Empty(text: 'airport.empty_trips'.tr()))
            : SliverList.separated(
                itemCount: trips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    TripCard(trip: trips[i], onTap: () => showTripDetailSheet(context, trips[i].id)),
              ),
      );

  Widget _requestList(FeedFilters f) => ref.watch(requestsFeedProvider(f)).when(
        loading: () => const SliverToBoxAdapter(child: _Loading()),
        error: (e, _) => SliverToBoxAdapter(
            child: QueryError(error: e, onRetry: () => ref.invalidate(requestsFeedProvider(f)))),
        data: (reqs) => reqs.isEmpty
            ? SliverToBoxAdapter(child: _Empty(text: 'airport.empty_requests'.tr()))
            : SliverList.separated(
                itemCount: reqs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    RequestCard(request: reqs[i], onTap: () => context.push('/requests/${reqs[i].id}')),
              ),
      );
}

/// Two-row «откуда / куда»: the airport row is fixed, the city row opens the picker.
class _RouteBox extends StatelessWidget {
  const _RouteBox({
    required this.dark,
    required this.top,
    required this.topHint,
    required this.bottom,
    required this.bottomHint,
    required this.cityOnTop,
    required this.onCity,
  });

  final bool dark;
  final String? top;
  final String topHint;
  final String? bottom;
  final String bottomHint;
  final bool cityOnTop;
  final VoidCallback onCity;

  Widget _row(String? text, String hint, IconData icon, Color color, VoidCallback? onTap) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text ?? hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: text == null ? InkColors.c400 : (dark ? Colors.white : InkColors.c900))),
            ),
            if (onTap != null) const Icon(Icons.chevron_right, size: 20, color: InkColors.c400),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl3),
          border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
          boxShadow: AppShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          _row(top, topHint, cityOnTop ? Icons.trip_origin : Icons.flight_takeoff_rounded, BrandColors.c600,
              cityOnTop ? onCity : null),
          Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
          _row(bottom, bottomHint, cityOnTop ? Icons.flight_land_rounded : Icons.flag_rounded, AccentColors.c500,
              cityOnTop ? null : onCity),
        ]),
      );
}

class _DateChips extends StatelessWidget {
  const _DateChips({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tomorrow = ymdOf(now.add(const Duration(days: 1)));
    final custom = value != 'any' && value.isNotEmpty && value != tomorrow;
    Widget chip(String label, bool sel, VoidCallback onTap) =>
        ChoiceChip(label: Text(label), selected: sel, onSelected: (_) => onTap());
    return Wrap(spacing: 8, runSpacing: 8, children: [
      chip('airport.any_date'.tr(), value == 'any', () => onChanged('any')),
      chip('feed.today'.tr(), value.isEmpty, () => onChanged('')),
      chip('feed.tomorrow'.tr(), value == tomorrow, () => onChanged(tomorrow)),
      ActionChip(
        avatar: const Icon(Icons.event_rounded, size: 16),
        label: Text(custom ? '${value.substring(8, 10)}.${value.substring(5, 7)}' : 'airport.pick_date'.tr()),
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            firstDate: DateTime(now.year, now.month, now.day),
            lastDate: now.add(const Duration(days: 60)),
            initialDate: custom ? DateTime.parse(value) : now,
          );
          if (d != null) onChanged(ymdOf(d));
        },
      ),
    ]);
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    maxLines: 2, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
              ),
            ]),
          ),
        ),
      );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(children: [
          const Icon(Icons.flight_rounded, size: 40, color: InkColors.c400),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400)),
        ]),
      );
}
