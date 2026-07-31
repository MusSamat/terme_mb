import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Seat meter — port of tappjet_ft seat-meter.tsx. A row of vertical pills:
/// taken (gray) first, free (teal) last. Optional free-count text.
enum SeatMeterSize { sm, md, lg }

class SeatMeter extends StatelessWidget {
  const SeatMeter({
    super.key,
    required this.free,
    required this.total,
    this.size = SeatMeterSize.sm,
    this.showCount = false,
  });

  final int free;
  final int total;
  final SeatMeterSize size;
  final bool showCount;

  static const _pill = {
    SeatMeterSize.sm: Size(7, 14),
    SeatMeterSize.md: Size(20, 26),
    SeatMeterSize.lg: Size(26, 32),
  };
  static const _pillRadius = {SeatMeterSize.sm: 3.0, SeatMeterSize.md: 6.0, SeatMeterSize.lg: 8.0};
  static const _gap = {SeatMeterSize.sm: 3.0, SeatMeterSize.md: 5.0, SeatMeterSize.lg: 6.0};
  static const _countPx = {SeatMeterSize.sm: 12.0, SeatMeterSize.md: 13.0, SeatMeterSize.lg: 14.0};

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final safeTotal = total < 0 ? 0 : total;
    if (safeTotal == 0) return const SizedBox.shrink();
    final safeFree = free.clamp(0, safeTotal);

    final size = _pill[this.size]!;
    final radius = _pillRadius[this.size]!;

    final countColor = safeFree == 0
        ? DangerColors.c600
        : safeFree == 1
            ? AccentColors.c600
            : (dark ? BrandColors.c300 : BrandColors.c700);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < safeTotal; i++) ...[
          if (i > 0) SizedBox(width: _gap[this.size]),
          Container(
            width: size.width,
            height: size.height,
            decoration: BoxDecoration(
              color: i >= safeTotal - safeFree
                  ? BrandColors.c500
                  : (dark ? InkColors.c700 : InkColors.c200),
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ],
        if (showCount) ...[
          const SizedBox(width: 6),
          Text(
            '$safeFree',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              fontSize: _countPx[this.size],
              height: 1,
              color: countColor,
            ),
          ),
        ],
      ],
    );
  }
}
