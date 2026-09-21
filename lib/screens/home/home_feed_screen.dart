import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/feed_filters.dart';
import '../../utils/config.dart';
import '../../models/trip_card_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../widgets/online_badge.dart';
import '../../widgets/query_error.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/city_picker.dart';
import '../../widgets/date_picker_modal.dart';
import '../../widgets/filters_sheet.dart';
import '../../widgets/intent_toggle.dart';
import '../../widgets/request_card.dart';
import '../../widgets/trip_card.dart';
import '../trip/trip_detail_screen.dart' show showTripDetailSheet;

/// Home feed — 1:1 port of terme_ft feed-header + search-layout / requests-feed.
/// Map band → intent toggle → search card → sticky (filters chip + date stepper)
/// → cards. Passenger shows trips (teal); driver shows requests (grape).
class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  FeedFilters _filters = const FeedFilters();

  static const _monthsShort = [
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек'
  ];

  String get _today => ymd(DateTime.now());
  String get _current => (_filters.date.isEmpty || _filters.date == 'any')
      ? _today
      : _filters.date;

  /// Applies the active filters + sort to a trip list (from the provider).
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
        list.sort(
            (a, b) => (b.driver.rating ?? 0).compareTo(a.driver.rating ?? 0));
      default:
        list.sort((a, b) => a.departureAt.compareTo(b.departureAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final driver = ref.watch(authProvider).activeMode == ActiveMode.driver;
    final accent = driver ? ChipAccent.grape : ChipAccent.brand;

    // Watch the async value so nearby/hasMore reflect the latest page load.
    // Only touch the ACTIVE mode's notifier (reading the other would fire its build).
    // Web parity: only load the paginated feed once a route is chosen. The
    // empty state shows recent searches + popular routes — not an endless list.
    final hasRoute = _filters.from.isNotEmpty && _filters.to.isNotEmpty;
    final async = hasRoute
        ? (driver
            ? ref.watch(requestsFeedProvider(_filters))
            : ref.watch(tripsFeedProvider(_filters)))
        : null;
    final hasMore = hasRoute &&
        async!.hasValue &&
        (driver
            ? ref.read(requestsFeedProvider(_filters).notifier).hasMore
            : ref.read(tripsFeedProvider(_filters).notifier).hasMore);
    final showNearby = hasRoute &&
        !driver &&
        async!.hasValue &&
        ref.read(tripsFeedProvider(_filters).notifier).nearby;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (hasRoute && n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
            driver
                ? ref.read(requestsFeedProvider(_filters).notifier).loadMore()
                : ref.read(tripsFeedProvider(_filters).notifier).loadMore();
          }
          return false;
        },
        child: RefreshIndicator(
          color: BrandColors.c500,
          onRefresh: () async {
            if (!hasRoute) {
              ref.invalidate(popularRoutesProvider);
              await ref.read(popularRoutesProvider.future);
              return;
            }
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
              SliverToBoxAdapter(child: _header(context, dark, driver)),
              // Filters + date stepper appear only after a route is picked.
              if (hasRoute)
                SliverPersistentHeader(
                    pinned: true,
                    delegate: _StickyBar(
                        child: _controlBar(context, dark, driver, accent))),
              if (showNearby) SliverToBoxAdapter(child: _nearbyBanner(dark)),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    AppLayout.pillNavClearance +
                        MediaQuery.of(context).padding.bottom),
                sliver: !hasRoute
                    ? _entryHints(dark, driver)
                    : (driver ? _requestList(dark) : _tripList(dark)),
              ),
              if (hasMore)
                const SliverToBoxAdapter(
                  child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: BrandColors.c500))),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty state: recent searches + popular routes (web FeedEntryHints) ──────
  Widget _entryHints(bool dark, bool driver) {
    final recent = _recentRoutes();
    final accent = driver ? GrapeColors.c600 : BrandColors.c600;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(alignment: Alignment.centerRight, child: OnlineBadge()),
          const SizedBox(height: 10),
          Text('feed.route_hint'.tr(),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: InkColors.c400)),
          const SizedBox(height: 18),
          if (recent.isNotEmpty) ...[
            _hintHeader(Icons.history, 'feed.recent_searches'.tr(), dark),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in recent)
                _routeChip(r.from, r.to, null, dark, accent),
            ]),
            const SizedBox(height: 20),
          ],
          _hintHeader(Icons.trending_up, 'feed.popular_routes'.tr(), dark),
          const SizedBox(height: 10),
          ref.watch(popularRoutesProvider).when(
                loading: () => const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: BrandColors.c500))),
                error: (_, __) => const SizedBox.shrink(),
                data: (routes) => Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final r in routes)
                    _routeChip(r.from, r.to, r.tripCount, dark, accent),
                ]),
              ),
        ],
      ),
    );
  }

  Widget _hintHeader(IconData icon, String text, bool dark) => Row(children: [
        Icon(icon, size: 18, color: dark ? InkColors.c300 : InkColors.c700),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: dark ? InkColors.c100 : InkColors.c800)),
      ]);

  Widget _routeChip(
          String from, String to, int? count, bool dark, Color accent) =>
      GestureDetector(
        onTap: () => _applyRoute(from, to),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('$from → $to',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : InkColors.c900)),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Text('$count',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: accent)),
            ],
          ]),
        ),
      );

  // ── Recent routes (Hive, max 3 · web terme_recent_routes parity) ─────────
  List<({String from, String to})> _recentRoutes() {
    final raw =
        (ref.read(hiveBoxProvider).get(StorageKeys.recentRoutes) as List?) ??
            const [];
    return raw
        .whereType<String>()
        .map((s) {
          final p = s.split('|');
          return (from: p.isNotEmpty ? p[0] : '', to: p.length > 1 ? p[1] : '');
        })
        .where((r) => r.from.isNotEmpty && r.to.isNotEmpty)
        .toList();
  }

  void _saveRecentRoute(String from, String to) {
    if (from.isEmpty || to.isEmpty) return;
    final box = ref.read(hiveBoxProvider);
    final cur = (((box.get(StorageKeys.recentRoutes) as List?) ?? const [])
        .whereType<String>()
        .toList());
    final key = '$from|$to';
    cur.removeWhere((s) => s == key);
    cur.insert(0, key);
    box.put(StorageKeys.recentRoutes, cur.take(3).toList());
  }

  void _applyRoute(String from, String to) {
    setState(() => _filters = _filters.copyWith(from: from, to: to));
    _saveRecentRoute(from, to);
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
          const Icon(Icons.near_me_outlined,
              size: 16, color: AccentColors.c600),
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
            // Real API already filters+sorts server-side (like web); only apply
            // client-side filtering to the bundled mock data.
            final trips = AppConfig.useMock ? _applyFilters(all) : all;
            if (trips.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Column(children: [
                    const Icon(Icons.event_busy,
                        size: 40, color: InkColors.c400),
                    const SizedBox(height: 12),
                    Text('empty.passenger_trips.title'.tr(),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: dark ? Colors.white : InkColors.c900)),
                    const SizedBox(height: 4),
                    Text('empty.passenger_trips.description'.tr(),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: InkColors.c400)),
                    _nextDayCta(dark, false),
                  ]),
                ),
              );
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
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 48),
                  child: Column(children: [
                    const Icon(Icons.inbox_outlined,
                        size: 40, color: InkColors.c400),
                    const SizedBox(height: 12),
                    Text('empty.passenger_requests.title'.tr(),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: dark ? Colors.white : InkColors.c900)),
                    const SizedBox(height: 4),
                    Text('empty.passenger_requests.description'.tr(),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: InkColors.c400)),
                    _nextDayCta(dark, true),
                  ]),
                ),
              );
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

  // ── Header: map band + intent toggle + search card ─────────────────────────
  Widget _header(BuildContext context, bool dark, bool driver) {
    return Column(
      children: [
        // Decorative map band (mint → lavender) with dashed route.
        Padding(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          child: Container(
            height: 96,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [BrandColors.c100, GrapeColors.c100],
              ),
            ),
            child: CustomPaint(painter: _MapRoutePainter()),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: [
                IntentToggle(
                  driver: driver,
                  showHint: true,
                  onChanged: (d) => ref
                      .read(authProvider.notifier)
                      .setActiveMode(
                          d ? ActiveMode.driver : ActiveMode.passenger),
                ),
                const SizedBox(height: 10),
                _searchCard(context, dark),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchCard(BuildContext context, bool dark) {
    Widget cityField(String value, String hint, Color dot,
            ValueChanged<String> onPick) =>
        Row(
          children: [
            Icon(Icons.circle, size: 14, color: dot),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final c = await showCityPicker(context);
                  if (c != null) onPick(c);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 40,
                  alignment: Alignment.centerLeft,
                  child: Text(value.isEmpty ? hint : value,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: value.isEmpty
                              ? InkColors.c400
                              : (dark ? Colors.white : InkColors.c900))),
                ),
              ),
            ),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        boxShadow: AppShadows.lift,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: cityField(_filters.from,
                          'feed.from_placeholder'.tr(), BrandColors.c600, (v) {
                        setState(() => _filters = _filters.copyWith(from: v));
                        if (_filters.to.isNotEmpty) _saveRecentRoute(v, _filters.to);
                      }))),
              GestureDetector(
                onTap: (_filters.from.isEmpty || _filters.to.isEmpty)
                    ? null
                    : () => setState(() => _filters = _filters.copyWith(
                        from: _filters.to, to: _filters.from)),
                child: Opacity(
                  opacity:
                      (_filters.from.isEmpty || _filters.to.isEmpty) ? 0.4 : 1,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: dark ? InkColors.c800 : InkColors.c100,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.swap_vert,
                        size: 16,
                        color: dark ? InkColors.c300 : InkColors.c500),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Container(
                height: 1, color: dark ? InkColors.c700 : InkColors.c200),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 40),
            child: cityField(
                _filters.to, 'feed.to_placeholder'.tr(), AccentColors.c500,
                (v) {
              setState(() => _filters = _filters.copyWith(to: v));
              if (_filters.from.isNotEmpty) _saveRecentRoute(_filters.from, v);
            }),
          ),
        ],
      ),
    );
  }

  // ── Sticky control bar: filters chip + date stepper ────────────────────────
  Widget _controlBar(
      BuildContext context, bool dark, bool driver, ChipAccent accent) {
    return Container(
      decoration: BoxDecoration(
        color: (dark ? InkColors.c950 : InkColors.c50).withValues(alpha: 0.92),
        border: Border(
            bottom: BorderSide(color: dark ? InkColors.c800 : InkColors.c100)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterButton(context, dark, driver, accent),
            const SizedBox(width: 8),
            _dateStepper(context, dark, driver),
          ],
        ),
      ),
    );
  }

  // Filters — icon-only on mobile (a labelled chip ate too much of the bar);
  // an active-count badge appears when any filter is set.
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
    if (date == ymd(DateTime.now().add(const Duration(days: 1)))) return 'feed.tomorrow'.tr();
    final p = date.split('-');
    return '${int.parse(p[2])} ${_monthsShort[int.parse(p[1]) - 1]}';
  }

  // Nearest FUTURE day (after the selected one) that actually has items — used
  // by the in-list «next day» CTA when today's list is empty or ends.
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

  // «Показать {next day} · N поездок/заявок» — jumps the date filter to the next
  // day with items. When there's no such day, shows a quiet «check the calendar»
  // hint instead of a dead-end or a «0» button.
  Widget _nextDayCta(bool dark, bool requests) {
    final nd = _nextAvailableDay(requests);
    final color = requests ? GrapeColors.c600 : BrandColors.c600;
    if (nd == null) {
      final counts = ref
              .read(calendarCountsProvider((
                kind: requests ? 'requests' : 'trips',
                from: _filters.from,
                to: _filters.to,
              )))
              .valueOrNull ??
          const <String, int>{};
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

  Widget _dateStepper(BuildContext context, bool dark, bool driver) {
    // Route-scoped availability counts (web parity): driver sees request counts,
    // passenger sees trip counts; empty until both cities are chosen.
    final counts = ref
            .watch(calendarCountsProvider((
              kind: driver ? 'requests' : 'trips',
              from: _filters.from,
              to: _filters.to,
            )))
            .valueOrNull ??
        const <String, int>{};
    final current = _current;
    final available = counts.entries
        .where((e) => e.value > 0 && e.key.compareTo(_today) >= 0)
        .map((e) => e.key)
        .toList()
      ..sort();
    String? prev;
    String? next;
    for (final d in available) {
      if (d.compareTo(current) < 0) prev = d;
      if (d.compareTo(current) > 0) {
        next = d;
        break;
      }
    }
    final count = counts[current] ?? 0;
    final accent = driver ? GrapeColors.c500 : BrandColors.c500;

    String label;
    if (current == _today) {
      label = 'feed.today'.tr();
    } else if (current == ymd(DateTime.now().add(const Duration(days: 1)))) {
      label = 'feed.tomorrow'.tr();
    } else {
      final p = current.split('-');
      label = '${int.parse(p[2])} ${_monthsShort[int.parse(p[1]) - 1]}';
    }

    Widget arrow(IconData icon, String? target) => GestureDetector(
          onTap: target == null
              ? null
              : () =>
                  setState(() => _filters = _filters.copyWith(date: target)),
          child: Opacity(
            opacity: target == null ? 0.25 : 1,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: dark ? InkColors.c800 : InkColors.c100,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon,
                  size: 20, color: dark ? InkColors.c300 : InkColors.c700),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          arrow(Icons.chevron_left, prev),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.calendar_today, size: 14, color: accent),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : InkColors.c900)),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: count > 0
                      ? (driver
                          ? (dark
                              ? GrapeColors.c500.withValues(alpha: 0.15)
                              : GrapeColors.c100)
                          : (dark
                              ? BrandColors.c500.withValues(alpha: 0.15)
                              : BrandColors.c50))
                      : (dark ? InkColors.c800 : InkColors.c100),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: count > 0
                            ? (driver
                                ? (dark ? GrapeColors.c300 : GrapeColors.c600)
                                : (dark ? BrandColors.c300 : BrandColors.c700))
                            : InkColors.c400)),
              ),
            ]),
          ),
          arrow(Icons.chevron_right, next),
          const SizedBox(width: 2),
          GestureDetector(
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
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: dark ? InkColors.c800 : InkColors.c100,
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.calendar_month,
                  size: 20, color: dark ? InkColors.c300 : InkColors.c700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered loading block for a sliver list while data resolves.
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

/// Dashed curved route over the map band (teal start → amber end dots).
class _MapRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p1 = Offset(w * 0.09, h * 0.78);
    final p2 = Offset(w * 0.93, h * 0.22);
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..cubicTo(w * 0.30, h * 0.75, w * 0.44, h * 0.31, w * 0.65, h * 0.34)
      ..cubicTo(w * 0.80, h * 0.36, w * 0.88, h * 0.20, p2.dx, p2.dy);

    final dash = Paint()
      ..color = BrandColors.c600
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final tan = metric.getTangentForOffset(dist);
        if (tan != null) {
          canvas.drawCircle(
              tan.position, 1.6, dash..style = PaintingStyle.fill);
        }
        dist += 9;
      }
    }
    canvas.drawCircle(p1, 6, Paint()..color = BrandColors.c600);
    canvas.drawCircle(p2, 6, Paint()..color = AccentColors.c500);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pins the control bar under the (scrolled-away) header.
class _StickyBar extends SliverPersistentHeaderDelegate {
  _StickyBar({required this.child});
  final Widget child;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _StickyBar oldDelegate) => true;
}
