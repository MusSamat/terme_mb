import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/services/misc_services.dart' show PopularRoute;
import '../../models/passenger_request.dart';
import '../../models/trip_card_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../utils/config.dart' show StorageKeys;
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/city_picker.dart';
import '../../widgets/date_picker_modal.dart';
import '../../widgets/intent_toggle.dart';
import '../../widgets/logo_mark.dart';
import '../../widgets/online_badge.dart';

/// Home = the search HUB. Rails on top (destinations · popular · history) and a
/// docked search bar above the pill nav. Tapping the bar opens the search modal;
/// submitting NAVIGATES to the results page (`/results`). Results never render
/// here — the main page stays a clean entry surface.
class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  String _from = '';
  String _to = '';
  bool _whole = false;
  String _date = ''; // '' = today

  static const _monthsShort = [
    'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
  ];

  String _dateLabel() {
    final today = ymd(DateTime.now());
    if (_date.isEmpty || _date == today) return 'feed.today'.tr();
    if (_date == ymd(DateTime.now().add(const Duration(days: 1)))) {
      return 'feed.tomorrow'.tr();
    }
    final p = _date.split('-');
    return '${int.parse(p[2])} ${_monthsShort[int.parse(p[1]) - 1]}';
  }

  void _pickDate(BuildContext context) {
    final today = ymd(DateTime.now());
    showDatePickerModal(
      context,
      value: (_date.isEmpty || _date == today) ? '' : _date,
      min: today,
      dayCounts: const {},
      onChange: (v) => setState(() => _date = v),
    );
  }

  @override
  void initState() {
    super.initState();
    // Seed the inline inputs from the last route for convenience.
    final r = _recentRoutes();
    if (r.isNotEmpty) {
      _from = r.first.from;
      _to = r.first.to;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final driver = ref.watch(authProvider).activeMode == ActiveMode.driver;

    final authed = ref
        .watch(authProvider.select((s) => s.status == AuthStatus.authenticated));

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(context, dark),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              child: IntentToggle(
                driver: driver,
                showHint: true,
                onChanged: (d) => ref
                    .read(authProvider.notifier)
                    .setActiveMode(
                        d ? ActiveMode.driver : ActiveMode.passenger),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: BrandColors.c500,
                onRefresh: () async {
                  ref.invalidate(popularRoutesProvider);
                  if (authed) {
                    ref.invalidate(myTripsProvider);
                    ref.invalidate(myRequestsProvider);
                  }
                  await ref.read(popularRoutesProvider.future);
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      sliver: _entryHints(dark, driver, authed),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: AppLayout.pillNavClearance + 12),
              child: _dockedCard(context, dark, driver),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar: logo + wordmark · online count + notifications ────────────────
  Widget _header(BuildContext context, bool dark) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 6, 0),
        child: Row(
          children: [
            const LogoMark(size: 30),
            const SizedBox(width: 9),
            _wordmark(dark),
            const Spacer(),
            const OnlineBadge(),
            IconButton(
              onPressed: () => context.push('/notifications'),
              splashRadius: 22,
              icon: Icon(Icons.notifications_none_rounded,
                  size: 24, color: dark ? InkColors.c200 : InkColors.c700),
            ),
          ],
        ),
      );

  // ── Active trip/request status banner (Yandex-style) ───────────────────────
  // My active trips/requests — a compact block (no header label) between
  // «Популярные» and «История»; tap opens the «Мои» list on the right tab.
  Widget _mineBlock(bool dark) {
    final trips =
        (ref.watch(myTripsProvider).valueOrNull ?? const <TripCardItem>[])
            .where((t) => t.status == 'active')
            .toList();
    final reqs = (ref.watch(myRequestsProvider).valueOrNull ??
            const <PassengerRequestItem>[])
        .where((r) => r.status == 'open')
        .toList();
    if (trips.isEmpty && reqs.isEmpty) return const SizedBox.shrink();
    final isTrip = trips.isNotEmpty;
    final count = isTrip ? trips.length : reqs.length;
    final line =
        (isTrip ? 'feed.mine_trips_line' : 'feed.mine_requests_line').plural(count);
    final sub = (isTrip ? 'feed.mine_trips_sub' : 'feed.mine_requests_sub').tr();
    final accent = isTrip ? BrandColors.c600 : GrapeColors.c600;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        // go (not push): /my/bookings lives in another shell branch — go
        // switches to the «Мои» tab; push wouldn't activate the branch.
        onTap: () =>
            context.go('/my/bookings?tab=${isTrip ? 'trips' : 'requests'}'),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl2),
            border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
            boxShadow: dark ? null : AppShadows.card,
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: dark ? 0.22 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isTrip ? Icons.directions_car_filled : Icons.person,
                  size: 22, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: dark ? Colors.white : InkColors.c900)),
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: InkColors.c400)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: InkColors.c400),
          ]),
        ),
      ),
    );
  }

  Widget _wordmark(bool dark) => Text.rich(
        TextSpan(
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: dark ? Colors.white : InkColors.c900),
          children: const [
            TextSpan(text: 'Ter'),
            TextSpan(text: 'me', style: TextStyle(color: BrandColors.c600)),
          ],
        ),
      );

  // ── Docked search card — inline Откуда/Куда inputs; «Найти» → results ───────
  Widget _dockedCard(BuildContext context, bool dark, bool driver) {
    final ready = _from.isNotEmpty && _to.isNotEmpty;
    final ctaColor = driver ? GrapeColors.c600 : AccentColors.c500;
    final ctaText = driver ? Colors.white : AccentColors.ink;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl4),
        boxShadow: dark ? null : AppShadows.lift,
        border: dark ? Border.all(color: InkColors.c800) : null,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: dark ? InkColors.c800.withValues(alpha: 0.5) : InkColors.c50,
            borderRadius: BorderRadius.circular(AppRadii.xl2),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: _cityField(context, _from,
                      'feed.from_placeholder'.tr(), BrandColors.c600, dark,
                      (v) => setState(() => _from = v))),
              GestureDetector(
                onTap: (_from.isEmpty || _to.isEmpty)
                    ? null
                    : () => setState(() {
                          final t = _from;
                          _from = _to;
                          _to = t;
                        }),
                child: Opacity(
                  opacity: (_from.isEmpty || _to.isEmpty) ? 0.4 : 1,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: dark ? InkColors.c900 : Colors.white,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: dark ? null : AppShadows.xs),
                    child: Icon(Icons.swap_vert,
                        size: 16,
                        color: dark ? InkColors.c300 : InkColors.c500),
                  ),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Container(
                  height: 1, color: dark ? InkColors.c700 : InkColors.c200),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 42),
              child: _cityField(context, _to, 'feed.to_placeholder'.tr(),
                  AccentColors.c500, dark, (v) => setState(() => _to = v)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _rideSegment(dark, driver)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: ready
                ? () => _goResults(_from, _to, _whole, openFilters: true)
                : null,
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: ready ? 1 : 0.4,
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: dark ? InkColors.c800 : InkColors.c100,
                    borderRadius: BorderRadius.circular(AppRadii.xl2)),
                child: Icon(Icons.tune,
                    size: 20,
                    color: driver ? GrapeColors.c600 : BrandColors.c600),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          GestureDetector(
            onTap: () => _pickDate(context),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    dark ? InkColors.c800.withValues(alpha: 0.5) : InkColors.c50,
                borderRadius: BorderRadius.circular(AppRadii.xl2),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.calendar_today,
                    size: 14,
                    color: driver ? GrapeColors.c500 : BrandColors.c500),
                const SizedBox(width: 6),
                Text(_dateLabel(),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : InkColors.c900)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: ready ? () => _goResults(_from, _to, _whole) : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color:
                      ready ? ctaColor : (dark ? InkColors.c800 : InkColors.c200),
                  borderRadius: BorderRadius.circular(AppRadii.xl2),
                  boxShadow: ready
                      ? (driver ? AppShadows.indigoCta : AppShadows.cta)
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.search,
                        size: 20, color: ready ? ctaText : InkColors.c400),
                    const SizedBox(width: 8),
                    Text(
                        (driver ? 'feed.find_passenger' : 'feed.find_trip').tr(),
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: ready ? ctaText : InkColors.c400)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _cityField(BuildContext context, String value, String hint, Color dot,
          bool dark, ValueChanged<String> onPick) =>
      Row(children: [
        Icon(Icons.circle, size: 12, color: dot),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              final c = await showCityPicker(context);
              if (c != null) onPick(c);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 44,
              alignment: Alignment.centerLeft,
              child: Text(value.isEmpty ? hint : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: value.isEmpty
                          ? InkColors.c400
                          : (dark ? Colors.white : InkColors.c900))),
            ),
          ),
        ),
      ]);

  Widget _rideSegment(bool dark, bool driver) {
    final accent = driver ? GrapeColors.c600 : BrandColors.c600;
    final accentDark = driver ? GrapeColors.c300 : BrandColors.c300;
    Widget seg(bool active, IconData icon, String label, VoidCallback onTap) =>
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? (dark ? InkColors.c900 : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: active && !dark ? AppShadows.xs : null,
              ),
              // Auto-shrink the whole icon+label group so long locales
              // (kg «Жолдоштор менен») show in full instead of ellipsizing.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon,
                      size: 16,
                      color: active
                          ? (dark ? accentDark : accent)
                          : InkColors.c400),
                  const SizedBox(width: 6),
                  Text(label,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: active
                              ? (dark ? accentDark : accent)
                              : (dark ? InkColors.c400 : InkColors.c500))),
                ]),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? InkColors.c800 : InkColors.c100,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Row(children: [
        seg(!_whole, Icons.groups_outlined, 'feed.ride_shared'.tr(),
            () => setState(() => _whole = false)),
        const SizedBox(width: 6),
        seg(_whole, Icons.airline_seat_recline_extra_outlined,
            'feed.ride_whole'.tr(), () => setState(() => _whole = true)),
      ]),
    );
  }

  void _goResults(String from, String to, bool whole,
      {bool openFilters = false}) {
    if (from.isEmpty || to.isEmpty) return;
    final driver = ref.read(authProvider).activeMode == ActiveMode.driver;
    final today = ymd(DateTime.now());
    final q = <String, String>{
      'from': from,
      'to': to,
      'mode': driver ? 'requests' : 'trips',
      if (whole) 'seats': '4',
      if (_date.isNotEmpty && _date != today) 'date': _date,
      if (openFilters) 'filters': '1',
    };
    final qs = q.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    context.push('/results?$qs');
  }

  // ── Hub rails: popular · mine · history · destinations(fallback, last) ─────
  Widget _entryHints(bool dark, bool driver, bool authed) {
    final recent = _recentRoutes();
    final hasHistory = recent.isNotEmpty;
    final activeTrips = authed
        ? (ref.watch(myTripsProvider).valueOrNull ?? const <TripCardItem>[])
            .where((t) => t.status == 'active')
            .length
        : 0;
    final activeReqs = authed
        ? (ref.watch(myRequestsProvider).valueOrNull ??
                const <PassengerRequestItem>[])
            .where((r) => r.status == 'open')
            .length
        : 0;
    final hasActive = activeTrips > 0 || activeReqs > 0;
    // «Куда едем/везём» is a filler — only when there's nothing more relevant.
    final showDests = !hasHistory && !hasActive;

    final routes =
        ref.watch(popularRoutesProvider).valueOrNull ?? const <PopularRoute>[];
    final seen = <String>{};
    final dests = <PopularRoute>[];
    for (final r in [...routes]
      ..sort((a, b) => b.tripCount.compareTo(a.tripCount))) {
      if (seen.add(r.to)) dests.add(r);
      if (dests.length >= 8) break;
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (routes.isNotEmpty)
            _rail(
              dark: dark,
              title: 'feed.popular_title'.tr(),
              height: 58,
              children: [
                for (final r in routes) _routeCountChip(r, dark, driver),
              ],
            ),
          if (authed) _mineBlock(dark),
          if (hasHistory)
            _rail(
              dark: dark,
              title: 'feed.search_history'.tr(),
              height: 42,
              action: GestureDetector(
                onTap: () {
                  ref.read(hiveBoxProvider).delete(StorageKeys.recentRoutes);
                  setState(() {});
                },
                behavior: HitTestBehavior.opaque,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.close, size: 14, color: InkColors.c400),
                  const SizedBox(width: 3),
                  Text('feed.clear'.tr(),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: InkColors.c400)),
                ]),
              ),
              children: [
                for (final r in recent) _histChip(r.from, r.to, dark),
              ],
            ),
          if (showDests && dests.isNotEmpty)
            _rail(
              dark: dark,
              title: (driver
                      ? 'feed.destinations_requests'
                      : 'feed.destinations_trips')
                  .tr(),
              height: 58,
              children: [
                for (final r in dests) _destChip(r, dark, driver),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rail({
    required bool dark,
    required String title,
    required double height,
    required List<Widget> children,
    Widget? action,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: dark ? InkColors.c100 : InkColors.c800)),
                  if (action != null) action,
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: children.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => children[i],
              ),
            ),
          ],
        ),
      );

  BoxDecoration _chipCard(bool dark) => BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
        boxShadow: dark ? null : AppShadows.card,
      );

  Widget _destChip(PopularRoute r, bool dark, bool driver) {
    final accent = driver ? GrapeColors.c600 : BrandColors.c600;
    final accentDark = driver ? GrapeColors.c300 : BrandColors.c300;
    String? sub;
    if (!driver && r.tripCount > 0) {
      sub = 'feed.trips_count'.tr(namedArgs: {'n': '${r.tripCount}'});
    } else if (driver && r.minPrice != null) {
      sub = 'feed.from_price'.tr(namedArgs: {'n': '${r.minPrice}'});
    }
    return GestureDetector(
      // Destination-only: fills «Куда» and leaves «Откуда» to the user (their
      // own/geolocated city), instead of forcing a fixed origin.
      onTap: () => setState(() => _to = r.to),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: _chipCard(dark),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.to,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : InkColors.c900)),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(sub,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: dark ? accentDark : accent)),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Icon(Icons.arrow_forward,
              size: 16, color: driver ? GrapeColors.c500 : BrandColors.c500),
        ]),
      ),
    );
  }

  Widget _routeCountChip(PopularRoute r, bool dark, bool driver) {
    final accent = driver ? GrapeColors.c600 : BrandColors.c600;
    final accentDark = driver ? GrapeColors.c300 : BrandColors.c300;
    String sub = '';
    if (!driver && r.tripCount > 0) {
      sub = 'feed.trips_count'.tr(namedArgs: {'n': '${r.tripCount}'});
    } else if (r.minPrice != null) {
      sub = 'feed.from_price'.tr(namedArgs: {'n': '${r.minPrice}'});
    }
    return GestureDetector(
      onTap: () => _applyRoute(r.from, r.to),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: _chipCard(dark),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(r.from,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : InkColors.c900)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child:
                    Icon(Icons.arrow_forward, size: 13, color: InkColors.c400),
              ),
              Text(r.to,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : InkColors.c900)),
            ]),
            if (sub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(sub,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: dark ? accentDark : accent)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _histChip(String from, String to, bool dark) => GestureDetector(
        onTap: () => _applyRoute(from, to),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: dark ? InkColors.c800 : InkColors.c50,
            borderRadius: BorderRadius.circular(AppRadii.xl2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.history, size: 15, color: InkColors.c400),
            const SizedBox(width: 7),
            Text('$from → $to',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: dark ? InkColors.c100 : InkColors.c800)),
          ]),
        ),
      );

  // ── Recent routes (Hive, max 3 · web terme_recent_routes parity) ───────────
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
    final cur = ((box.get(StorageKeys.recentRoutes) as List?) ?? const [])
        .whereType<String>()
        .toList();
    final key = '$from|$to';
    cur.removeWhere((s) => s == key);
    cur.insert(0, key);
    box.put(StorageKeys.recentRoutes, cur.take(3).toList());
  }

  void _applyRoute(String from, String to) {
    _saveRecentRoute(from, to);
    _goResults(from, to, _whole);
  }
}
