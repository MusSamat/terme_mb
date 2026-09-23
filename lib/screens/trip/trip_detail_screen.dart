import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../widgets/query_error.dart';
import '../../models/trip_card_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/listing_metrics.dart';
import '../../widgets/verified_badge.dart';

/// Resolves the current viewer role (guest/passenger/driver) from auth.
String _roleOf(WidgetRef ref) {
  final auth = ref.read(authProvider);
  if (!auth.isAuthenticated) return 'guest';
  return auth.activeMode == ActiveMode.driver ? 'driver' : 'passenger';
}

/// Opens the trip detail as a bottom sheet — the feed's «Подробнее» behavior
/// (terme_ft `TripDetailView variant="rail"`). CTA sits at the end of scroll.
void showTripDetailSheet(BuildContext context, String id) {
  showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final dark = Theme.of(ctx).brightness == Brightness.dark;
        final role = _roleOf(ref);
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
          decoration: BoxDecoration(
            color: dark ? InkColors.c950 : InkColors.c50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ref.watch(tripDetailProvider(id)).when(
                loading: () => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500))),
                error: (e, _) => SizedBox(height: 240, child: QueryError(error: e, onRetry: () => ref.invalidate(tripDetailProvider(id)))),
                data: (trip) => SingleChildScrollView(
                  child: Column(
                    children: [
                      tripHeader(ctx, trip, onClose: () => Navigator.of(ctx).pop(), isOwner: ref.read(authProvider).user?.id == trip.driver.id),
                      tripBody(ctx, trip),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.of(ctx).padding.bottom),
                        child: tripCta(ctx, trip, role, isOwner: ref.read(authProvider).user?.id == trip.driver.id),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    ),
  );
}

/// Full-page trip detail — kept for deep links (`/trips/:id`).
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.id, this.autoBook = false});

  final String id;
  final bool autoBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final role = _roleOf(ref);

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: ref.watch(tripDetailProvider(id)).when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500)),
            error: (e, _) => Center(child: QueryError(error: e, onRetry: () => ref.invalidate(tripDetailProvider(id)))),
            data: (trip) {
              final isOwner = ref.read(authProvider).user?.id == trip.driver.id;
              if (autoBook && !isOwner) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted && role == 'passenger') showBookingSheet(context, trip);
                });
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        tripHeader(context, trip, onBack: () => context.canPop() ? context.pop() : context.go('/'), isOwner: isOwner),
                        tripBody(context, trip),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
                    decoration: BoxDecoration(
                      color: dark ? InkColors.c900 : Colors.white,
                      border: Border(top: BorderSide(color: dark ? InkColors.c800 : InkColors.c200)),
                    ),
                    child: tripCta(context, trip, role, isOwner: isOwner),
                  ),
                ],
              );
            },
          ),
    );
  }
}

// ── Shared pieces (used by both the page and the sheet) ──────────────────────

/// Teal gradient header: back/close, share, like, route spine + price.
Widget tripHeader(BuildContext context, TripCardItem trip, {VoidCallback? onBack, VoidCallback? onClose, bool isOwner = false}) {
  final stops = trip.pickupCities.isNotEmpty ? trip.pickupCities.join(' · ') : null;

  Widget circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
      );

  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [BrandColors.c600, BrandColors.c500]),
    ),
    padding: EdgeInsets.fromLTRB(20, (onBack != null ? MediaQuery.of(context).padding.top : 8) + 12, 20, 24),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (onBack != null) circleBtn(Icons.arrow_back, onBack) else const SizedBox(width: 36),
            Row(children: [
              circleBtn(Icons.ios_share, () => Toasts.info('detail.share_copied'.tr())),
              // Owner can't like their own listing (backend own_listing); a
              // finished/cancelled trip is read-only so its like is hidden too.
              if (!isOwner && !trip.inactive) ...[const SizedBox(width: 8), _LikeCircle(id: trip.id, liked: trip.liked)],
              if (onClose != null) ...[const SizedBox(width: 8), circleBtn(Icons.close, onClose)],
            ]),
          ],
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _HeaderSpine(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(trip.originCity, style: const TextStyle(fontSize: 20, height: 1.1, fontWeight: FontWeight.w900, color: Colors.white)),
                    if (stops != null)
                      Text(stops, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
                    Text(trip.destinationCity, style: const TextStyle(fontSize: 20, height: 1.1, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: _price(trip.pricePerSeat), style: const TextStyle(fontSize: 24, height: 1, fontWeight: FontWeight.w900, color: Colors.white)),
                    TextSpan(text: ' ${'detail.som_short'.tr()}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  ])),
                  const SizedBox(height: 4),
                  Text('detail.per_seat'.tr(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Driver card + info tiles + comment.
Widget tripBody(BuildContext context, TripCardItem trip) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final d = trip.driver;
  final showRating = d.rating != null && d.ratingCount >= 3;
  final meta = [
    showRating ? '★${d.rating!.toStringAsFixed(1)}' : 'detail.new_driver'.tr(),
    if (showRating) 'detail.reviews_count'.tr(namedArgs: {'n': '${d.ratingCount}'}),
    if (d.car != null) '${d.car!.make} ${d.car!.model}',
  ].join(' · ');
  final label = departureLabel(trip.departureAt);
  final luggage = switch (trip.luggage) {
    'yes' => 'detail.luggage_big'.tr(),
    'no' => 'detail.luggage_none'.tr(),
    _ => 'detail.luggage_small'.tr(),
  };

  Widget tile(IconData icon, String value, String sub) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(color: dark ? InkColors.c800 : InkColors.c50, borderRadius: BorderRadius.circular(AppRadii.xl2)),
          child: Column(children: [
            Icon(icon, size: 16, color: dark ? BrandColors.c300 : BrandColors.c600),
            const SizedBox(height: 4),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400)),
          ]),
        ),
      );

  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    child: Column(
      children: [
        // Creator-only engagement counters (views · likes · calls).
        if (trip.metrics != null) ...[
          Align(alignment: Alignment.centerLeft, child: ListingMetricsRow(metrics: trip.metrics)),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: dark ? InkColors.c800 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl2),
            border: Border.all(color: dark ? InkColors.c700 : InkColors.c100),
            boxShadow: AppShadows.xs,
          ),
          child: Row(children: [
            DriverAvatar(name: d.name, imageUrl: d.avatarUrl, size: AvatarSize.lg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900))),
                    if (d.verified) ...[const SizedBox(width: 4), const VerifiedBadge()],
                  ]),
                  Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c400)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          tile(
              Icons.calendar_today,
              trip.departureWindowEnd != null
                  ? '${label.date}, ${label.time}–${hhmm(trip.departureWindowEnd!)}'
                  : '${label.date}, ${label.time}',
              'detail.tile_departure'.tr()),
          const SizedBox(width: 10),
          tile(Icons.group, 'detail.tile_seats_value'.tr(namedArgs: {'n': '${trip.seatsAvailable}'}), 'detail.tile_seats_sub'.tr()),
          const SizedBox(width: 10),
          tile(Icons.work_outline, 'detail.tile_luggage_title'.tr(), luggage),
        ]),
        if ((trip.comment ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: dark ? AccentColors.c500.withValues(alpha: 0.1) : AccentColors.c50, borderRadius: BorderRadius.circular(AppRadii.xl2)),
            child: Text(trip.comment!, style: TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w600, color: dark ? AccentColors.c200 : InkColors.c700)),
          ),
        ],
      ],
    ),
  );
}

/// Role-aware CTA + contact reveal.
Widget tripCta(BuildContext context, TripCardItem trip, String role, {bool isOwner = false}) {
  // Own trip: the passenger-mode viewer must NOT see «book» / «reveal contact»
  // (both 400 on the backend — cannot_book_own_trip / own_listing). Show the
  // driver CTA («create similar») instead, exactly like the web mini-app.
  if (isOwner) role = 'driver';
  // Completed / cancelled trip → read-only: no «book», no contact reveal, no phone.
  if (trip.inactive && role != 'driver' && role != 'guest') {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 50,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: dark ? InkColors.c800 : InkColors.c100, borderRadius: BorderRadius.circular(AppRadii.lg)),
      child: Text('detail.trip_unavailable'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: InkColors.c500)),
    );
  }
  late final Color bg;
  late final Color fg;
  late final IconData icon;
  late final String label;
  late final VoidCallback onTap;
  List<BoxShadow> shadow = const [];

  if (role == 'driver') {
    bg = BrandColors.c600;
    fg = Colors.white;
    icon = Icons.directions_car_filled;
    label = 'detail.cta_create_similar'.tr();
    shadow = AppShadows.brandCta;
    onTap = () => context.push('/trips/create');
  } else if (role == 'guest') {
    bg = InkColors.c700;
    fg = Colors.white;
    icon = Icons.lock_outline;
    label = 'detail.cta_signin'.tr();
    onTap = () => context.push('/auth/login');
  } else {
    bg = AccentColors.c500;
    fg = AccentColors.ink;
    icon = Icons.check_circle;
    label = 'detail.cta_book'.tr();
    shadow = AppShadows.cta;
    onTap = () => showBookingSheet(context, trip);
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 50,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.lg), boxShadow: shadow),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
          ]),
        ),
      ),
      if (role != 'driver') ...[
        const SizedBox(height: 8),
        Consumer(builder: (ctx, ref, _) => _ContactReveal(onReveal: () => ref.read(tripsServiceProvider).revealContact(trip.id))),
      ],
    ],
  );
}

String _price(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

class _HeaderSpine extends StatelessWidget {
  const _HeaderSpine();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      child: Column(children: [
        const SizedBox(height: 4),
        Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
        Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: Colors.white.withValues(alpha: 0.5))),
        Container(width: 14, height: 14, decoration: const BoxDecoration(shape: BoxShape.circle, color: AccentColors.c400)),
      ]),
    );
  }
}

class _LikeCircle extends ConsumerStatefulWidget {
  const _LikeCircle({required this.id, required this.liked});
  final String id;
  final bool liked;
  @override
  ConsumerState<_LikeCircle> createState() => _LikeCircleState();
}

class _LikeCircleState extends ConsumerState<_LikeCircle> {
  late bool _liked = widget.liked;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    final next = !_liked;
    setState(() { _liked = next; _busy = true; }); // optimistic
    try {
      final svc = ref.read(tripsServiceProvider);
      next ? await svc.like(widget.id) : await svc.unlike(widget.id);
    } catch (e) {
      if (mounted) setState(() => _liked = !next); // revert
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
        child: Icon(_liked ? Icons.favorite : Icons.favorite_border, size: 18, color: _liked ? CoralColors.c400 : Colors.white),
      ),
    );
  }
}

/// Reveal-contact button — calls the audited reveal endpoint on tap and shows
/// the real phone (tap again to dial). Used for both trips and requests.
class _ContactReveal extends StatefulWidget {
  const _ContactReveal({required this.onReveal});
  final Future<String?> Function() onReveal;
  @override
  State<_ContactReveal> createState() => _ContactRevealState();
}

class _ContactRevealState extends State<_ContactReveal> {
  String? _phone;
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    if (_phone != null) {
      await launchUrl(Uri.parse('tel:$_phone'));
      return;
    }
    setState(() => _busy = true);
    try {
      final p = await widget.onReveal();
      if (mounted) setState(() => _phone = p);
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final revealed = _phone != null;
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: dark ? BrandColors.c500.withValues(alpha: 0.4) : BrandColors.c200),
        ),
        child: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: BrandColors.c500))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(revealed ? Icons.call : Icons.phone_outlined, size: 18, color: dark ? BrandColors.c300 : BrandColors.c600),
                const SizedBox(width: 8),
                Text(revealed ? _phone! : 'contact.call'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? BrandColors.c300 : BrandColors.c700)),
              ]),
      ),
    );
  }
}

// ── Booking sheet (port of book-form) ────────────────────────────────────────

void showBookingSheet(BuildContext context, TripCardItem trip) {
  showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BookingSheet(trip: trip),
  );
}

class _BookingSheet extends ConsumerStatefulWidget {
  const _BookingSheet({required this.trip});
  final TripCardItem trip;
  @override
  ConsumerState<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends ConsumerState<_BookingSheet> {
  int _seats = 1;
  bool _sent = false;
  bool _loading = false;
  String? _bookingId; // real id of the created booking (for the chat link)
  final _comment = TextEditingController();

  static const _chips = ['book_form.chip_bus_station', 'book_form.chip_small_luggage', 'book_form.chip_alone', 'book_form.chip_early'];

  int get _max => widget.trip.seatsAvailable.clamp(1, 4);

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    // Backend rejects booking a sold-out trip (SEATS_NOT_AVAILABLE) — guard here.
    if (widget.trip.soldOut) {
      Toasts.error('book_form.err_sold_out'.tr());
      return;
    }
    setState(() => _loading = true);
    try {
      final comment = _comment.text.trim();
      final id = await ref.read(bookingsServiceProvider).create(
            tripId: widget.trip.id,
            seats: _seats,
            comment: comment.isEmpty ? null : comment,
          );
      // Refresh the seat count on the trip, the passenger's bookings, and the
      // feed behind the sheet.
      ref.invalidate(tripDetailProvider(widget.trip.id));
      ref.invalidate(myBookingsProvider);
      ref.invalidate(tripsFeedProvider);
      if (mounted) setState(() { _sent = true; _bookingId = id; });
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999))),
            Flexible(child: _sent ? _waiting(dark) : _form(dark)),
          ],
        ),
      ),
    );
  }

  Widget _form(bool dark) {
    final total = widget.trip.pricePerSeat * _seats;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('detail.book_modal_title'.tr(), style: TextStyle(fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.of(context).pop(), child: const Icon(Icons.close, color: InkColors.c400)),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.xl2), border: Border.all(color: dark ? InkColors.c800 : InkColors.c200)),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.group, size: 18, color: InkColors.c400),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('book_form.seats_label'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900)),
                    Text('book_form.available'.tr(namedArgs: {'n': '${widget.trip.seatsAvailable}'}), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400)),
                  ])),
                  _stepBtn('−', _seats > 1, () => setState(() => _seats--)),
                  SizedBox(width: 30, child: Text('$_seats', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900))),
                  _stepBtn('+', _seats < _max, () => setState(() => _seats++)),
                ]),
              ),
              Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet, size: 18, color: BrandColors.c500),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('book_form.pay_to_driver'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900)),
                    Text('${widget.trip.pricePerSeat} ${'detail.som_short'.tr()} × $_seats', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400)),
                  ])),
                  Text('${_price(total)} ${'detail.som_short'.tr()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: BrandColors.c700)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.chat_bubble_outline, size: 14, color: InkColors.c400),
            const SizedBox(width: 6),
            Text('book_form.comment_label'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: InkColors.c500)),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in _chips)
              GestureDetector(
                onTap: () {
                  final t = c.tr();
                  _comment.text = _comment.text.isEmpty ? t : '${_comment.text}, ${t.toLowerCase()}';
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: dark ? InkColors.c800 : InkColors.c50, borderRadius: BorderRadius.circular(999), border: Border.all(color: dark ? InkColors.c700 : InkColors.c200)),
                  child: Text(c.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dark ? InkColors.c300 : InkColors.c600)),
                ),
              ),
          ]),
          const SizedBox(height: 8),
          TextField(
            controller: _comment,
            maxLines: 2,
            maxLength: 300,
            style: TextStyle(fontSize: 14, color: dark ? Colors.white : InkColors.c900),
            decoration: InputDecoration(
              hintText: 'book_form.comment_placeholder'.tr(),
              hintStyle: const TextStyle(color: InkColors.c400),
              filled: true,
              fillColor: dark ? InkColors.c800 : InkColors.c50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200)),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: dark ? AccentColors.c500.withValues(alpha: 0.1) : AccentColors.c50, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: dark ? AccentColors.c500.withValues(alpha: 0.2) : AccentColors.c100)),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, size: 16, color: AccentColors.c600),
              const SizedBox(width: 8),
              Expanded(child: Text('book_form.warning_hint'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AccentColors.c700))),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Container(height: 50, alignment: Alignment.center, child: Text('book_form.cancel'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: InkColors.c500))),
              ),
            ),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: _loading ? null : _submit,
                behavior: HitTestBehavior.opaque,
                child: Opacity(
                  opacity: _loading ? 0.6 : 1,
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AccentColors.c500, borderRadius: BorderRadius.circular(AppRadii.lg), boxShadow: AppShadows.cta),
                    child: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AccentColors.ink))
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.send, size: 18, color: AccentColors.ink),
                            const SizedBox(width: 8),
                            Text('book_form.submit'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AccentColors.ink)),
                          ]),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _stepBtn(String label, bool enabled, VoidCallback onTap) => Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          behavior: HitTestBehavior.opaque,
          child: Container(width: 32, height: 32, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: InkColors.c300)), child: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        ),
      );

  Widget _waiting(bool dark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(children: [
        Container(width: 80, height: 80, alignment: Alignment.center, decoration: BoxDecoration(color: dark ? AccentColors.c500.withValues(alpha: 0.15) : AccentColors.c50, shape: BoxShape.circle), child: const Icon(Icons.schedule, size: 36, color: AccentColors.c500)),
        const SizedBox(height: 16),
        Text('book_form.request_sent'.tr(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
        const SizedBox(height: 8),
        Text('book_form.waiting_hint'.tr(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600, color: InkColors.c400)),
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: 0.4, minHeight: 4, backgroundColor: dark ? InkColors.c800 : InkColors.c100, valueColor: const AlwaysStoppedAnimation(AccentColors.c500))),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: dark ? BrandColors.c500.withValues(alpha: 0.1) : BrandColors.c50, borderRadius: BorderRadius.circular(AppRadii.xl2), border: Border.all(color: dark ? BrandColors.c500.withValues(alpha: 0.2) : BrandColors.c100)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.chat_bubble_outline, size: 14, color: dark ? BrandColors.c300 : BrandColors.c700),
              const SizedBox(width: 6),
              Text('book_form.chat_title'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? BrandColors.c200 : BrandColors.c800)),
            ]),
            const SizedBox(height: 4),
            Text('book_form.chat_hint'.tr(), style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: dark ? BrandColors.c300 : BrandColors.c700)),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                context.push('/my/bookings');
              },
              behavior: HitTestBehavior.opaque,
              child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: dark ? InkColors.c700 : InkColors.c200)), child: Text('book_form.my_trips'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c800))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                // Real booking id — not a hardcoded "b1". If unknown, fall back
                // to the bookings list.
                context.push(_bookingId != null ? '/my/bookings/$_bookingId/chat' : '/my/bookings');
              },
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: BrandColors.c600, borderRadius: BorderRadius.circular(AppRadii.lg)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('book_form.open_chat'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}
