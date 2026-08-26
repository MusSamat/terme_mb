import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// +/- seat stepper — port of terme_ft seats-stepper. Count text is role/
/// state colored; bounded by [min]..[max].
class SeatsStepper extends StatelessWidget {
  const SeatsStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 4,
    this.accent,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = this.accent ?? (dark ? BrandColors.c300 : BrandColors.c600);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(context, Icons.remove, value > min, () => onChanged(value - 1)),
        SizedBox(
          width: 48,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: accent)),
        ),
        _btn(context, Icons.add, value < max, () => onChanged(value + 1)),
      ],
    );
  }

  Widget _btn(BuildContext context, IconData icon, bool enabled, VoidCallback onTap) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? InkColors.c800 : InkColors.c100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: dark ? InkColors.c100 : InkColors.c700),
        ),
      ),
    );
  }
}
