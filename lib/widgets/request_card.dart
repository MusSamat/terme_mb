
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/passenger_request.dart';
import '../theme/colors.dart';
import 'airport_extras.dart';
import '../utils/api_format.dart';
import '../utils/locale.dart';
import 'driver_avatar.dart';
import 'ticket.dart';

/// Passenger request card — teal ticket variant. Top: date · route · seats
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
    final kg = isKg(context);
    final extra = [
      if (r.distanceKm != null) distanceLabel(r.distanceKm!),
      if (r.originPoint != null) r.originPoint!.label(kg),
      if (r.flightNumber != null) '✈ ${r.flightNumber}',
    ].where((s) => s.isNotEmpty).join(' · ');

    final ink = dark ? Colors.white : InkColors.c900;
    final muted = dark ? InkColors.c400 : InkColors.c500;
    final accent = dark ? BrandColors.c300 : BrandColors.c600;

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
                    Icon(Icons.event, size: 16, color: accent),
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
                  Text('${r.originName(kg)} → ${r.destinationName(kg)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: muted)),
                  if (extra.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(extra, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: muted)),
                    ),
                  if (r.isAirport && (r.meetWithSign || r.luggageCount != null))
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: AirportExtras(request: r, color: muted),
                    ),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${r.seatsNeeded}', style: TextStyle(fontSize: 19, height: 1, fontWeight: FontWeight.w800, color: accent, fontFeatures: _tnum)),
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
                decoration: BoxDecoration(color: dark ? BrandColors.c500.withValues(alpha: 0.22) : BrandColors.c50, borderRadius: BorderRadius.circular(6)),
                child: Text('card.new'.tr(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dark ? BrandColors.c200 : BrandColors.c600)),
              ),
            const Spacer(),
            Icon(Icons.chevron_right, size: 18, color: dark ? BrandColors.c300 : BrandColors.c400),
          ]),
        ),
      ),
    );
  }
}
