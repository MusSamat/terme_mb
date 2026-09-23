import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_app_data.dart';
import '../../models/passenger_request.dart';
import '../../models/pending_rating.dart';
import '../../models/request_response.dart';
import '../../models/trip_card_item.dart';
import '../../api/friendly_error.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/action_modal.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/list_card.dart';
import '../../widgets/request_edit_sheet.dart';
import '../../widgets/query_error.dart';
import '../trip/trip_detail_screen.dart' show showTripDetailSheet;

/// One-format date helpers shared by every «Мои» card (DD.MM · HH:MM).
String _dm(DateTime? d) => d == null
    ? ''
    : '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
String _dmt(DateTime? d) => d == null
    ? ''
    : '${_dm(d)} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Terminal booking statuses — these live under the «История» sub-tab, show no
/// action buttons and never reveal a phone number.
const _terminalBookingStatuses = {
  'completed',
  'rejected',
  'cancelled_by_passenger',
  'cancelled_by_driver',
  'cancelled_late',
  'no_show',
  'expired',
};

/// «Мои» hub — 1:1 port of terme_ft my/bookings page. Title + publish button,
/// segmented tabs (passenger: Брони/Заявки/Избранное · driver: Поездки/Избранное).
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key, this.tab});
  final String? tab;

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

/// The four category chips of the «Мои» hub — mode-independent, one list each.
enum _MyFilter { bookings, trips, requests, liked }

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen> {
  late _MyFilter _filter = _filterFor(widget.tab);
  bool _history =
      false; // Активные ↔ История sub-toggle (not shown on «Избранное»)
  // Dynamic default: with no explicit ?tab, open the tab the user has content in
  // (trips first, then requests, else bookings). True while we're deciding.
  bool _deciding = false;

  /// Maps a deep-link `?tab=` value to a category chip.
  static _MyFilter _filterFor(String? tab) => switch (tab) {
        'trips' => _MyFilter.trips,
        'requests' || 'incoming' || 'my_requests' => _MyFilter.requests,
        'liked' || 'favorites' => _MyFilter.liked,
        _ => _MyFilter.bookings,
      };

  @override
  void initState() {
    super.initState();
    if (widget.tab == null) {
      _deciding = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickDefault());
    }
  }

  Future<void> _pickDefault() async {
    try {
      final tripsF = ref.read(myTripsProvider.future);
      final reqsF = ref.read(myRequestsProvider.future);
      final trips = await tripsF;
      final reqs = await reqsF;
      if (!mounted) return;
      setState(() {
        _filter = trips.isNotEmpty
            ? _MyFilter.trips
            : reqs.isNotEmpty
                ? _MyFilter.requests
                : _MyFilter.bookings;
        _deciding = false;
      });
    } catch (_) {
      if (mounted) setState(() => _deciding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

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
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: dark ? Colors.white : InkColors.c900)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/trips/create'),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                          color: AccentColors.c500,
                          borderRadius: BorderRadius.circular(AppRadii.xl2),
                          boxShadow: AppShadows.cta),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.add,
                            size: 16, color: AccentColors.ink),
                        const SizedBox(width: 6),
                        Text('my.publish'.tr(),
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AccentColors.ink)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            _attentionStrip(dark),
            _filterChips(dark),
            if (_filter != _MyFilter.liked && !_deciding) _activeHistoryToggle(dark),
            Expanded(
              child: _deciding
                  ? const Center(child: CircularProgressIndicator(color: BrandColors.c600))
                  : _content(dark),
            ),
          ],
        ),
      ),
    );
  }

  // ── Attention strip — actionable nudges (what needs YOU), only when present ──
  Widget _attentionStrip(bool dark) {
    final incoming =
        ref.watch(incomingBookingsProvider).valueOrNull ?? const [];
    final pendingRatings =
        ref.watch(pendingRatingsProvider).valueOrNull ?? const [];
    final chips = <Widget>[
      if (incoming.isNotEmpty)
        _attnChip(
            Icons.inbox,
            'my.attn_incoming'.tr(namedArgs: {'n': '${incoming.length}'}),
            BrandColors.c600,
            () => setState(() => _filter = _MyFilter.trips)),
      for (final pr in pendingRatings.take(3))
        _attnChip(
            Icons.star,
            'my.attn_rate'.tr(namedArgs: {'name': pr.counterpartName}),
            AccentColors.c600,
            () => context.push('/trips/${pr.tripId}/rate/${pr.counterpartId}')),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            chips[i]
          ],
        ],
      ),
    );
  }

  Widget _attnChip(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.3))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );

  // ── Filter chips — scrollable, mode-independent (today's best practice) ──────
  Widget _filterChips(bool dark) {
    const items = <(_MyFilter, String, IconData?)>[
      (_MyFilter.bookings, 'my.tab_bookings', null),
      (_MyFilter.trips, 'my.tab_trips', null),
      (_MyFilter.requests, 'my.filter_requests', null),
      (_MyFilter.liked, 'my.tab_liked', Icons.favorite),
    ];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (final (f, key, icon) in items) ...[
            _filterChip(dark, f, key, icon),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(bool dark, _MyFilter f, String key, IconData? icon) {
    final selected = _filter == f;
    // Selected = filled brand pill with a lift; unselected = quiet outline. The
    // strong colour contrast makes the active chip unmistakable.
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: icon != null ? 14 : 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? BrandColors.c600
              : (dark ? InkColors.c900 : Colors.white),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected
                  ? BrandColors.c600
                  : (dark ? InkColors.c800 : InkColors.c200),
              width: selected ? 1.5 : 1),
          boxShadow: selected ? AppShadows.brandCta : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon,
                size: 15,
                color: selected
                    ? Colors.white
                    : (dark ? InkColors.c300 : InkColors.c500)),
            if (icon != Icons.favorite || !selected) const SizedBox(width: 5),
          ],
          if (icon != Icons.favorite)
            Text(key.tr(),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? Colors.white
                        : (dark ? InkColors.c300 : InkColors.c600))),
        ]),
      ),
    );
  }

  // Активные ↔ История segmented toggle — terminal/expired items live under История.
  Widget _activeHistoryToggle(bool dark) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              color: dark ? InkColors.c800 : InkColors.c100,
              borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _segItem('my.sub_active'.tr(), !_history,
                () => setState(() => _history = false), dark),
            _segItem('my.sub_history'.tr(), _history,
                () => setState(() => _history = true), dark),
          ]),
        ),
      );

  Widget _segItem(String label, bool on, VoidCallback onTap, bool dark) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on
                  ? (dark ? InkColors.c950 : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: on ? AppShadows.xs : null,
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: on
                        ? (dark ? Colors.white : InkColors.c900)
                        : InkColors.c400)),
          ),
        ),
      );

  // Owner actions for the driver's own trip (long-press): edit / complete / cancel.
  Future<void> _ownerActions(TripCardItem trip) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final action = await showModalBottomSheet<String>(
      useRootNavigator: true,
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl2)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: BrandColors.c600),
            title: Text('my.trip_edit'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: () => Navigator.pop(ctx, 'edit'),
          ),
          ListTile(
            leading:
                const Icon(Icons.check_circle_outline, color: BrandColors.c600),
            title: Text('my.trip_complete'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w800)),
            onTap: () => Navigator.pop(ctx, 'complete'),
          ),
          ListTile(
            leading: const Icon(Icons.cancel_outlined, color: CoralColors.c600),
            title: Text('my.trip_cancel'.tr(),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: CoralColors.c600)),
            onTap: () => Navigator.pop(ctx, 'cancel'),
          ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'edit') return _editTrip(trip);
    if (action == 'complete') return _completeTrip(trip);
    return _cancelTrip(trip);
  }

  Future<void> _editTrip(TripCardItem trip) async {
    await showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _TripEditSheet(trip: trip), // handles its own save + invalidation
    );
  }

  Future<void> _completeTrip(TripCardItem trip) async {
    try {
      await ref.read(tripsServiceProvider).complete(trip.id);
      ref.invalidate(myTripsProvider);
      if (mounted) Toasts.success('toasts.saved'.tr());
    } catch (e) {
      if (mounted) Toasts.error(friendlyError(e));
    }
  }

  Future<void> _cancelTrip(TripCardItem trip) async {
    final ok = await showConfirmModal(
      context,
      icon: Icons.cancel_outlined,
      title: 'my.trip_cancel'.tr(),
      body: '${trip.originCity} → ${trip.destinationCity}',
      confirmLabel: 'my.trip_cancel'.tr(),
      cancelLabel: 'book_form.cancel'.tr(),
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(tripsServiceProvider).cancel(trip.id);
      ref.invalidate(myTripsProvider);
      if (mounted) Toasts.success('toasts.saved'.tr());
    } catch (e) {
      if (mounted) Toasts.error(friendlyError(e));
    }
  }

  EdgeInsets get _pad => EdgeInsets.fromLTRB(16, 8, 16,
      AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom);

  Map<String, PendingRating> get _pendingByTrip => {
        for (final pr in (ref.watch(pendingRatingsProvider).valueOrNull ??
            const <PendingRating>[]))
          pr.tripId: pr,
      };

  Widget _content(bool dark) => switch (_filter) {
        _MyFilter.trips => _tripsSection(dark),
        _MyFilter.bookings => _bookingsSection(dark),
        _MyFilter.requests => _requestsSection(dark),
        _MyFilter.liked => _likedSection(dark),
      };

  Widget _loading() => const Center(
      child:
          CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500));

  /// Wraps a tab body in a pull-to-refresh that invalidates + awaits [refresh].
  Widget _refreshable(Widget child, Future<void> Function() refresh) =>
      RefreshIndicator(
        color: BrandColors.c500,
        onRefresh: refresh,
        child: child,
      );

  /// Empty-state made refreshable — the centered content sits inside a
  /// full-height scrollable so the drag gesture always registers.
  Widget _refreshableEmpty(Widget empty, Future<void> Function() refresh) =>
      _refreshable(
        LayoutBuilder(
          builder: (_, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [SizedBox(height: constraints.maxHeight, child: empty)],
          ),
        ),
        refresh,
      );

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                color: InkColors.c400)),
      );

  // ── «Поездки» — incoming requests (needs action) on top, then published ──────
  Future<void> _refreshTrips() async {
    ref.invalidate(myTripsProvider);
    ref.invalidate(incomingBookingsProvider);
    await ref.read(myTripsProvider.future);
  }

  Widget _tripsSection(bool dark) {
    final trips = ref.watch(myTripsProvider);
    final incoming = ref.watch(incomingBookingsProvider).valueOrNull ??
        const <MockBooking>[];
    return trips.when(
      loading: _loading,
      error: (e, _) =>
          QueryError(error: e, onRetry: () => ref.invalidate(myTripsProvider)),
      data: (list) {
        // 'direct' = a live trip created from an accepted passenger-request
        // response — it belongs with the active tab, not history.
        final shown = list
            .where((t) => _history
                ? (t.status != 'active' && t.status != 'direct')
                : (t.status == 'active' || t.status == 'direct'))
            .toList();
        final showIncoming = !_history && incoming.isNotEmpty;
        if (shown.isEmpty && !showIncoming) {
          return _refreshableEmpty(
            _history
                ? RoleEmptyState(
                    icon: Icons.history,
                    title: 'my.history_empty_title'.tr(),
                    description: 'my.history_empty_hint'.tr())
                : RoleEmptyState(
                    icon: Icons.directions_car_outlined,
                    title: 'empty.driver_trips.title'.tr(),
                    description: 'empty.driver_trips.description'.tr()),
            _refreshTrips,
          );
        }
        return _refreshable(
          ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: _pad,
            children: [
              if (showIncoming) ...[
                _sectionHeader('my.section_incoming'.tr()),
                for (final b in incoming)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _IncomingCard(booking: b)),
                const SizedBox(height: 4),
                _sectionHeader('my.tab_my_trips'.tr()),
              ],
              for (final t in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _myTripCard(dark, t),
                ),
            ],
          ),
          _refreshTrips,
        );
      },
    );
  }

  // ── Shared card bits ─────────────────────────────────────────────────────
  Widget _iconAvatar(IconData icon, Color color, bool dark) => Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: color.withValues(alpha: dark ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 18, color: color),
      );

  Widget _priceTag(int price) => Text('$price ${'requests.my.som'.tr()}',
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w900, color: SkyColors.c600));

  Widget _sub(String text, {IconData? icon}) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: InkColors.c400),
          const SizedBox(width: 4)
        ],
        Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: InkColors.c500))),
      ]);

  // Driver's own published trip — edit / complete / cancel inline.
  Widget _myTripCard(bool dark, TripCardItem t) {
    final car = t.driver.car;
    final carLabel =
        car != null ? '${car.make} ${car.model}' : 'my.tab_my_trips'.tr();
    return ListCard(
      grape: false,
      when: _dmt(t.departureAt),
      role: 'profile.history_as_driver'.tr(),
      status: t.status,
      origin: t.originCity,
      destination: t.destinationCity,
      avatar: _iconAvatar(Icons.directions_car_filled, BrandColors.c600, dark),
      actorName: carLabel,
      actorSub:
          _sub('${t.seatsAvailable}/${t.seatsTotal}', icon: Icons.event_seat),
      trailing: _priceTag(t.pricePerSeat),
      onTap: () => showTripDetailSheet(context, t.id),
      onLongPress: () => _ownerActions(t),
      actions: t.status == 'active'
          ? [
              ListCardButton(
                  label: 'my.act_edit'.tr(),
                  icon: Icons.edit_outlined,
                  onTap: () => _editTrip(t)),
              ListCardButton(
                  label: 'my.act_complete'.tr(),
                  icon: Icons.check_circle_outline,
                  onTap: () => _completeTrip(t)),
              ListCardButton(
                  label: 'my.act_cancel'.tr(),
                  kind: ListBtnKind.danger,
                  onTap: () => _cancelTrip(t)),
            ]
          : null,
    );
  }

  Future<void> _refreshBookings() async {
    ref.invalidate(myBookingsProvider);
    ref.invalidate(pendingRatingsProvider);
    await ref.read(myBookingsProvider.future);
  }

  Widget _bookingsSection(bool dark) {
    final pending = _pendingByTrip;
    return ref.watch(myBookingsProvider).when(
          loading: _loading,
          error: (e, _) => QueryError(
              error: e, onRetry: () => ref.invalidate(myBookingsProvider)),
          data: (all) {
            final bookings = all
                .where((b) =>
                    _terminalBookingStatuses.contains(b.status) == _history)
                .toList();
            if (bookings.isEmpty) {
              return _refreshableEmpty(
                _history
                    ? RoleEmptyState(
                        icon: Icons.history,
                        title: 'my.history_empty_title'.tr(),
                        description: 'my.history_empty_hint'.tr())
                    : RoleEmptyState(
                        icon: Icons.event_note_outlined,
                        title: 'empty.passenger_bookings.title'.tr(),
                        description:
                            'empty.passenger_bookings.description'.tr()),
                _refreshBookings,
              );
            }
            return _refreshable(
              ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: _pad,
                itemCount: bookings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _BookingCard(
                  booking: bookings[i],
                  pendingRating: bookings[i].tripId != null
                      ? pending[bookings[i].tripId]
                      : null,
                ),
              ),
              _refreshBookings,
            );
          },
        );
  }

  Future<void> _refreshRequests() async {
    ref.invalidate(myRequestsProvider);
    await ref.read(myRequestsProvider.future);
  }

  Widget _requestsSection(bool dark) => ref.watch(myRequestsProvider).when(
        loading: _loading,
        error: (e, _) => QueryError(
            error: e, onRetry: () => ref.invalidate(myRequestsProvider)),
        data: (all) {
          final reqs =
              all.where((r) => (r.status != 'open') == _history).toList();
          if (reqs.isEmpty) {
            return _refreshableEmpty(
              _history
                  ? RoleEmptyState(
                      icon: Icons.history,
                      title: 'my.history_empty_title'.tr(),
                      description: 'my.history_empty_hint'.tr())
                  : RoleEmptyState(
                      icon: Icons.article_outlined,
                      title: 'empty.passenger_requests.title'.tr(),
                      description: 'empty.passenger_requests.description'.tr()),
              _refreshRequests,
            );
          }
          return _refreshable(
            ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: _pad,
              itemCount: reqs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _MyRequestCard(request: reqs[i]),
            ),
            _refreshRequests,
          );
        },
      );

  // ── «Избранное» — liked trips AND liked requests together ────────────────────
  // Expired/closed favourites are NOT hidden — they stay in the list under a
  // grey «Истёк» ribbon so the user sees what they saved even after it timed out.
  Future<void> _refreshLiked() async {
    ref.invalidate(likedTripsProvider);
    ref.invalidate(likedRequestsProvider);
    await ref.read(likedTripsProvider.future);
    await ref.read(likedRequestsProvider.future);
  }

  Widget _likedSection(bool dark) {
    final trips = ref.watch(likedTripsProvider);
    final requests = ref.watch(likedRequestsProvider);
    final now = DateTime.now();
    final items = <Widget>[
      for (final t in trips.valueOrNull ?? const <TripCardItem>[])
        () {
          final expired = t.status != 'active' || t.departureAt.isBefore(now);
          return ListCard(
            grape: false,
            when: _dmt(t.departureAt),
            status: t.status,
            origin: t.originCity,
            destination: t.destinationCity,
            avatar: DriverAvatar(
                name: t.driver.name,
                imageUrl: t.driver.avatarUrl,
                verified: t.driver.verified),
            actorName: t.driver.name,
            actorSub: t.driver.rating != null
                ? _sub('★ ${t.driver.rating!.toStringAsFixed(1)}')
                : null,
            trailing: _priceTag(t.pricePerSeat),
            onTap: () => showTripDetailSheet(context, t.id),
            dimmed: expired,
            ribbon: expired ? 'my.expired'.tr() : null,
          );
        }(),
      for (final r in requests.valueOrNull ?? const <PassengerRequestItem>[])
        () {
          final expired =
              r.status != 'open' || (r.departureDate?.isBefore(now) ?? false);
          return ListCard(
            grape: true,
            when: r.departureDate != null ? _dm(r.departureDate) : r.dateLabel,
            status: r.status,
            origin: r.originCity,
            destination: r.destinationCity,
            avatar: DriverAvatar(
                name: r.passengerName, verified: r.passengerVerified),
            actorName: r.passengerName,
            actorSub: r.passengerRating != null
                ? _sub('★ ${r.passengerRating!.toStringAsFixed(1)}')
                : null,
            trailing: Text('${r.seatsNeeded} ${'booking_card.seats_word'.tr()}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: InkColors.c500)),
            onTap: () => context.push('/requests/${r.id}'),
            dimmed: expired,
            ribbon: expired ? 'my.expired'.tr() : null,
          );
        }(),
    ];
    if (items.isEmpty) {
      if (trips.isLoading || requests.isLoading) return _loading();
      return _refreshableEmpty(
        RoleEmptyState(
            icon: Icons.favorite_border,
            title: 'my.liked_empty_title'.tr(),
            description: 'my.liked_empty_hint'.tr()),
        _refreshLiked,
      );
    }
    return _refreshable(
      ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: _pad,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => items[i],
      ),
      _refreshLiked,
    );
  }
}

/// Booking card — port of booking-card.tsx (passenger view: driver strip).
/// Driver's incoming request card with accept / reject actions.
class _IncomingCard extends ConsumerStatefulWidget {
  const _IncomingCard({required this.booking});
  final MockBooking booking;
  @override
  ConsumerState<_IncomingCard> createState() => _IncomingCardState();
}

class _IncomingCardState extends ConsumerState<_IncomingCard> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() call) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await call();
      ref.invalidate(incomingBookingsProvider);
      ref.invalidate(myTripsProvider);
    } catch (e) {
      if (mounted) Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final b = widget.booking;
    final svc = ref.read(bookingsServiceProvider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
        boxShadow: AppShadows.xs,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          DriverAvatar(name: b.otherName, size: AvatarSize.sm),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.otherName,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : InkColors.c900)),
              Text('${b.origin} → ${b.destination}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: InkColors.c400)),
            ]),
          ),
          Text('${b.seats} ${'booking_card.seats_word'.tr()}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: InkColors.c500)),
        ]),
        if (b.comment != null && b.comment!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(b.comment!,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: InkColors.c500)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _actBtn(
                'booking_card.reject'.tr(),
                CoralColors.c600,
                dark ? InkColors.c800 : Colors.white,
                () => _act(() => svc.reject(b.id))),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _actBtn('booking_card.accept'.tr(), Colors.white,
                BrandColors.c600, () => _act(() => svc.accept(b.id))),
          ),
        ]),
      ]),
    );
  }

  Widget _actBtn(String label, Color fg, Color bg, VoidCallback onTap) =>
      GestureDetector(
        onTap: _busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: _busy ? 0.5 : 1,
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                    color: bg == Colors.white ? InkColors.c200 : bg)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: fg)),
          ),
        ),
      );
}

/// Edit a driver's own trip: price / comment / luggage → PATCH /trips/{id}.
class _TripEditSheet extends ConsumerStatefulWidget {
  const _TripEditSheet({required this.trip});
  final TripCardItem trip;
  @override
  ConsumerState<_TripEditSheet> createState() => _TripEditSheetState();
}

class _TripEditSheetState extends ConsumerState<_TripEditSheet> {
  late final _price =
      TextEditingController(text: '${widget.trip.pricePerSeat}');
  late final _comment = TextEditingController(text: widget.trip.comment ?? '');
  late String _luggage = widget.trip.luggage;
  late int _seatsAvail = widget.trip.seatsAvailable;
  bool _seatsBusy = false;
  bool _loading = false;

  // Remaining seats — immediate ±1 (phone deals happen off-app), like the web
  // owner panel. Separate from the price/comment/luggage save below.
  Future<void> _adjustSeats(int delta) async {
    final next = _seatsAvail + delta;
    if (next < 0 || next > widget.trip.seatsTotal || _seatsBusy) return;
    setState(() => _seatsBusy = true);
    try {
      await ref.read(tripsServiceProvider).adjustSeats(widget.trip.id, delta);
      ref.invalidate(myTripsProvider);
      ref.invalidate(tripDetailProvider(widget.trip.id));
      if (mounted) setState(() { _seatsAvail = next; _seatsBusy = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _seatsBusy = false);
        Toasts.error(friendlyError(e));
      }
    }
  }

  Widget _stepBtn(String s, bool enabled, VoidCallback onTap) =>
      GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: enabled ? GrapeColors.c600 : InkColors.c300,
              borderRadius: BorderRadius.circular(10)),
          child: Text(s,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ),
      );

  static const _luggageOpts = ['yes', 'small', 'no'];
  static String _luggageLabel(String l) => switch (l) {
        'yes' => 'trips.luggage_ok'.tr(),
        'no' => 'trips.luggage_none'.tr(),
        _ => 'trips.luggage_small'.tr(),
      };

  @override
  void dispose() {
    _price.dispose();
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = int.tryParse(_price.text.trim()) ?? 0;
    if (price < 50 || price > 10000) {
      Toasts.error('create.err_price'.tr());
      return;
    }
    if (_loading) return;
    final ok = await showConfirmModal(
      context,
      icon: Icons.edit_outlined,
      title: 'my.trip_edit'.tr(),
      body: 'my.edit_confirm'.tr(),
      confirmLabel: 'profile.save'.tr(),
      cancelLabel: 'book_form.cancel'.tr(),
    );
    if (!ok) return;
    setState(() => _loading = true);
    try {
      await ref.read(tripsServiceProvider).edit(widget.trip.id, {
        'pricePerSeat': price,
        'comment': _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        'luggage': _luggage,
      });
      ref.invalidate(myTripsProvider);
      ref.invalidate(tripDetailProvider(widget.trip.id));
      if (mounted) Navigator.of(context).pop();
      Toasts.success('toasts.saved'.tr());
    } catch (e) {
      Toasts.error(friendlyError(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: InkColors.c400),
          filled: true,
          fillColor: dark ? InkColors.c800 : InkColors.c50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              borderSide: BorderSide(
                  color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              borderSide: BorderSide(
                  color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              borderSide: const BorderSide(color: BrandColors.c500, width: 2)),
        );
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.xl4))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: InkColors.c300,
                          borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 14),
              Text('my.trip_edit'.tr(),
                  style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : InkColors.c900)),
              const SizedBox(height: 14),
              Text('create.price_label_driver'.tr(),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: InkColors.c400)),
              const SizedBox(height: 6),
              TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : InkColors.c900),
                  decoration: deco('0')),
              const SizedBox(height: 12),
              Text('book_form.comment_label'.tr(),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: InkColors.c400)),
              const SizedBox(height: 6),
              TextField(
                  controller: _comment,
                  maxLines: 2,
                  maxLength: 300,
                  style: TextStyle(
                      fontSize: 14,
                      color: dark ? Colors.white : InkColors.c900),
                  decoration: deco('book_form.comment_placeholder'.tr())
                      .copyWith(counterText: '')),
              const SizedBox(height: 8),
              Text('search_filters.luggage_label'.tr(),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: InkColors.c400)),
              const SizedBox(height: 6),
              Row(children: [
                for (final l in _luggageOpts) ...[
                  GestureDetector(
                    onTap: () => setState(() => _luggage = l),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: _luggage == l
                            ? BrandColors.c600
                            : (dark ? InkColors.c800 : InkColors.c50),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: _luggage == l
                                ? BrandColors.c600
                                : (dark ? InkColors.c700 : InkColors.c200)),
                      ),
                      child: Text(_luggageLabel(l),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _luggage == l
                                  ? Colors.white
                                  : (dark ? InkColors.c200 : InkColors.c700))),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ]),
              const SizedBox(height: 12),
              Text('my.trip_seats_left'.tr(),
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: InkColors.c400)),
              const SizedBox(height: 6),
              Row(children: [
                _stepBtn('−', _seatsAvail > 0 && !_seatsBusy,
                    () => _adjustSeats(-1)),
                SizedBox(
                    width: 48,
                    child: Text('$_seatsAvail',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: dark ? Colors.white : InkColors.c900))),
                _stepBtn(
                    '+',
                    _seatsAvail < widget.trip.seatsTotal && !_seatsBusy,
                    () => _adjustSeats(1)),
                const SizedBox(width: 10),
                Text('/ ${widget.trip.seatsTotal}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: InkColors.c400)),
                if (_seatsBusy) ...[
                  const SizedBox(width: 10),
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.2, color: GrapeColors.c500)),
                ],
              ]),
              const SizedBox(height: 16),
              AppButton(
                  label: 'profile.save'.tr(),
                  loading: _loading,
                  onPressed: _save),
            ]),
      ),
    );
  }
}

class _BookingCard extends ConsumerWidget {
  const _BookingCard({required this.booking, this.pendingRating});
  final PendingRating? pendingRating;
  final MockBooking booking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = booking;
    final isHistory = _terminalBookingStatuses.contains(b.status);
    final accepted = b.status == 'accepted';
    // История items are read-only: no chat/cancel/rate buttons, no phone.
    final canChat = !isHistory && (accepted || b.status == 'completed');
    final canCancel = b.status == 'pending' || b.status == 'accepted';

    Future<void> cancel() async {
      final ok = await showConfirmModal(
        context,
        title: 'bookings.cancel_btn'.tr(),
        body: '${b.origin} → ${b.destination}',
        confirmLabel: 'bookings.cancel_btn'.tr(),
        cancelLabel: 'book_form.cancel'.tr(),
        danger: true,
      );
      if (!ok) return;
      try {
        await ref.read(bookingsServiceProvider).cancel(b.id);
        ref.invalidate(myBookingsProvider);
        if (context.mounted) Toasts.success('toasts.booking_cancelled'.tr());
      } catch (e) {
        if (context.mounted) Toasts.error(friendlyError(e));
      }
    }

    final actions = <Widget>[
      if (pendingRating != null)
        ListCardButton(
            label: 'bookings.rate_btn'.tr(),
            icon: Icons.star,
            kind: ListBtnKind.primary,
            onTap: () => context.push(
                '/trips/${pendingRating!.tripId}/rate/${pendingRating!.counterpartId}')),
      if (canChat)
        ListCardButton(
            label: 'booking_card.chat'.tr(),
            icon: Icons.chat_bubble_outline,
            onTap: () => context.push('/my/bookings/${b.id}/chat')),
      if (canCancel)
        ListCardButton(
            label: 'booking_card.cancel'.tr(),
            kind: ListBtnKind.danger,
            onTap: cancel),
    ];

    return ListCard(
      grape: false,
      when: b.departureAt != null ? _dmt(b.departureAt) : b.dateLabel,
      role: 'profile.history_as_passenger'.tr(),
      status: b.status,
      origin: b.origin,
      destination: b.destination,
      avatar: DriverAvatar(name: b.otherName, verified: b.verified),
      actorName: b.otherName,
      // История is read-only — hide the "phone opens after confirmation" hint.
      actorSub: isHistory
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.phone,
            size: 12, color: accepted ? BrandColors.c600 : InkColors.c400),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            accepted && b.phone != null
                ? b.phone!
                : 'booking_card.phone_after_accept'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: accepted ? BrandColors.c700 : InkColors.c400),
          ),
        ),
      ]),
      trailing: Text('${b.seats} ${'booking_card.seats_word'.tr()}',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: InkColors.c500)),
      actions: actions.isEmpty ? null : actions,
    );
  }
}

/// A passenger's own request + an expandable «Предложения водителей» section
/// (driver offers with accept/decline) — 1:1 with the web my-requests-tab.
class _MyRequestCard extends ConsumerStatefulWidget {
  const _MyRequestCard({required this.request});
  final PassengerRequestItem request;
  @override
  ConsumerState<_MyRequestCard> createState() => _MyRequestCardState();
}

class _MyRequestCardState extends ConsumerState<_MyRequestCard> {
  bool _expanded = false;

  Future<void> _openEdit() async {
    await showRequestEditSheet(context, widget.request);
  }

  Future<void> _confirmCancel() async {
    final ok = await showConfirmModal(
      context,
      icon: Icons.cancel_outlined,
      title: 'requests.my.cancel_title'.tr(),
      confirmLabel: 'requests.my.cancel_btn'.tr(),
      cancelLabel: 'book_form.cancel'.tr(),
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(requestsServiceProvider).cancel(widget.request.id);
      Toasts.success('toasts.request_cancelled'.tr());
      ref.invalidate(myRequestsProvider);
    } catch (e) {
      if (mounted) Toasts.error(friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(requestResponsesProvider(widget.request.id));
    final pending = offers.asData?.value.where((r) => r.isPending).length ?? 0;

    final r = widget.request;
    final open = r.status == 'open';
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListCard(
          grape: true,
          when: r.departureDate != null ? _dm(r.departureDate) : r.dateLabel,
          role: 'requests.request_label'.tr(),
          status: r.status,
          origin: r.originCity,
          destination: r.destinationCity,
          avatar: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: GrapeColors.c600.withValues(alpha: dark ? 0.22 : 0.12),
                borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.person, size: 18, color: GrapeColors.c600),
          ),
          actorName: '${r.seatsNeeded} ${'booking_card.seats_word'.tr()}',
          actorSub: (r.comment ?? '').isNotEmpty
              ? Text('«${r.comment!}»',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: InkColors.c500))
              : null,
          trailing: open && pending > 0
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                      color: GrapeColors.c100,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(
                      'requests.my.offers_count'
                          .tr(namedArgs: {'n': '$pending'}),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: GrapeColors.c700)),
                )
              : null,
          onTap: () => context.push('/requests/${r.id}'),
          onLongPress: open ? _confirmCancel : null,
          actions: open
              ? [
                  ListCardButton(
                      label: 'my.act_edit'.tr(),
                      icon: Icons.edit_outlined,
                      grape: true,
                      onTap: _openEdit),
                  ListCardButton(
                      label: 'my.act_cancel'.tr(),
                      kind: ListBtnKind.danger,
                      onTap: _confirmCancel),
                ]
              : null,
        ),
        // Offers expander — only when the request is still open.
        if (open) ...[
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(children: [
                const Icon(Icons.local_offer_outlined,
                    size: 16, color: GrapeColors.c600),
                const SizedBox(width: 6),
                Text('requests.my.offers_title'.tr(),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: GrapeColors.c700)),
                if (pending > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                        color: GrapeColors.c100,
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(
                        'requests.my.offers_count'
                            .tr(namedArgs: {'n': '$pending'}),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: GrapeColors.c700)),
                  ),
                ],
                const Spacer(),
                Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: InkColors.c400),
              ]),
            ),
          ),
          if (_expanded)
            offers.when(
              loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: GrapeColors.c500))),
              error: (e, _) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: QueryError(
                      error: e,
                      onRetry: () => ref.invalidate(
                          requestResponsesProvider(widget.request.id)))),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      child: Text('requests.my.no_offers'.tr(),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: InkColors.c400)))
                  : Column(
                      children: [
                        for (final r in list) ...[
                          const SizedBox(height: 8),
                          _OfferCard(requestId: widget.request.id, response: r),
                        ],
                      ],
                    ),
            ),
        ],
      ],
    );
  }
}

class _OfferCard extends ConsumerStatefulWidget {
  const _OfferCard({required this.requestId, required this.response});
  final String requestId;
  final RequestResponse response;
  @override
  ConsumerState<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends ConsumerState<_OfferCard> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bookingId = await ref
          .read(requestsServiceProvider)
          .acceptResponse(widget.requestId, widget.response.id);
      Toasts.success('toasts.offer_accepted'.tr());
      ref.invalidate(myRequestsProvider);
      ref.invalidate(requestResponsesProvider(widget.requestId));
      ref.invalidate(myBookingsProvider);
      if (mounted && bookingId != null) context.push('/my/bookings/$bookingId/chat');
    } catch (e) {
      if (mounted) Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(requestsServiceProvider)
          .declineResponse(widget.requestId, widget.response.id);
      Toasts.success('toasts.offer_declined'.tr());
      ref.invalidate(requestResponsesProvider(widget.requestId));
    } catch (e) {
      if (mounted) Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _timeLabel() {
    final d = DateTime.tryParse(widget.response.departureTime)?.toLocal();
    if (d == null) return widget.response.departureTime;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.response;
    final declined = r.status == 'declined';
    final accepted = r.status == 'accepted';

    return Opacity(
      opacity: declined ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(
              color: accepted
                  ? BrandColors.c300
                  : (dark ? InkColors.c800 : InkColors.c200)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DriverAvatar(
              name: r.driver.name,
              imageUrl: r.driver.avatarUrl,
              verified: r.driver.verified),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(r.driver.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: dark ? Colors.white : InkColors.c900)),
                ),
                if (r.driver.rating != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.star, size: 12, color: AccentColors.c400),
                  const SizedBox(width: 2),
                  Text(r.driver.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: InkColors.c600)),
                ],
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Text('${r.price} ${'requests.my.som'.tr()}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: SkyColors.c600)),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(_timeLabel(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: InkColors.c500))),
              ]),
              if ((r.message ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('«${r.message!}»',
                    style: const TextStyle(
                        fontSize: 13, height: 1.4, color: InkColors.c600)),
              ],
              if (accepted) ...[
                const SizedBox(height: 4),
                Text('requests.my.accepted'.tr(),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: BrandColors.c600)),
              ] else if (declined) ...[
                const SizedBox(height: 4),
                Text('requests.my.rejected'.tr(),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: InkColors.c400)),
              ],
            ]),
          ),
          if (r.isPending) ...[
            const SizedBox(width: 8),
            _circleBtn(Icons.check, BrandColors.c600, Colors.white,
                _busy ? null : _accept, 'requests.my.accept_aria'.tr()),
            const SizedBox(width: 6),
            _circleBtn(
                Icons.close,
                dark ? InkColors.c900 : Colors.white,
                InkColors.c500,
                _busy ? null : _decline,
                'requests.my.reject_aria'.tr(),
                border: dark ? InkColors.c700 : InkColors.c200),
          ],
        ]),
      ),
    );
  }

  Widget _circleBtn(
      IconData icon, Color bg, Color fg, VoidCallback? onTap, String tooltip,
      {Color? border}) {
    return Semantics(
      label: tooltip,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: border != null ? Border.all(color: border) : null,
            ),
            child: Icon(icon, size: 16, color: fg),
          ),
        ),
      ),
    );
  }
}
