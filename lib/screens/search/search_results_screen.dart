import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/services/misc_services.dart' show MapItem;
import '../../models/feed_filters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../create/create_screen.dart' show CreatePrefill;
import '../../utils/airport.dart';
import '../../utils/date_format.dart';
import '../../utils/locale.dart';
import '../../utils/location.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/date_picker_modal.dart';
import '../../widgets/filters_sheet.dart';
import '../../widgets/query_error.dart';
import '../../widgets/request_card.dart';
import '../../widgets/trip_card.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../map/map_nearby.dart';
import '../map/route_results_map.dart';
import '../trip/trip_detail_screen.dart' show showTripDetailSheet;

/// «Список | Карта» — the last choice, remembered for the app session.
final resultsMapViewProvider = StateProvider<bool>((ref) => false);

/// Results page (the «next page» after searching from the hub). Shows the
/// route header (editable) + a control row (filters · date stepper) + the
/// trips/requests list. Passenger = trips; driver = requests (both teal).
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen(
      {super.key,
      required this.initial,
      required this.driver,
      this.openFilters = false,
      this.mapView});

  final FeedFilters initial;
  final bool driver;
  final bool openFilters;

  /// `?view=map|list`; null → the session's last choice.
  final bool? mapView;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late FeedFilters _filters = widget.initial;
  late bool _mapView = widget.mapView ?? ref.read(resultsMapViewProvider);
  bool _canSortNear = false; // location on + the user is near «Откуда»
  bool get _driver => widget.driver;

  @override
  void initState() {
    super.initState();
    _checkNear();
    // Arrived from the hub's filter icon → open the full filter sheet (which
    // also lets the user change Откуда/Куда).
    if (widget.openFilters) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openFilters());
    }
  }

  void _openFilters() => showFiltersSheet(
        context,
        initial: _filters,
        accent: _driver ? ChipAccent.grape : ChipAccent.brand,
        onChanged: (f) => setState(() => _filters = f),
      );

  Future<void> _checkNear() async {
    final loc = ref.read(locationServiceProvider);
    if (await loc.status() != LocPermission.granted) return;
    final me = loc.last ?? await loc.lastKnown();
    final from = _filters.from;
    final near = me != null &&
        inKyrgyzstan(me) &&
        (from == null || !from.hasPoint || haversineKm(me, (lat: from.lat!, lng: from.lng!)) <= 50);
    if (mounted && near != _canSortNear) setState(() => _canSortNear = near);
  }

  void _setView(bool map) {
    ref.read(resultsMapViewProvider.notifier).state = map;
    setState(() => _mapView = map);
  }

  static const _monthsShort = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
  ];

  String get _today => ymd(DateTime.now());
  String get _current =>
      (_filters.date.isEmpty || _filters.date == 'any') ? _today : _filters.date;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final driver = _driver;
    final accent = driver ? ChipAccent.grape : ChipAccent.brand;

    final async = driver
        ? ref.watch(requestsFeedProvider(_filters))
        : ref.watch(tripsFeedProvider(_filters));
    final hasMore = async.hasValue &&
        (driver
            ? ref.read(requestsFeedProvider(_filters).notifier).hasMore
            : ref.read(tripsFeedProvider(_filters).notifier).hasMore);
    final showNearby = !driver &&
        async.hasValue &&
        ref.read(tripsFeedProvider(_filters).notifier).nearby;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(dark),
            _dateBar(context, dark, driver, accent),
            _viewToggle(),
            if (_mapView)
              Expanded(child: _mapBody(dark, driver))
            else
              Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
                    driver
                        ? ref.read(requestsFeedProvider(_filters).notifier).loadMore()
                        : ref.read(tripsFeedProvider(_filters).notifier).loadMore();
                  }
                  return false;
                },
                child: RefreshIndicator(
                  color: BrandColors.c500,
                  onRefresh: () async {
                    if (driver) {
                      ref.invalidate(requestsFeedProvider(_filters));
                      await ref.read(requestsFeedProvider(_filters).future);
                    } else {
                      ref.invalidate(tripsFeedProvider(_filters));
                      await ref.read(tripsFeedProvider(_filters).future);
                    }
                  },
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (_canSortNear && _filters.targetTime == null)
                        SliverToBoxAdapter(child: _nearSortChip()),
                      if (_filters.targetTime != null)
                        SliverToBoxAdapter(child: _targetBanner(dark)),
                      if (showNearby)
                        SliverToBoxAdapter(child: _nearbyBanner(dark)),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            24 + MediaQuery.of(context).padding.bottom),
                        sliver: driver ? _requestList(dark) : _tripList(dark),
                      ),
                      if (hasMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: BrandColors.c500)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Compact header: back + «Когда хотите поехать?» + route + swap ──────────
  Widget _header(bool dark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/'),
            icon: Icon(Icons.arrow_back,
                color: dark ? Colors.white : InkColors.c900),
          ),
          Expanded(
            child: Column(
              children: [
                Text('feed.when_go'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: dark ? Colors.white : InkColors.c900)),
                const SizedBox(height: 1),
                Text('${_filters.from?.name(isKg(context)) ?? ''} — ${_filters.to?.name(isKg(context)) ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: InkColors.c400)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _filters = _filters.copyWith(
                from: _filters.to,
                to: _filters.from,
                clearFrom: _filters.to == null,
                clearTo: _filters.from == null,
                clearTarget: true)),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: dark ? InkColors.c800 : InkColors.c100,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.swap_vert,
                  size: 20, color: dark ? InkColors.c300 : InkColors.c500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Date chips (Сегодня · Завтра · …) + filter icon ───────────────────────
  Widget _dateBar(
      BuildContext context, bool dark, bool driver, ChipAccent accent) {
    final today = ymd(DateTime.now());
    // «Любая дата» (from the filters sheet) highlights no day chip.
    final current = _filters.date.isEmpty ? today : _filters.date;
    final days = [
      for (var i = 0; i < 3; i++) ymd(DateTime.now().add(Duration(days: i)))
    ];
    String label(String d) {
      if (d == today) return 'feed.today'.tr();
      if (d == ymd(DateTime.now().add(const Duration(days: 1)))) {
        return 'feed.tomorrow'.tr();
      }
      final p = d.split('-');
      return '${int.parse(p[2])} ${_monthsShort[int.parse(p[1]) - 1]}';
    }

    const acc = BrandColors.c500;

    Widget chip(String d) {
      final sel = d == current;
      return GestureDetector(
        onTap: () => setState(() => _filters = _filters.copyWith(date: d)),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: sel
                ? acc
                : (dark ? InkColors.c900 : Colors.white),
            borderRadius: BorderRadius.circular(999),
            border: sel
                ? null
                : Border.all(color: dark ? InkColors.c800 : InkColors.c200),
          ),
          child: Text(label(d),
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: sel
                      ? Colors.white
                      : (dark ? InkColors.c100 : InkColors.c800))),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 12),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final d in days) chip(d),
              // Calendar — pick any other date.
              GestureDetector(
                onTap: () => showDatePickerModal(
                  context,
                  value: current == today ? '' : current,
                  min: today,
                  dayCounts: const {},
                  onChange: (v) =>
                      setState(() => _filters = _filters.copyWith(date: v)),
                ),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: dark ? InkColors.c900 : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border:
                        Border.all(color: dark ? InkColors.c800 : InkColors.c200),
                  ),
                  child: Icon(Icons.calendar_month,
                      size: 18, color: dark ? InkColors.c300 : InkColors.c600),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        _filterButton(context, dark, driver, accent),
      ]),
    );
  }

  Widget _filterButton(
      BuildContext context, bool dark, bool driver, ChipAccent accent) {
    final count = _filters.activeCount;
    const color = BrandColors.c600;
    return GestureDetector(
      onTap: () => showFiltersSheet(
        context,
        initial: _filters,
        accent: accent,
        onChanged: (f) => setState(() => _filters = f),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            const Icon(Icons.tune, size: 20, color: color),
            if (count > 0)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  alignment: Alignment.center,
                  decoration:
                      const BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Text('$count',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _dayLabel(String date) {
    if (date == _today) return 'feed.today'.tr();
    if (date == ymd(DateTime.now().add(const Duration(days: 1)))) {
      return 'feed.tomorrow'.tr();
    }
    final p = date.split('-');
    return '${int.parse(p[2])} ${_monthsShort[int.parse(p[1]) - 1]}';
  }

  ({String date, int count})? _nextAvailableDay(bool requests) {
    final counts = ref
            .read(calendarCountsProvider((
              kind: requests ? 'requests' : 'trips',
              from: _filters.from?.id,
              to: _filters.to?.id,
            )))
            .valueOrNull ??
        const <String, int>{};
    final current = _current;
    final available = counts.entries
        .where((e) => e.value > 0 && e.key.compareTo(_today) >= 0)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    for (final e in available) {
      if (e.key.compareTo(current) > 0) return (date: e.key, count: e.value);
    }
    return null;
  }

  Widget _nextDayCta(bool dark, bool requests) {
    // Only show once the route's per-day counts are actually loaded — otherwise
    // the CTA flashes with an empty calendar and reads as broken (web parity).
    final counts = ref
        .watch(calendarCountsProvider((
          kind: requests ? 'requests' : 'trips',
          from: _filters.from?.id,
          to: _filters.to?.id,
        )))
        .valueOrNull;
    if (counts == null || counts.isEmpty) return const SizedBox.shrink();
    final nd = _nextAvailableDay(requests);
    const color = BrandColors.c600;
    if (nd == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showDatePickerModal(
            context,
            value: (_filters.date.isEmpty ||
                    _filters.date == 'any' ||
                    _filters.date == _today)
                ? ''
                : _filters.date,
            min: _today,
            dayCounts: counts,
            onChange: (v) =>
                setState(() => _filters = _filters.copyWith(date: v)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.calendar_month_outlined, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text('feed.next_day_none'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: color,
                      decoration: TextDecoration.underline,
                      decorationColor: color)),
            ),
          ]),
        ),
      );
    }
    final bg = dark ? BrandColors.c500.withValues(alpha: 0.12) : BrandColors.c50;
    final count = (requests ? 'feed.requests_plural' : 'feed.trips_plural')
        .plural(nd.count);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: GestureDetector(
        onTap: () =>
            setState(() => _filters = _filters.copyWith(date: nd.date)),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppRadii.xl2),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.event_available, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'feed.next_day_show'.tr(
                    namedArgs: {'date': _dayLabel(nd.date), 'count': count}),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: color),
          ]),
        ),
      ),
    );
  }

  // ── «Список | Карта» ───────────────────────────────────────────────────────
  Widget _viewToggle() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.view_list_rounded, size: 18),
                  label: Text('map.view_list'.tr())),
              ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text('map.view_map'.tr())),
            ],
            selected: {_mapView},
            onSelectionChanged: (v) => _setView(v.first),
          ),
        ),
      );

  Widget _nearSortChip() {
    final on = _filters.sort == 'nearest';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilterChip(
          avatar: const Icon(Icons.near_me_rounded, size: 16),
          label: Text('map.sort_near'.tr()),
          selected: on,
          showCheckmark: false,
          onSelected: (_) => setState(() => _filters = _filters.copyWith(sort: on ? 'time' : 'nearest')),
        ),
      ),
    );
  }

  // Map view: every listing of this route (GET /map/route), pinned at their
  // pickup points. Loaded list pages stand in while it loads (or without a route).
  Widget _mapBody(bool dark, bool driver) {
    final from = _filters.from;
    void open(String id) => driver ? context.push('/requests/$id') : showTripDetailSheet(context, id);
    Widget map(List<MapItem> items, {bool nearby = false, bool truncated = false}) => items.isEmpty
        ? SingleChildScrollView(child: _emptyBlock(dark, driver))
        : RouteResultsMap(
            items: items,
            requests: driver,
            origin: from,
            airport: from?.isAirport == true ? from : (_filters.to?.isAirport == true ? _filters.to : null),
            nearby: nearby,
            truncated: truncated,
            onOpen: open,
          );
    Widget err(Object e, VoidCallback retry) => SingleChildScrollView(child: QueryError(error: e, onRetry: retry));
    final feed = driver
        ? ref.watch(requestsFeedProvider(_filters)).whenData((all) => all.map((r) => requestPin(r, fallback: from)))
        : ref.watch(tripsFeedProvider(_filters)).whenData((all) => all.map((t) => tripPin(t, fallback: from)));
    void retryFeed() =>
        driver ? ref.invalidate(requestsFeedProvider(_filters)) : ref.invalidate(tripsFeedProvider(_filters));
    Widget fromFeed() => feed.when(
          loading: () => const _LoadingBlock(),
          error: (e, _) => err(e, retryFeed),
          data: (pins) => map(pins.nonNulls.toList()),
        );
    final key = (requests: driver, filters: _filters);
    return ref.watch(mapRouteProvider(key)).when(
          loading: fromFeed,
          error: (e, _) => err(e, () => ref.invalidate(mapRouteProvider(key))),
          data: (route) => route == null
              ? fromFeed()
              : map(route.items, nearby: route.nearby, truncated: route.truncated),
        );
  }

  void _create(bool driver) {
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      context.push('/auth/login');
      return;
    }
    final target = _filters.targetTime == null ? null : DateTime.tryParse(_filters.targetTime!)?.toLocal();
    context.push('/trips/create?kind=${driver ? 'trip' : 'request'}',
        extra: CreatePrefill(from: _filters.from, to: _filters.to, departureAt: target));
  }

  // Airport search: results ranked around the flight / pickup time.
  Widget _targetBanner(bool dark) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(children: [
          const Icon(Icons.schedule_rounded, size: 16, color: BrandColors.c600),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                'airport.target_banner'
                    .tr(namedArgs: {'time': hhmm(DateTime.parse(_filters.targetTime!))}),
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: dark ? InkColors.c200 : InkColors.c700)),
          ),
        ]),
      );

  /// target_time results: «Подходят по времени», then «Остальные в этот день».
  List<Widget> _grouped<T>(List<T> items, bool? Function(T) nearOf, Widget Function(T) card) {
    Widget list(List<T> xs) => SliverList.separated(
          itemCount: xs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => card(xs[i]),
        );
    if (_filters.targetTime == null) return [list(items)];
    final g = groupByTarget(items, nearOf);
    Widget head(String key, {bool first = false}) => SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: first ? 0 : 18, bottom: 8),
            child: Text(key.tr(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: InkColors.c500)),
          ),
        );
    return [
      if (g.near.isNotEmpty) ...[head('airport.group_near', first: true), list(g.near)],
      if (g.rest.isNotEmpty) ...[head('airport.group_rest', first: g.near.isEmpty), list(g.rest)],
    ];
  }

  Widget _nearbyBanner(bool dark) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: dark
              ? AccentColors.c500.withValues(alpha: 0.12)
              : AccentColors.c50,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
              color: dark
                  ? AccentColors.c500.withValues(alpha: 0.25)
                  : AccentColors.c100),
        ),
        child: Row(children: [
          const Icon(Icons.near_me_outlined, size: 16, color: AccentColors.c600),
          const SizedBox(width: 8),
          Expanded(
              child: Text('feed.nearby_banner'.tr(),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AccentColors.c700))),
        ]),
      );

  Widget _tripList(bool dark) {
    return ref.watch(tripsFeedProvider(_filters)).when(
          loading: () => const SliverToBoxAdapter(child: _LoadingBlock()),
          error: (e, _) => SliverToBoxAdapter(
              child: QueryError(
                  error: e,
                  onRetry: () => ref.invalidate(tripsFeedProvider(_filters)))),
          data: (all) {
            final trips = all;
            if (trips.isEmpty) {
              return SliverToBoxAdapter(child: _emptyBlock(dark, false));
            }
            return SliverMainAxisGroup(slivers: [
              ..._grouped(trips, (t) => t.nearTarget,
                  (t) => TripCard(trip: t, onTap: () => showTripDetailSheet(context, t.id))),
              SliverToBoxAdapter(child: _nextDayCta(dark, false)),
            ]);
          },
        );
  }

  Widget _requestList(bool dark) {
    return ref.watch(requestsFeedProvider(_filters)).when(
          loading: () => const SliverToBoxAdapter(child: _LoadingBlock()),
          error: (e, _) => SliverToBoxAdapter(
              child: QueryError(
                  error: e,
                  onRetry: () =>
                      ref.invalidate(requestsFeedProvider(_filters)))),
          data: (reqs) {
            if (reqs.isEmpty) {
              return SliverToBoxAdapter(child: _emptyBlock(dark, true));
            }
            return SliverMainAxisGroup(slivers: [
              ..._grouped(reqs, (r) => r.nearTarget,
                  (r) => RequestCard(request: r, onTap: () => context.push('/requests/${r.id}'))),
              SliverToBoxAdapter(child: _nextDayCta(dark, true)),
            ]);
          },
        );
  }

  Widget _emptyBlock(bool dark, bool requests) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(children: [
          Icon(requests ? Icons.inbox_outlined : Icons.event_busy,
              size: 40, color: InkColors.c400),
          const SizedBox(height: 12),
          Text(
              (requests
                      ? 'empty.passenger_requests.title'
                      : 'empty.passenger_trips.title')
                  .tr(),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: dark ? Colors.white : InkColors.c900)),
          const SizedBox(height: 4),
          Text(
              (requests
                      ? 'empty.passenger_requests.description'
                      : 'empty.passenger_trips.description')
                  .tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: InkColors.c400)),
          const SizedBox(height: 16),
          AppButton(
            label: (requests ? 'map.publish_trip' : 'map.create_request').tr(),
            variant: AppButtonVariant.outline,
            expand: false,
            onPressed: () => _create(requests),
          ),
          _nextDayCta(dark, requests),
        ]),
      );
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2.6, color: BrandColors.c500)),
      );
}
