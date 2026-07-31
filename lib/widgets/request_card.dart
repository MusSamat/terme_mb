import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/passenger_request.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import 'driver_avatar.dart';
import 'verified_badge.dart';

/// Passenger request card — grape-accented port of tappjet_ft request-card.
/// «ищет» pill · date · route · seats-needed · passenger strip · budget.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, this.onTap});

  final PassengerRequestItem request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = request;
    final showRating = r.passengerRating != null && r.passengerRatingCount >= 3;

    return GestureDetector(
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: dark ? GrapeColors.c500.withValues(alpha: 0.18) : GrapeColors.c50,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('card.seeking'.tr(),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: dark ? GrapeColors.c300 : GrapeColors.c600)),
                ),
                const Spacer(),
                if (r.responded)
                  Text('card.responded'.tr(),
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, color: BrandColors.c600)),
              ],
            ),
            const SizedBox(height: 8),
            Text(r.dateLabel,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: InkColors.c400)),
            const SizedBox(height: 2),
            Text('${r.originCity} → ${r.destinationCity}',
                style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : InkColors.c900)),
            const SizedBox(height: 12),
            Row(
              children: [
                DriverAvatar(name: r.passengerName, size: AvatarSize.sm, square: true, verified: r.passengerVerified),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(r.passengerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: dark ? InkColors.c100 : InkColors.c800)),
                ),
                if (r.passengerVerified) ...[const SizedBox(width: 4), const VerifiedBadge()],
                const SizedBox(width: 6),
                if (showRating)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star, size: 12, color: AccentColors.c400),
                    const SizedBox(width: 2),
                    Text(r.passengerRating!.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: InkColors.c400)),
                  ])
                else
                  Text('requests.new_passenger'.tr(),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: dark ? GrapeColors.c300 : GrapeColors.c600)),
                const Spacer(),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.group, size: 14, color: InkColors.c400),
                  const SizedBox(width: 4),
                  Text('${r.seatsNeeded}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c500)),
                ]),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('card.needs'.tr(),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700, color: InkColors.c400)),
                const Spacer(),
                Text('${_price(r.budget)} ${'card.som'.tr()}',
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: dark ? GrapeColors.c300 : GrapeColors.c600)),
              ],
            ),
          ],
        ),
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
