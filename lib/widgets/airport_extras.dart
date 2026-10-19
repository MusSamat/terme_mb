import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/passenger_request.dart';
import '../theme/colors.dart';

/// Airport request extras as small icon + text: «С табличкой» · «Багаж: 2».
/// Renders nothing for intercity requests or when neither was given.
class AirportExtras extends StatelessWidget {
  const AirportExtras({super.key, required this.request, this.fontSize = 11.5, this.color});

  final PassengerRequestItem request;
  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final r = request;
    if (!r.isAirport || (!r.meetWithSign && r.luggageCount == null)) return const SizedBox.shrink();
    final c = color ?? (Theme.of(context).brightness == Brightness.dark ? InkColors.c400 : InkColors.c500);
    Widget item(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: fontSize + 3, color: c),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: c)),
        ]);
    return Wrap(spacing: 10, runSpacing: 4, children: [
      if (r.meetWithSign) item(Icons.badge_outlined, 'airport.with_sign'.tr()),
      if (r.luggageCount != null)
        item(Icons.luggage_outlined, 'airport.luggage_n'.tr(namedArgs: {'n': '${r.luggageCount}'})),
    ]);
  }
}
