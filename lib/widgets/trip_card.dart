
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/trip_card_item.dart';
import '../theme/colors.dart';
import '../utils/date_format.dart';
import 'driver_avatar.dart';
import 'ticket.dart';

/// Ride card — ticket redesign. Top half: departure time · route · price.
/// Perforated divider → bottom stub with the driver. Whole card is tappable.
/// No date under the time (it's in the filter bar), no "details" hint row, one
/// trust signal only (rating OR «Новый»).
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap});

  final TripCardItem trip;
  final VoidCallback? onTap;

  static const _tnum = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final d = trip.driver;
    final dimmed = trip.soldOut || trip.inactive;
    final time = hhmm(trip.departureAt);
    final windowEnd = trip.departureWindowEnd != null ? '–${hhmm(trip.departureWindowEnd!)}' : '';
    final stops = trip.pickupCities.isNotEmpty ? trip.pickupCities.join(' · ') : null;

    final ink = dark ? Colors.white : InkColors.c900;
    final muted = dark ? InkColors.c400 : InkColors.c500;
    final price = dark ? BrandColors.c300 : BrandColors.c900;

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: TicketCard(
          dark: dark,
          top: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 60,
                child: Text(time,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.05, color: ink, fontFeatures: _tnum)),
              ),
              const SizedBox(width: 12),
              _spine(dark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(trip.originCity, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.15, color: ink)),
                  if (stops != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('card.via'.tr(namedArgs: {'stops': stops}), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
                    ),
                  const SizedBox(height: 6),
                  Text(trip.destinationCity, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.15, color: ink)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text.rich(TextSpan(children: [
                  TextSpan(text: _fmt(trip.pricePerSeat), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1, color: price, fontFeatures: _tnum)),
                  TextSpan(text: ' ${'card.som'.tr()}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: price)),
                ])),
                const SizedBox(height: 3),
                Text('card.per_seat'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
              ]),
            ],
          ),
          bottom: _stub(dark, d, muted, windowEnd),
        ),
      ),
    );
  }

  Widget _spine(bool dark) => Padding(
        padding: const EdgeInsets.only(top: 2),
        child: SizedBox(
          height: 40,
          child: Column(children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: dark ? BrandColors.c300 : BrandColors.c700, width: 1.5))),
            Expanded(child: Container(width: 1, margin: const EdgeInsets.symmetric(vertical: 3), color: dark ? Colors.white24 : InkColors.c300)),
            Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: AccentColors.c500)),
          ]),
        ),
      );

  Widget _stub(bool dark, TripDriver d, Color muted, String windowEnd) {
    final showRating = d.rating != null && d.ratingCount >= 3;
    final nameColor = dark ? Colors.white : InkColors.c900;
    final car = d.car;
    final carLabel = car == null ? '' : '${car.make} ${car.model}'.trim();
    return Row(children: [
      DriverAvatar(name: d.name, imageUrl: d.avatarUrl, size: AvatarSize.sm),
      const SizedBox(width: 8),
      // Driver name + trust signal on the first line; the full car name gets its
      // own line below so it never truncates to «Nissa…».
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Flexible(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: nameColor))),
              const SizedBox(width: 6),
              if (showRating)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star, size: 12, color: AccentColors.c400),
                  const SizedBox(width: 2),
                  Text(d.rating!.toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted, fontFeatures: _tnum)),
                ])
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: dark ? BrandColors.c900 : BrandColors.c50, borderRadius: BorderRadius.circular(6)),
                  child: Text('card.new'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dark ? BrandColors.c200 : BrandColors.c700)),
                ),
            ]),
            if (carLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(carLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted)),
              ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      if (trip.instant) ...[
        const Icon(Icons.bolt, size: 16, color: AccentColors.c500),
        const SizedBox(width: 6),
      ],
      _seats(dark, muted),
    ]);
  }

  Widget _seats(bool dark, Color muted) {
    if (trip.soldOut) {
      return Text('card.no_seats'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted));
    }
    final last = trip.seatsAvailable == 1;
    final color = last ? AccentColors.c500 : (dark ? BrandColors.c300 : BrandColors.c800);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.group, size: 14, color: color),
      const SizedBox(width: 4),
      Text('${trip.seatsAvailable}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color, fontFeatures: _tnum)),
    ]);
  }

  static String _fmt(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}
