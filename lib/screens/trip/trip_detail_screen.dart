import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/mock_trips.dart';
import '../../models/trip_card_item.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../theme/role_theme.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_button.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/seats_stepper.dart';
import '../../widgets/verified_badge.dart';

class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.id, this.autoBook = false});

  final String id;
  final bool autoBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final role = ref.watch(roleThemeProvider);
    final trip = mockTripById(id);

    if (autoBook) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _showBookingSheet(context, trip);
      });
    }

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                _header(context, role, trip, dark),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverList.list(children: [
                    _MapCard(trip: trip),
                    const SizedBox(height: 14),
                    _InfoTiles(trip: trip),
                    const SizedBox(height: 14),
                    _DriverCard(trip: trip),
                    if (trip.preferences.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _Preferences(trip: trip),
                    ],
                    if ((trip.comment ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _CommentBlock(text: trip.comment!),
                    ],
                    const SizedBox(height: 14),
                    const _TrustRows(),
                  ]),
                ),
              ],
            ),
          ),
          _BottomCta(trip: trip),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, RoleTheme role, TripCardItem trip, bool dark) {
    final label = departureLabel(trip.departureAt);
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: role.headerGradient,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadii.xl4)),
        ),
        padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 4, 8, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _circleBtn(Icons.arrow_back, () => context.canPop() ? context.pop() : context.go('/')),
                const Spacer(),
                _circleBtn(Icons.ios_share, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('detail.share_copied'.tr())));
                }),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${trip.originCity} → ${trip.destinationCity}',
                            style: const TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 24,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('${label.date}, ${label.time}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: _price(trip.pricePerSeat),
                            style: const TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 26,
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        TextSpan(
                            text: ' ${'detail.som_short'.tr()}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withValues(alpha: 0.85))),
                      ])),
                      Text('detail.per_seat'.tr(),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }

  static String _price(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.trip});
  final TripCardItem trip;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final o = kCityCoords[trip.originCity];
    final d = kCityCoords[trip.destinationCity];

    Widget child;
    if (o == null || d == null) {
      child = Container(
        color: dark ? InkColors.c800 : InkColors.c100,
        alignment: Alignment.center,
        child: const Icon(Icons.map_outlined, color: InkColors.c400, size: 32),
      );
    } else {
      final p1 = LatLng(o.lat, o.lng);
      final p2 = LatLng(d.lat, d.lng);
      child = FlutterMap(
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(
            bounds: LatLngBounds(p1, p2),
            padding: const EdgeInsets.all(40),
          ),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'kg.tappjet.tappjet_mb',
          ),
          PolylineLayer(polylines: [
            Polyline(points: [p1, p2], strokeWidth: 3, color: BrandColors.c500),
          ]),
          MarkerLayer(markers: [
            Marker(point: p1, width: 16, height: 16, child: _dot(BrandColors.c600)),
            Marker(point: p2, width: 16, height: 16, child: _dot(AccentColors.c500)),
          ]),
        ],
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.xl3),
      child: SizedBox(height: 170, child: child),
    );
  }

  Widget _dot(Color color) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

class _InfoTiles extends StatelessWidget {
  const _InfoTiles({required this.trip});
  final TripCardItem trip;

  @override
  Widget build(BuildContext context) {
    final label = departureLabel(trip.departureAt);
    final luggage = switch (trip.luggage) {
      'yes' => 'detail.luggage_big'.tr(),
      'no' => 'detail.luggage_none'.tr(),
      _ => 'detail.luggage_small'.tr(),
    };
    return Row(
      children: [
        Expanded(child: _tile(context, Icons.schedule, 'detail.tile_departure'.tr(), label.time)),
        const SizedBox(width: 10),
        Expanded(
            child: _tile(context, Icons.event_seat, 'detail.seats_label'.tr(),
                '${trip.seatsAvailable}/${trip.seatsTotal}')),
        const SizedBox(width: 10),
        Expanded(child: _tile(context, Icons.luggage, 'detail.tile_luggage_title'.tr(), luggage)),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String value) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 20, color: dark ? BrandColors.c300 : BrandColors.c600),
          const SizedBox(height: 6),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, color: InkColors.c400)),
          const SizedBox(height: 2),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : InkColors.c900)),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.trip});
  final TripCardItem trip;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final d = trip.driver;
    final showRating = d.rating != null && d.ratingCount >= 3;
    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              DriverAvatar(name: d.name, imageUrl: d.avatarUrl, size: AvatarSize.lg, verified: d.verified),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: dark ? Colors.white : InkColors.c900)),
                      ),
                      if (d.verified) ...[const SizedBox(width: 6), const VerifiedBadge()],
                    ]),
                    const SizedBox(height: 2),
                    if (showRating)
                      Row(children: [
                        const Icon(Icons.star, size: 14, color: AccentColors.c400),
                        const SizedBox(width: 3),
                        Text(d.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, color: InkColors.c500)),
                        const SizedBox(width: 4),
                        Text('detail.reviews_count'.tr(namedArgs: {'n': '${d.ratingCount}'}),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
                      ])
                    else
                      Text('detail.new_driver'.tr(),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: dark ? BrandColors.c300 : BrandColors.c600)),
                    if (d.car != null) ...[
                      const SizedBox(height: 2),
                      Text('${d.car!.make} ${d.car!.model}${d.car!.plate != null ? ' · ${d.car!.plate}' : ''}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'detail.message_driver'.tr(),
            variant: AppButtonVariant.outline,
            icon: Icons.chat_bubble_outline,
            height: 46,
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _Preferences extends StatelessWidget {
  const _Preferences({required this.trip});
  final TripCardItem trip;

  static const _labels = {
    'clean': 'create.pref_clean',
    'music': 'create.pref_music',
    'no_smoking': 'create.pref_no_smoking',
    'ac': 'create.pref_ac',
    'pets': 'create.pref_pets',
    'quiet': 'create.pref_quiet',
    'chat': 'create.pref_chat',
    'women_only': 'create.pref_women_only',
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = trip.preferences.entries.where((e) => e.value).map((e) => e.key).toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final key in active)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: dark ? InkColors.c800 : InkColors.c100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text((_labels[key] ?? key).tr(),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: dark ? InkColors.c200 : InkColors.c700)),
          ),
      ],
    );
  }
}

class _CommentBlock extends StatelessWidget {
  const _CommentBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _Card(
      child: Text(text,
          style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: dark ? InkColors.c200 : InkColors.c700)),
    );
  }
}

class _TrustRows extends StatelessWidget {
  const _TrustRows();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(Icons.payments_outlined, 'detail.trust_pay'.tr()),
        const SizedBox(height: 8),
        _row(Icons.verified_user_outlined, 'detail.trust_verified'.tr()),
      ],
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: BrandColors.c600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c500)),
        ),
      ],
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.trip});
  final TripCardItem trip;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        border: Border(top: BorderSide(color: dark ? InkColors.c800 : InkColors.c100)),
      ),
      child: AppButton(
        label: trip.soldOut ? 'card.no_seats'.tr() : 'detail.cta_book'.tr(),
        onPressed: trip.soldOut ? null : () => _showBookingSheet(context, trip),
      ),
    );
  }
}

// ── Booking bottom sheet ────────────────────────────────────────────────────

void _showBookingSheet(BuildContext context, TripCardItem trip) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BookingSheet(trip: trip),
  );
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.trip});
  final TripCardItem trip;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  int _seats = 1;
  final _comment = TextEditingController();

  static const _chips = [
    'book_form.chip_bus_station',
    'book_form.chip_small_luggage',
    'book_form.chip_alone',
    'book_form.chip_early',
  ];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final total = widget.trip.pricePerSeat * _seats;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: InkColors.c300, borderRadius: BorderRadius.circular(999))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text('detail.book_modal_title'.tr(),
                      style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: dark ? Colors.white : InkColors.c900)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: InkColors.c400),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('book_form.seats_label'.tr(),
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: dark ? Colors.white : InkColors.c900)),
                            const SizedBox(height: 2),
                            Text('book_form.available'.tr(namedArgs: {'n': '${widget.trip.seatsAvailable}'}),
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
                          ],
                        ),
                        SeatsStepper(
                          value: _seats,
                          max: widget.trip.seatsAvailable.clamp(1, 4),
                          onChanged: (v) => setState(() => _seats = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('book_form.comment_label'.tr(),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : InkColors.c900)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in _chips)
                          GestureDetector(
                            onTap: () {
                              final t = c.tr();
                              final cur = _comment.text;
                              _comment.text = cur.isEmpty ? t : '$cur, $t';
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: dark ? InkColors.c800 : InkColors.c100,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('+ ${c.tr()}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: dark ? InkColors.c200 : InkColors.c700)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _comment,
                      maxLines: 3,
                      maxLength: 300,
                      style: TextStyle(
                          fontSize: 14, color: dark ? Colors.white : InkColors.c900),
                      decoration: InputDecoration(
                        hintText: 'book_form.comment_placeholder'.tr(),
                        hintStyle: const TextStyle(color: InkColors.c400, fontSize: 14),
                        filled: true,
                        fillColor: dark ? InkColors.c800 : InkColors.c50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? BrandColors.c500.withValues(alpha: 0.12) : BrandColors.c50,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('book_form.pay_to_driver'.tr(),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: dark ? BrandColors.c200 : BrandColors.c700)),
                          Text('${TripDetailScreen._price(total)} ${'detail.som_short'.tr()}',
                              style: TextStyle(
                                  fontFamily: 'Fredoka',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: dark ? BrandColors.c200 : BrandColors.c700)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AccentColors.c600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('book_form.warning_hint'.tr(),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: InkColors.c500)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'book_form.submit'.tr(),
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('book_form.request_sent'.tr())),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
