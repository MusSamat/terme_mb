import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Small brand check badge shown next to a verified driver's name.
/// Port of terme_ft verified-badge.tsx.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: BrandColors.c600, shape: BoxShape.circle),
      child: Icon(Icons.check, size: size * 0.7, color: Colors.white),
    );
  }
}
