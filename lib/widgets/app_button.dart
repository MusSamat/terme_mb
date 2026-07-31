import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimens.dart';

/// Primary action button. Amber = главное действие (submit/book), brand/grape =
/// operational, outline = secondary. Port of tappjet_ft button variants.
enum AppButtonVariant { amber, brand, grape, outline }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.amber,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null && !loading;

    late final Color bg;
    late final Color fg;
    late final List<BoxShadow> shadow;
    Border? border;

    switch (variant) {
      case AppButtonVariant.amber:
        bg = AccentColors.c500;
        fg = AccentColors.ink;
        shadow = AppShadows.cta;
      case AppButtonVariant.brand:
        bg = BrandColors.c600;
        fg = Colors.white;
        shadow = AppShadows.brandCta;
      case AppButtonVariant.grape:
        bg = GrapeColors.c600;
        fg = Colors.white;
        shadow = AppShadows.indigoCta;
      case AppButtonVariant.outline:
        bg = dark ? InkColors.c900 : Colors.white;
        fg = dark ? InkColors.c100 : InkColors.c800;
        shadow = const [];
        border = Border.all(color: dark ? InkColors.c700 : InkColors.c200);
    }

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: expand ? null : const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: enabled ? shadow : const [],
            border: border,
          ),
          child: loading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                    Text(label,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
                  ],
                ),
        ),
      ),
    );
  }
}
