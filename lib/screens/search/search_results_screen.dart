import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/feed_filters.dart';
import '../../models/trip_card_item.dart';
import '../../providers/data_providers.dart';
import '../../utils/config.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/date_picker_modal.dart';
import '../../widgets/filters_sheet.dart';
import '../../widgets/query_error.dart';
import '../../widgets/request_card.dart';
import '../../widgets/trip_card.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../trip/trip_detail_screen.dart' show showTripDetailSheet;

/// Results page (the «next page» after searching from the hub). Shows the
/// route header (editable) + a control row (filters · date stepper) + the
/// trips/requests list. Passenger = trips (teal); driver = requests (grape).
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen(
      {super.key,
      required this.initial,
      required this.driver,
      this.openFilters = false});

  final FeedFilters initial;
  final bool driver;
  final bool openFilters;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late FeedFilters _filters = widget.initial;
  bool get _driver => widget.driver;

  @override
  void initState() {
    super.initState();
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

  static const _monthsShort = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
  ];

  String get _today => ymd(DateTime.now());
  String get _current =>
      (_filters.date.isEmpty || _filters.date == 'any') ? _today : _filters.date;

  List<TripCardItem> _applyFilters(List<TripCardItem> all) {
    var list = List<TripCardItem>.from(all);
    if (_filters.date != 'any') {
      final eff = _filters.date.isEmpty ? _today : _filters.date;
      list = list.where((t) => ymd(t.departureAt) == eff).toList();
    }
    if (_filters.onlyVerified) list = list.where((t) => t.driver.verified).toList();
    if (_filters.luggage.isNotEmpty) list = list.where((t) => t.luggage == _filters.luggage).toList();
    if (_filters.minRating > 0) list = list.where((t) => (t.driver.rating ?? 0) >= _filters.minRating).toList();
    if (_filters.minPrice != null) list = list.where((t) => t.pricePerSeat >= _filters.minPrice!).toList();
    if (_filters.maxPrice != null) list = list.where((t) => t.pricePerSeat <= _filters.maxPrice!).toList();
    switch (_filters.sort) {
      case 'price_asc':
        list.sort((a, b) => a.pricePerSeat.compareTo(b.pricePerSeat));
      case 'rating_desc':
        list.sort((a, b) => (b.driver.rating ?? 0).compareTo(a.driver.rating ?? 0));
      default:
        list.sort((a, b) => a.departureAt.compareTo(b.departureAt));
    }
    return list;
  }

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
            _header(dark, driver),
            _dateBar(context, dark, driver, accent),
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
  Widget _header(bool dark, bool driver) {
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
                Text('${_filters.from} — ${_filters.to}',
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
            onTap: () => setState(() => _filters =
                _filters.copyWith(from: _filters.to, to: _filters.from)),
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
    final current = (_filters.date.isEmpty || _filters.date == 'any')
        ? today
        : _filters.date;
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

    final acc = driver ? GrapeColors.c500 : BrandColors.c500;

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
    final color = driver ? GrapeColors.c600 : BrandColors.c600;
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
            Icon(Icons.tune, size: 20, color: color),
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
                      BoxDecoration(color: color, shape: BoxShape.circle),
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
              from: _filters.from,
              to: _filters.to,
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
          from: _filters.from,
          to: _filters.to,
        )))
        .valueOrNull;
    if (counts == null || counts.isEmpty) return const SizedBox.shrink();
    final nd = _nextAvailableDay(requests);
    final color = requests ? GrapeColors.c600 : BrandColors.c600;
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
            Icon(Icons.calendar_month_outlined, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text('feed.next_day_none'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
    final bg = requests
        ? (dark ? GrapeColors.c500.withValues(alpha: 0.12) : GrapeColors.c50)
        : (dark ? BrandColors.c500.withValues(alpha: 0.12) : BrandColors.c50);
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
            Icon(Icons.event_available, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'feed.next_day_show'.tr(
                    namedArgs: {'date': _dayLabel(nd.date), 'count': count}),
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: color),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: color),
          ]),
        ),
      ),
    );
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
            final trips = AppConfig.useMock ? _applyFilters(all) : all;
            if (trips.isEmpty) {
              return SliverToBoxAdapter(child: _emptyBlock(dark, false));
            }
            return SliverMainAxisGroup(slivers: [
              SliverList.separated(
                itemCount: trips.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => TripCard(
                    trip: trips[i],
                    onTap: () => showTripDetailSheet(context, trips[i].id)),
              ),
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
              SliverList.separated(
                itemCount: reqs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => RequestCard(
                    request: reqs[i],
                    onTap: () => context.push('/requests/${reqs[i].id}')),
              ),
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
