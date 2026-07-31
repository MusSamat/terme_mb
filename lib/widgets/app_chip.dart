import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Filter/quick chip — port of tappjet_ft ui/chip. `accent` picks the selected
/// tint (brand for passenger context, grape for driver).
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.accent = ChipAccent.brand,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final ChipAccent accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final acc = accent == ChipAccent.grape ? GrapeColors.c600 : BrandColors.c600;

    final bg = selected
        ? acc
        : (dark ? InkColors.c800 : Colors.white);
    final fg = selected
        ? Colors.white
        : (dark ? InkColors.c200 : InkColors.c700);
    final border = selected ? acc : (dark ? InkColors.c700 : InkColors.c200);

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

enum ChipAccent { brand, grape }
