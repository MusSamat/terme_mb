import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../widgets/query_error.dart';

// Bookings that represent an ACTUAL arranged ride — the only ones kept in trip
// history (inDrive-style). Never-confirmed states (pending / viewed / rejected /
// expired) never became a trip, so they're not history. An 'accepted' booking
// whose time has passed is treated as completed.
const _rideBooking = {
  'completed',
  'no_show',
  'cancelled_by_passenger',
  'cancelled_by_driver',
  'cancelled_late',
};

enum _HistTab { bookings, trips }

/// История поездок — reached from Profile. Shows only trips that actually
/// happened: bookings taken as a passenger, and trips published as a driver.
/// Unfulfilled requests and never-confirmed bookings are not listed.
class TripHistoryScreen extends ConsumerStatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  ConsumerState<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends ConsumerState<TripHistoryScreen> {
  _HistTab _tab = _HistTab.bookings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkColors.c50,
      appBar: AppBar(
        backgroundColor: InkColors.c50,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: InkColors.c900),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('profile.tab_history'.tr(),
            style: const TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.w800, color: InkColors.c900)),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              _chip('my.tab_bookings'.tr(), _HistTab.bookings),
              const SizedBox(width: 8),
              _chip('my.tab_trips'.tr(), _HistTab.trips),
            ]),
          ),
          Expanded(child: _tab == _HistTab.bookings ? _bookings() : _trips()),
        ]),
      ),
    );
  }

  Widget _chip(String label, _HistTab tab) {
    final on = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? BrandColors.c600 : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: on ? null : Border.all(color: InkColors.c200),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: on ? Colors.white : InkColors.c600)),
      ),
    );
  }

  // ── plain-text row: route + "date · status · role" ──────────────────────────
  Widget _row({required String from, required String to, required String date, required String status, String? role}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$from → $to',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: InkColors.c900)),
          const SizedBox(height: 3),
          Text([date, 'status.$status'.tr(), if (role != null) role].join(' · '),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: InkColors.c500)),
        ]),
      );

  Widget _list(List<Widget> rows) => rows.isEmpty
      ? _empty()
      : ListView.separated(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, color: InkColors.c200),
          itemBuilder: (_, i) => rows[i],
        );

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('profile.history_empty_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: InkColors.c500)),
        ),
      );

  Widget _loading() => const Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500));

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  Widget _bookings() {
    final now = DateTime.now();
    return ref.watch(myBookingsProvider).when(
          loading: _loading,
          error: (e, _) => QueryError(error: e, onRetry: () => ref.invalidate(myBookingsProvider)),
          data: (all) {
            // Real rides only: a confirmed/completed booking, or one that was
            // accepted and whose time has passed. Drops rejected/expired/pending.
            final past = all
                .where((b) =>
                    _rideBooking.contains(b.status) ||
                    (b.status == 'accepted' && (b.departureAt?.isBefore(now) ?? false)))
                .toList()
              ..sort((a, b) => (b.departureAt ?? DateTime(0)).compareTo(a.departureAt ?? DateTime(0)));
            return _list([
              for (final b in past)
                _row(
                  from: b.origin,
                  to: b.destination,
                  date: b.dateLabel,
                  status: _rideBooking.contains(b.status) ? b.status : 'completed',
                  role: 'profile.history_as_passenger'.tr(),
                ),
            ]);
          },
        );
  }

  Widget _trips() {
    final now = DateTime.now();
    return ref.watch(myTripsProvider).when(
          loading: _loading,
          error: (e, _) => QueryError(error: e, onRetry: () => ref.invalidate(myTripsProvider)),
          data: (all) {
            // A driver's past trips: completed or cancelled (an 'active'/'direct'
            // trip whose time has passed reads as completed).
            final past = all
                .where((t) => !((t.status == 'active' || t.status == 'direct') && t.departureAt.isAfter(now)))
                .toList()
              ..sort((a, b) => b.departureAt.compareTo(a.departureAt));
            return _list([
              for (final t in past)
                _row(
                  from: t.originCity,
                  to: t.destinationCity,
                  date: _d(t.departureAt),
                  status: (t.status == 'active' || t.status == 'direct') ? 'completed' : t.status,
                  role: 'profile.history_as_driver'.tr(),
                ),
            ]);
          },
        );
  }
}
