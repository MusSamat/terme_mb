import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_calendar.dart';
import '../../data/mock_requests.dart';
import '../../data/mock_trips.dart';
import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_chip.dart';
import '../../widgets/city_picker.dart';
import '../../widgets/date_picker_modal.dart';
import '../../widgets/filters_sheet.dart';
import '../../widgets/intent_toggle.dart';
import '../../widgets/request_card.dart';
import '../../widgets/trip_card.dart';

/// Home feed — 1:1 port of tappjet_ft feed-header + search-layout / requests-feed.
/// Map band → intent toggle → search card → sticky (filters chip + date stepper)
/// → cards. Passenger shows trips (teal); driver shows requests (grape).
class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  String _from = '';
  String _to = '';
  String _date = ''; // '' = today

  static const _monthsShort = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];

  String get _today => ymd(DateTime.now());
  String get _current => _date.isEmpty ? _today : _date;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final driver = ref.watch(authProvider).activeMode == ActiveMode.driver;
    final accent = driver ? ChipAccent.grape : ChipAccent.brand;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header(context, dark, driver)),
          SliverPersistentHeader(pinned: true, delegate: _StickyBar(child: _controlBar(context, dark, driver, accent))),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom),
            sliver: driver ? _requestList(dark) : _tripList(dark),
          ),
        ],
      ),
    );
  }

  SliverList _tripList(bool dark) {
    final trips = mockTrips();
    return SliverList.separated(
      itemCount: trips.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => TripCard(trip: trips[i], onTap: () => context.push('/trips/${trips[i].id}')),
    );
  }

  SliverList _requestList(bool dark) {
    final reqs = mockRequests();
    return SliverList.separated(
      itemCount: reqs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => RequestCard(request: reqs[i], onTap: () => context.push('/requests/${reqs[i].id}')),
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
                  onChanged: (d) => ref
                      .read(authProvider.notifier)
                      .setActiveMode(d ? ActiveMode.driver : ActiveMode.passenger),
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
    Widget cityField(String value, String hint, Color dot, ValueChanged<String> onPick) => Row(
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
                          color: value.isEmpty ? InkColors.c400 : (dark ? Colors.white : InkColors.c900))),
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
              Expanded(child: Padding(padding: const EdgeInsets.only(left: 8), child: cityField(_from, 'feed.from_placeholder'.tr(), BrandColors.c600, (v) => setState(() => _from = v)))),
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
                        color: dark ? InkColors.c800 : InkColors.c100,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.swap_vert, size: 16, color: dark ? InkColors.c300 : InkColors.c500),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Container(height: 1, color: dark ? InkColors.c700 : InkColors.c200),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 40),
            child: cityField(_to, 'feed.to_placeholder'.tr(), AccentColors.c500, (v) => setState(() => _to = v)),
          ),
        ],
      ),
    );
  }

  // ── Sticky control bar: filters chip + date stepper ────────────────────────
  Widget _controlBar(BuildContext context, bool dark, bool driver, ChipAccent accent) {
    return Container(
      color: (dark ? InkColors.c950 : InkColors.c50).withValues(alpha: 0.92),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            AppChip(
              label: 'feed.filters'.tr(),
              icon: Icons.tune,
              selected: true,
              accent: accent,
              onTap: () => showFiltersSheet(context, accent: accent),
            ),
            const SizedBox(width: 8),
            _dateStepper(context, dark, driver),
          ],
        ),
      ),
    );
  }

  Widget _dateStepper(BuildContext context, bool dark, bool driver) {
    final counts = mockCalendarCounts();
    final current = _current;
    final available = counts.entries.where((e) => e.value > 0 && e.key.compareTo(_today) >= 0).map((e) => e.key).toList()..sort();
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
          onTap: target == null ? null : () => setState(() => _date = target),
          child: Opacity(
            opacity: target == null ? 0.25 : 1,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: dark ? InkColors.c800 : InkColors.c100, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: dark ? InkColors.c300 : InkColors.c700),
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
                      fontSize: 13, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: count > 0
                      ? (driver
                          ? (dark ? GrapeColors.c500.withValues(alpha: 0.15) : GrapeColors.c100)
                          : (dark ? BrandColors.c500.withValues(alpha: 0.15) : BrandColors.c50))
                      : (dark ? InkColors.c800 : InkColors.c100),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: count > 0
                            ? (driver ? (dark ? GrapeColors.c300 : GrapeColors.c600) : (dark ? BrandColors.c300 : BrandColors.c700))
                            : InkColors.c400)),
              ),
            ]),
          ),
          arrow(Icons.chevron_right, next),
          const SizedBox(width: 2),
          GestureDetector(
            onTap: () => showDatePickerModal(
              context,
              value: _date == _today ? '' : _date,
              min: _today,
              dayCounts: counts,
              onChange: (v) => setState(() => _date = v),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: dark ? InkColors.c800 : InkColors.c100, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.calendar_month, size: 20, color: dark ? InkColors.c300 : InkColors.c700),
            ),
          ),
        ],
      ),
    );
  }
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
          canvas.drawCircle(tan.position, 1.6, dash..style = PaintingStyle.fill);
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
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _StickyBar oldDelegate) => true;
}
