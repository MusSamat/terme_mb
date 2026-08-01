import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_app_data.dart';
import '../../data/mock_trips.dart';
import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/action_modal.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/trip_card.dart';
import '../trip/trip_detail_screen.dart' show showTripDetailSheet;

/// «Мои» hub — 1:1 port of tappjet_ft my/bookings page. Title + publish button,
/// segmented tabs (passenger: Брони/Заявки/Избранное · driver: Поездки/Избранное).
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key, this.tab});
  final String? tab;

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final driver = ref.watch(authProvider).activeMode == ActiveMode.driver;
    final tabs = driver
        ? ['my.tab_my_trips'.tr(), 'my.tab_liked'.tr()]
        : ['my.tab_bookings'.tr(), 'my.tab_my_requests'.tr(), 'my.tab_liked'.tr()];
    if (_tab >= tabs.length) _tab = 0;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('my.title'.tr(),
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/trips/create'),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(color: AccentColors.c500, borderRadius: BorderRadius.circular(AppRadii.xl2), boxShadow: AppShadows.cta),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add, size: 16, color: AccentColors.ink),
                        const SizedBox(width: 6),
                        Text('my.publish'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AccentColors.ink)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _Segmented(tabs: tabs, selected: _tab, onSelect: (i) => setState(() => _tab = i)),
            ),
            Expanded(child: _content(driver, dark)),
          ],
        ),
      ),
    );
  }

  Widget _content(bool driver, bool dark) {
    final likedTab = driver ? 1 : 2;
    final pad = EdgeInsets.fromLTRB(16, 8, 16, AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom);

    if (_tab == likedTab) {
      final liked = mockTrips().where((t) => t.liked).toList();
      if (liked.isEmpty) {
        return RoleEmptyState(icon: Icons.favorite_border, title: 'my.liked_empty_title'.tr(), description: 'my.liked_empty_hint'.tr());
      }
      return ListView.separated(
        padding: pad,
        itemCount: liked.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => TripCard(trip: liked[i], onTap: () => showTripDetailSheet(context, liked[i].id)),
      );
    }

    if (driver && _tab == 0) {
      final trips = mockTrips().take(4).toList();
      return ListView.separated(
        padding: pad,
        itemCount: trips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => TripCard(trip: trips[i], onTap: () => showTripDetailSheet(context, trips[i].id)),
      );
    }

    if (!driver && _tab == 1) {
      return RoleEmptyState(
        icon: Icons.article_outlined,
        title: 'empty.passenger_requests.title'.tr(),
        description: 'empty.passenger_requests.description'.tr(),
      );
    }

    final bookings = mockBookings();
    return ListView.separated(
      padding: pad,
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _BookingCard(booking: bookings[i]),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.tabs, required this.selected, required this.onSelect});
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? (dark ? InkColors.c800 : InkColors.c100) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Text(tabs[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: i == selected ? (dark ? Colors.white : InkColors.c900) : InkColors.c400)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Booking card — port of booking-card.tsx (passenger view: driver strip).
class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final MockBooking booking;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final b = booking;
    final accepted = b.status == 'accepted';
    final canChat = accepted || b.status == 'completed';
    final canCancel = b.status == 'pending' || b.status == 'accepted';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.schedule, size: 14, color: InkColors.c500),
                      const SizedBox(width: 6),
                      Text(b.dateLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? InkColors.c300 : InkColors.c700)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Flexible(child: Text(b.origin, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900))),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 16, color: InkColors.c500)),
                      Flexible(child: Text(b.destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(status: b.status),
            ],
          ),
          const SizedBox(height: 12),
          // Driver strip
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: dark ? InkColors.c800 : InkColors.c100))),
            child: Row(
              children: [
                DriverAvatar(name: b.otherName, verified: b.verified),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900)),
                      Row(children: [
                        Icon(Icons.phone, size: 12, color: accepted ? BrandColors.c600 : InkColors.c400),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            accepted && b.phone != null ? b.phone! : 'booking_card.phone_after_accept'.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accepted ? BrandColors.c700 : InkColors.c400),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                Text('${b.seats} ${'booking_card.seats_word'.tr()}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: InkColors.c500)),
              ],
            ),
          ),
          if ((b.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: dark ? InkColors.c800 : InkColors.c50, borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Text('«${b.comment!}»', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: dark ? InkColors.c200 : InkColors.c700)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (canChat)
                _btn(context, 'booking_card.chat'.tr(), Icons.chat_bubble_outline, false, dark, () => context.push('/my/bookings/${b.id}/chat')),
              if (b.status == 'completed') ...[
                const SizedBox(width: 8),
                _btn(context, 'bookings.rate_btn'.tr(), Icons.star_border, true, dark, () => context.push('/trips/t1/rate/d1')),
              ],
              if (canCancel) ...[
                if (canChat) const SizedBox(width: 8),
                _btn(context, 'booking_card.cancel'.tr(), null, false, dark, () async {
                  final ok = await showConfirmModal(
                    context,
                    title: 'bookings.cancel_btn'.tr(),
                    body: '${b.origin} → ${b.destination}',
                    confirmLabel: 'bookings.cancel_btn'.tr(),
                    cancelLabel: 'book_form.cancel'.tr(),
                    danger: true,
                  );
                  if (ok && context.mounted) Toasts.success('toasts.booking_cancelled'.tr());
                }, danger: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(BuildContext context, String label, IconData? icon, bool amber, bool dark, VoidCallback onTap, {bool danger = false}) {
    final bg = amber ? AccentColors.c500 : (dark ? InkColors.c800 : Colors.white);
    final fg = amber ? AccentColors.ink : (danger ? CoralColors.c600 : (dark ? InkColors.c100 : InkColors.c800));
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: amber ? null : Border.all(color: danger ? CoralColors.c200 : (dark ? InkColors.c700 : InkColors.c200)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg)),
          ]),
        ),
      ),
    );
  }
}
