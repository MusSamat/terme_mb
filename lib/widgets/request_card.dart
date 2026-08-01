import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/passenger_request.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import 'driver_avatar.dart';

/// Passenger request card — 1:1 port of request-card.tsx.
/// Type pill · date hero (grape CalendarClock) · thin route · seats-needed +
/// heart · passenger strip + chevron. No budget row (matches ref).
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, this.onTap});

  final PassengerRequestItem request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = request;
    final showRating = r.passengerRating != null && r.passengerRatingCount >= 3;
    final firstName = r.passengerName.split(' ').first;

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
            // Type pill
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: dark ? GrapeColors.c500.withValues(alpha: 0.2) : GrapeColors.c100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.back_hand, size: 12, color: dark ? GrapeColors.c300 : GrapeColors.c600),
                  const SizedBox(width: 4),
                  Text('card.type_passenger'.tr().toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.3, color: dark ? GrapeColors.c300 : GrapeColors.c600)),
                ]),
              ),
              if (r.responded) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: BrandColors.c100, borderRadius: BorderRadius.circular(999)),
                  child: Text('card.responded'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: BrandColors.c700)),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            // Row 1 — date hero + route (left), seats-needed + heart (right)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.event, size: 16, color: dark ? GrapeColors.c400 : GrapeColors.c500),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(r.dateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 17, height: 1.1, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text('${r.originCity} → ${r.destinationCity}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c500)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('card.needs'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: InkColors.c400)),
                    Text('${r.seatsNeeded}', style: TextStyle(fontSize: 18, height: 1, fontWeight: FontWeight.w900, color: dark ? GrapeColors.c300 : GrapeColors.c600)),
                  ],
                ),
                const SizedBox(width: 8),
                _LikeHeart(liked: r.liked),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
            const SizedBox(height: 10),
            // Row 2 — passenger strip
            Row(children: [
              DriverAvatar(name: r.passengerName, size: AvatarSize.md, square: true, verified: r.passengerVerified),
              const SizedBox(width: 8),
              Flexible(
                child: Text(firstName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
              ),
              const SizedBox(width: 6),
              if (showRating)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star, size: 12, color: AccentColors.c400),
                  const SizedBox(width: 2),
                  Text(r.passengerRating!.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: InkColors.c500)),
                ])
              else
                Text('card.new'.tr(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: dark ? GrapeColors.c300 : GrapeColors.c600)),
              const Spacer(),
              const Icon(Icons.chevron_right, size: 18, color: GrapeColors.c400),
            ]),
          ],
        ),
      ),
    );
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
      child: Icon(_liked ? Icons.favorite : Icons.favorite_border, size: 20, color: _liked ? CoralColors.c500 : CoralColors.c400),
    );
  }
}
