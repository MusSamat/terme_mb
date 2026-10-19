import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Filter/quick chip — port of terme_ft ui/chip.
/// [filled] = the «quick» leading chip (solid accent). Default = «filter» chip
/// (light-tinted selected: soft bg + accent text + accent border).
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.filled = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const acc600 = BrandColors.c600;
    const acc500 = BrandColors.c500;
    const acc50 = BrandColors.c50;
    const acc300 = BrandColors.c300;
    const acc700 = BrandColors.c700;

    late final Color bg;
    late final Color fg;
    late final Color border;

    if (selected && filled) {
      // «quick» chip — solid accent.
      bg = acc600;
      fg = Colors.white;
      border = acc600;
    } else if (selected) {
      // «filter» chip — light tinted.
      bg = dark ? acc500.withValues(alpha: 0.15) : acc50;
      fg = dark ? acc300 : acc700;
      border = acc500;
    } else {
      bg = dark ? InkColors.c900 : Colors.white;
      fg = dark ? InkColors.c200 : InkColors.c700;
      border = dark ? InkColors.c700 : InkColors.c200;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Which list a filter set belongs to: brand = trips, grape = requests.
/// Legacy name — no longer affects colour (all chips are teal).
enum ChipAccent { brand, grape }
