import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/mock_app_data.dart';
import '../../models/trip_card_item.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/query_error.dart';
import '../../widgets/status_badge.dart';
import '../trip/trip_detail_screen.dart' show showTripDetailSheet;

/// Profile → «История поездок». Read-only timeline of everything already behind
/// the user: completed / cancelled / expired passenger bookings AND the driver's
/// own finished trips. Mirrors the web «История» split in my/bookings but lives
/// under the profile so it's reachable from one place.
class ProfileHistoryView extends ConsumerWidget {
  const ProfileHistoryView({super.key, required this.dark});
  final bool dark;

  // Terminal booking states — same set the web my/bookings history tab uses.
  static const _historyBooking = {
    'completed',
    'rejected',
    'cancelled_by_passenger',
    'cancelled_by_driver',
    'cancelled_late',
    'no_show',
    'expired',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(myBookingsProvider);
    final trips = ref.watch(myTripsProvider);

    if (bookings.isLoading || trips.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500)),
      );
    }
    if (bookings.hasError) {
      return QueryError(error: bookings.error!, onRetry: () => ref.invalidate(myBookingsProvider));
    }

    final pastBookings = (bookings.valueOrNull ?? const <MockBooking>[])
        .where((b) => _historyBooking.contains(b.status))
        .toList()
      ..sort((a, b) => (b.departureAt ?? DateTime(0)).compareTo(a.departureAt ?? DateTime(0)));
    final pastTrips = (trips.valueOrNull ?? const <TripCardItem>[])
        .where((t) => t.status == 'completed' || t.status == 'cancelled')
        .toList()
      ..sort((a, b) => b.departureAt.compareTo(a.departureAt));

    if (pastBookings.isEmpty && pastTrips.isEmpty) {
      return _hintCard('profile.history_empty'.tr());
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final b in pastBookings) ...[
        _row(
          context,
          date: b.dateLabel,
          origin: b.origin,
          destination: b.destination,
          status: b.status,
          role: 'profile.history_as_passenger'.tr(),
          onTap: b.tripId != null ? () => showTripDetailSheet(context, b.tripId!) : null,
        ),
        const SizedBox(height: 10),
      ],
      for (final t in pastTrips) ...[
        _row(
          context,
          date: '${t.departureAt.day.toString().padLeft(2, '0')}.${t.departureAt.month.toString().padLeft(2, '0')}',
          origin: t.originCity,
          destination: t.destinationCity,
          status: t.status,
          role: 'profile.history_as_driver'.tr(),
          onTap: () => showTripDetailSheet(context, t.id),
        ),
        const SizedBox(height: 10),
      ],
    ]);
  }

  Widget _row(
    BuildContext context, {
    required String date,
    required String origin,
    required String destination,
    required String status,
    required String role,
    VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl2),
            border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.schedule, size: 14, color: InkColors.c500),
              const SizedBox(width: 6),
              Text(date, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? InkColors.c300 : InkColors.c700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: dark ? InkColors.c800 : InkColors.c100, borderRadius: BorderRadius.circular(999)),
                child: Text(role, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: InkColors.c500)),
              ),
              const Spacer(),
              StatusBadge(status: status),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Flexible(child: Text(origin, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 15, color: InkColors.c500)),
              Flexible(child: Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900))),
            ]),
          ]),
        ),
      );

  Widget _hintCard(String text) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl3),
          boxShadow: AppShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: InkColors.c500))),
        ),
      );
}
