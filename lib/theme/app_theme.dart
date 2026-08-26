import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

/// Semantic surface/border/text colors as a ThemeExtension.
/// Read via `Theme.of(context).extension<AppColors>()!` — never hardcode.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.brand,
    required this.accent,
    required this.accentInk,
    required this.danger,
    required this.success,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color brand;
  final Color accent;
  final Color accentInk;
  final Color danger;
  final Color success;

  static const light = AppColors(
    background: InkColors.c50,
    surface: Colors.white,
    surfaceMuted: InkColors.c100,
    border: InkColors.c200,
    textPrimary: InkColors.c900,
    textSecondary: InkColors.c600,
    textMuted: InkColors.c400,
    brand: BrandColors.c600,
    accent: AccentColors.c500,
    accentInk: AccentColors.ink,
    danger: CoralColors.c500,
    success: SemanticColors.success,
  );

  static const dark = AppColors(
    background: InkColors.c950,
    surface: InkColors.c900,
    surfaceMuted: InkColors.c800,
    border: InkColors.c800,
    textPrimary: InkColors.c100,
    textSecondary: InkColors.c300,
    textMuted: InkColors.c500,
    brand: BrandColors.c300,
    accent: AccentColors.c400,
    accentInk: AccentColors.ink,
    danger: CoralColors.c400,
    success: BrandColors.c300,
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? brand,
    Color? accent,
    Color? accentInk,
    Color? danger,
    Color? success,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      brand: brand ?? this.brand,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      danger: danger ?? this.danger,
      success: success ?? this.success,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppColors.light);
  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: BrandColors.c600,
      brightness: brightness,
      surface: c.surface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.background,
      colorScheme: scheme.copyWith(
        primary: c.brand,
        secondary: c.accent,
        error: c.danger,
      ),
      fontFamily: 'Manrope',
      textTheme: AppTypography.textTheme(c.textPrimary),
      extensions: <ThemeExtension<dynamic>>[c],
      splashFactory: NoSplash.splashFactory,
    );
  }
}
