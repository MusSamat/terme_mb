import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/trip_card_item.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import '../utils/date_format.dart';
import 'driver_avatar.dart';
import 'verified_badge.dart';

/// Ride card — «Card F» port of tappjet_ft trip-card.tsx.
/// Big departure time · route spine · cities · ♥ price, then a driver strip
/// and a «Подробнее ›» tap hint. Info-only; booking lives on the detail screen.
class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap});

  final TripCardItem trip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final d = trip.driver;
    final dimmed = trip.soldOut || trip.inactive;
    final label = departureLabel(trip.departureAt);
    final windowEnd = trip.departureWindowEnd != null ? '–${hhmm(trip.departureWindowEnd!)}' : '';
    final stops = trip.pickupCities.isNotEmpty ? trip.pickupCities.join(' · ') : null;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.xl3),
            boxShadow: AppShadows.card,
            border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row1(context, dark, label, windowEnd, stops),
              const SizedBox(height: 10),
              Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
              const SizedBox(height: 10),
              _driverStrip(context, dark, d),
              const SizedBox(height: 6),
              _tapHint(dark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row1(BuildContext c, bool dark, ({String date, String time}) label, String windowEnd,
      String? stops) {
    final cityStyle = TextStyle(
      fontFamily: 'Nunito',
      fontWeight: FontWeight.w800,
      fontSize: 15,
      height: 1.1,
      color: dark ? Colors.white : InkColors.c900,
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Departure time hero
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('card.depart_label'.tr().toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: InkColors.c400)),
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: label.time,
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                        height: 1.1,
                        color: dark ? Colors.white : InkColors.c900),
                  ),
                  if (windowEnd.isNotEmpty)
                    TextSpan(
                        text: windowEnd,
                        style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: InkColors.c400)),
                ])),
                Text(label.date,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: InkColors.c400)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Route spine
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: BrandColors.c600, width: 1.5)),
                ),
                Expanded(
                    child: Container(
                        width: 1, color: dark ? InkColors.c700 : InkColors.c200)),
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      const BoxDecoration(shape: BoxShape.circle, color: AccentColors.c500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Cities
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trip.originCity, maxLines: 1, overflow: TextOverflow.ellipsis, style: cityStyle),
                if (stops != null)
                  Text('card.via'.tr(namedArgs: {'stops': stops}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: InkColors.c400)),
                Text(trip.destinationCity,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: cityStyle),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Like + price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _LikeHeart(liked: trip.liked),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(
                        text: _price(trip.pricePerSeat),
                        style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            height: 1,
                            color: dark ? BrandColors.c300 : BrandColors.c700)),
                    TextSpan(
                        text: ' ${'card.som'.tr()}',
                        style: TextStyle(
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: dark ? BrandColors.c300 : BrandColors.c700)),
                  ])),
                  Text('card.per_seat'.tr(),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: InkColors.c400)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _driverStrip(BuildContext c, bool dark, TripDriver d) {
    final showRating = d.rating != null && d.ratingCount >= 3;
    return Row(
      children: [
        DriverAvatar(name: d.name, imageUrl: d.avatarUrl, size: AvatarSize.sm),
        const SizedBox(width: 8),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: dark ? InkColors.c100 : InkColors.c800)),
              ),
              if (d.verified) ...[const SizedBox(width: 4), const VerifiedBadge()],
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (showRating)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star, size: 12, color: AccentColors.c400),
            const SizedBox(width: 2),
            Text(d.rating!.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: InkColors.c400)),
          ])
        else
          Text('card.new'.tr(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: dark ? BrandColors.c300 : BrandColors.c600)),
        if (d.car != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text('· ${d.car!.make} ${d.car!.model}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
          ),
        ],
        const Spacer(),
        if (trip.instant) ...[
          const Icon(Icons.bolt, size: 16, color: AccentColors.c500),
          const SizedBox(width: 6),
        ],
        if (trip.wholeCabin) ...[
          const Icon(Icons.weekend_outlined, size: 16, color: SkyColors.c500),
          const SizedBox(width: 6),
        ],
        _seats(dark),
      ],
    );
  }

  Widget _seats(bool dark) {
    if (trip.soldOut) {
      return Text('card.no_seats'.tr(),
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: InkColors.c400));
    }
    final one = trip.seatsAvailable == 1;
    final color = one ? (dark ? AccentColors.c400 : AccentColors.c600) : (dark ? BrandColors.c300 : BrandColors.c700);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.group, size: 14, color: color),
      const SizedBox(width: 4),
      Text('${trip.seatsAvailable}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
    ]);
  }

  Widget _tapHint(bool dark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('card.details_hint'.tr(),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: InkColors.c400)),
        const Icon(Icons.chevron_right, size: 14, color: InkColors.c400),
      ],
    );
  }

  static String _price(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class _LikeHeart extends StatefulWidget {
  const _LikeHeart({required this.liked});
  final bool liked;

  @override
  State<_LikeHeart> createState() => _LikeHeartState();
}

class _LikeHeartState extends State<_LikeHeart> {
  late bool _liked = widget.liked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _liked = !_liked),
      behavior: HitTestBehavior.opaque,
      child: Icon(
        _liked ? Icons.favorite : Icons.favorite_border,
        size: 20,
        color: _liked ? CoralColors.c500 : CoralColors.c400,
      ),
    );
  }
}
