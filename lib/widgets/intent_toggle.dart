import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Role / intent switch — a segmented control with one sliding thumb in the
/// active role colour (teal = passenger, grape = driver). Reads as a single
/// control with a clear current state, not two rival cards. Optional [showHint]
/// adds a one-line caption spelling out what the mode shows (used on the feed).
/// Same public API as before: [driver] + [onChanged].
class IntentToggle extends StatelessWidget {
  const IntentToggle({
    super.key,
    required this.driver,
    required this.onChanged,
    this.showHint = false,
  });

  final bool driver;
  final ValueChanged<bool> onChanged;
  final bool showHint;

  static const _dur = Duration(milliseconds: 240);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = driver ? GrapeColors.c600 : BrandColors.c600;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: dark ? InkColors.c800 : InkColors.c100,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Stack(
            children: [
              // Sliding thumb — half-width, animates left/right with the mode.
              Positioned.fill(
                child: AnimatedAlign(
                  duration: _dur,
                  curve: Curves.easeOutCubic,
                  alignment:
                      driver ? Alignment.centerRight : Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    heightFactor: 1,
                    child: AnimatedContainer(
                      duration: _dur,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.45),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: [
                    _segment(
                      active: !driver,
                      icon: Icons.person,
                      label: 'feed.mode_trips_title'.tr(),
                      onTap: () => onChanged(false),
                      dark: dark,
                    ),
                    _segment(
                      active: driver,
                      icon: Icons.directions_car_filled,
                      label: 'feed.mode_requests_title'.tr(),
                      onTap: () => onChanged(true),
                      dark: dark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showHint) ...[
          const SizedBox(height: 8),
          _hint(dark, accent),
        ],
      ],
    );
  }

  Widget _segment({
    required bool active,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool dark,
  }) {
    final off = dark ? InkColors.c400 : InkColors.c500;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedDefaultTextStyle(
            duration: _dur,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: active ? Colors.white : off,
            ),
            // Auto-shrink the whole group so long locales (kg
            // «Мен жүргүнчүмүн») stay fully visible in the fixed half-segment.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: active ? Colors.white : off),
                  const SizedBox(width: 7),
                  Text(label, maxLines: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // One-line caption: identity + what the feed shows for this mode.
  Widget _hint(bool dark, Color accent) {
    final title =
        driver ? 'feed.mode_requests_title'.tr() : 'feed.mode_trips_title'.tr();
    final hint =
        driver ? 'feed.mode_requests_hint'.tr() : 'feed.mode_trips_hint'.tr();
    return Row(
      children: [
        Icon(driver ? Icons.directions_car_filled : Icons.search,
            size: 14, color: accent),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '$title · $hint',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: dark ? InkColors.c400 : InkColors.c500,
            ),
          ),
        ),
      ],
    );
  }
}
