import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_app_data.dart';
import '../../data/mock_trips.dart';
import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/trip_card.dart';

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
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        title: Text('my.title'.tr(),
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _Segmented(tabs: tabs, selected: _tab, onSelect: (i) => setState(() => _tab = i)),
          ),
          Expanded(child: _content(driver, dark)),
        ],
      ),
    );
  }

  Widget _content(bool driver, bool dark) {
    // Liked tab (last for both roles).
    final likedTab = driver ? 1 : 2;
    if (_tab == likedTab) {
      final liked = mockTrips().where((t) => t.liked).toList();
      if (liked.isEmpty) {
        return RoleEmptyState(
            icon: Icons.favorite_border, title: 'my.liked_empty_title'.tr(), description: 'my.liked_empty_hint'.tr());
      }
      return ListView.separated(
        padding: _pad,
        itemCount: liked.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => TripCard(trip: liked[i], onTap: () => context.push('/trips/${liked[i].id}')),
      );
    }

    // Driver "my trips" tab → own trips as cards.
    if (driver && _tab == 0) {
      final trips = mockTrips().take(3).toList();
      return ListView.separated(
        padding: _pad,
        itemCount: trips.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => TripCard(trip: trips[i], onTap: () => context.push('/trips/${trips[i].id}')),
      );
    }

    // Passenger "мои заявки" → empty for now.
    if (!driver && _tab == 1) {
      return RoleEmptyState(
        icon: Icons.article_outlined,
        title: 'empty.passenger_requests.title'.tr(),
        description: 'empty.passenger_requests.description'.tr(),
      );
    }

    // Passenger "брони" → booking cards.
    final bookings = mockBookings();
    return ListView.separated(
      padding: _pad,
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _BookingCard(booking: bookings[i]),
    );
  }

  EdgeInsets get _pad => EdgeInsets.fromLTRB(
      16, 8, 16, AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom);
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
                          color: i == selected
                              ? (dark ? Colors.white : InkColors.c900)
                              : InkColors.c400)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final MockBooking booking;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canChat = booking.status == 'accepted' || booking.status == 'completed';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DriverAvatar(name: booking.otherName, verified: booking.verified),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.route,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : InkColors.c900)),
                    Text(booking.dateLabel,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
                  ],
                ),
              ),
              StatusBadge(status: booking.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${'bookings.seats_label'.tr()}: ${booking.seats}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: InkColors.c500)),
              const SizedBox(width: 12),
              Text('${'bookings.sum_label'.tr()}: ${booking.sum} с',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: InkColors.c500)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (canChat)
                Expanded(
                  child: AppButton(
                    label: 'booking_card.chat'.tr(),
                    variant: AppButtonVariant.brand,
                    height: 44,
                    icon: Icons.chat_bubble_outline,
                    onPressed: () => context.push('/my/bookings/${booking.id}/chat'),
                  ),
                ),
              if (canChat && booking.status == 'accepted') const SizedBox(width: 8),
              if (booking.status == 'pending' || booking.status == 'accepted')
                Expanded(
                  child: AppButton(
                    label: 'booking_card.cancel'.tr(),
                    variant: AppButtonVariant.outline,
                    height: 44,
                    onPressed: () {},
                  ),
                ),
              if (booking.status == 'completed')
                Expanded(
                  child: AppButton(
                    label: 'bookings.rate_btn'.tr(),
                    variant: AppButtonVariant.amber,
                    height: 44,
                    onPressed: () => context.push('/trips/t1/rate/d1'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
