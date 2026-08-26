
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/passenger_request.dart';
import '../theme/colors.dart';
import 'driver_avatar.dart';
import 'ticket.dart';

/// Passenger request card — grape ticket variant. Top: date · route · seats
/// needed. Perforated divider → passenger stub. One trust signal (rating OR
/// «Новый»); whole card tappable.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, this.onTap});

  final PassengerRequestItem request;
  final VoidCallback? onTap;

  static const _tnum = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = request;
    final showRating = r.passengerRating != null && r.passengerRatingCount >= 3;
    final firstName = r.passengerName.split(' ').first;
    final inactive = r.status != 'open';

    final ink = dark ? Colors.white : InkColors.c900;
    final muted = dark ? InkColors.c400 : InkColors.c500;
    final grape = dark ? GrapeColors.c300 : GrapeColors.c600;

    return Opacity(
      opacity: inactive ? 0.5 : 1,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: TicketCard(
          dark: dark,
          top: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.event, size: 16, color: grape),
                    const SizedBox(width: 6),
                    Flexible(child: Text(r.dateLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 17, height: 1.1, fontWeight: FontWeight.w800, color: ink))),
                    if (r.responded) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: dark ? BrandColors.c900 : BrandColors.c50, borderRadius: BorderRadius.circular(6)),
                        child: Text('card.responded'.tr(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: dark ? BrandColors.c200 : BrandColors.c700)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 6),
                  Text('${r.originCity} → ${r.destinationCity}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: muted)),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${r.seatsNeeded}', style: TextStyle(fontSize: 19, height: 1, fontWeight: FontWeight.w800, color: grape, fontFeatures: _tnum)),
                const SizedBox(height: 3),
                Text('card.needs'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
              ]),
            ],
          ),
          bottom: Row(children: [
            DriverAvatar(name: r.passengerName, size: AvatarSize.sm, verified: r.passengerVerified),
            const SizedBox(width: 8),
            Text(firstName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(width: 6),
            if (showRating)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star, size: 12, color: AccentColors.c400),
                const SizedBox(width: 2),
                Text(r.passengerRating!.toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: muted, fontFeatures: _tnum)),
              ])
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: dark ? GrapeColors.c500.withValues(alpha: 0.22) : GrapeColors.c50, borderRadius: BorderRadius.circular(6)),
                child: Text('card.new'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dark ? GrapeColors.c200 : GrapeColors.c600)),
              ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 18, color: dark ? GrapeColors.c300 : GrapeColors.c400),
          ]),
        ),
      ),
    );
  }
}
