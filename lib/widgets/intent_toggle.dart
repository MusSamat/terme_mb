import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Two-line intent switch — 1:1 port of tappjet_ft intent-toggle.tsx.
/// «Я пассажир · ищу поездку» / «Я водитель · ищу пассажиров».
class IntentToggle extends StatelessWidget {
  const IntentToggle({super.key, required this.driver, required this.onChanged});

  final bool driver;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _card(
            context,
            active: !driver,
            accent: BrandColors.c600,
            accentBg: BrandColors.c50,
            accentBorder: BrandColors.c500,
            accentText: BrandColors.c700,
            icon: Icons.person,
            title: 'feed.mode_trips_title'.tr(),
            sub: 'feed.mode_trips_sub'.tr(),
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _card(
            context,
            active: driver,
            accent: GrapeColors.c500,
            accentBg: GrapeColors.c50,
            accentBorder: GrapeColors.c500,
            accentText: GrapeColors.c600,
            icon: Icons.directions_car_filled,
            title: 'feed.mode_requests_title'.tr(),
            sub: 'feed.mode_requests_sub'.tr(),
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }

  Widget _card(
    BuildContext context, {
    required bool active,
    required Color accent,
    required Color accentBg,
    required Color accentBorder,
    required Color accentText,
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? (dark ? InkColors.c800 : accentBg)
              : (dark ? InkColors.c800 : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            width: 3,
            color: active ? accentBorder : (dark ? InkColors.c700 : InkColors.c200),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? accent : (dark ? InkColors.c700 : InkColors.c100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 16, color: active ? Colors.white : InkColors.c400),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: active
                              ? (dark ? Colors.white : accentText)
                              : (dark ? InkColors.c300 : InkColors.c700))),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? (dark ? InkColors.c300 : InkColors.c600)
                              : InkColors.c500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
