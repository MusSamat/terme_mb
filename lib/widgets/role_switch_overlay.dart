import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Full-screen role-switch loader. Shown for ~1.5s when the user flips
/// Пассажир ⇄ Водитель: the target-role icon springs in, the role name below
/// it (auto-scaled so any locale fits), and a spinner in the role colour.
/// Swap the Material icons for the brand SVGs by dropping .svg assets + using
/// flutter_svg — the layout stays the same.
class RoleSwitchOverlay extends StatefulWidget {
  const RoleSwitchOverlay({super.key, required this.driver});

  final bool driver;

  @override
  State<RoleSwitchOverlay> createState() => _RoleSwitchOverlayState();
}

class _RoleSwitchOverlayState extends State<RoleSwitchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.driver ? GrapeColors.c600 : BrandColors.c600;
    final icon =
        widget.driver ? Icons.directions_car_filled_rounded : Icons.hail_rounded;
    final title = (widget.driver
            ? 'feed.role_switch_driver'
            : 'feed.role_switch_passenger')
        .tr();

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 220),
        builder: (_, fade, child) => Opacity(opacity: fade, child: child),
        child: ColoredBox(
          color: dark ? InkColors.c950 : InkColors.c50,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
                  child: FadeTransition(
                    opacity: _c,
                    child: Container(
                      width: 112,
                      height: 112,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: dark ? 0.20 : 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 56, color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                        color: dark ? Colors.white : InkColors.c900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'feed.role_switching'.tr(),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: InkColors.c400,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.6, color: accent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
