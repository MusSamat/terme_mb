import 'package:flutter/painting.dart';

/// Canonical palette (diverges from terme_ft: two hues only).
/// Do NOT hardcode colors in widgets; read them through the theme (AppColors
/// ThemeExtension) or these token classes.
///
/// Two-hue palette (Uber/Yandex-style):
///   ink = warm stone neutrals — text, surfaces, borders, secondary buttons;
///   brand = teal — selection, links, focus, map, progress, success;
///   accent = amber — the one primary CTA per screen + pending/warning
///   (text on amber = AccentColors.ink);
///   danger = red — errors and destructive actions only.
/// Driver vs passenger is told apart by icon + label, never by color.

class BrandColors {
  static const c50 = Color(0xFFECFDF8);
  static const c100 = Color(0xFFD0FBEF);
  static const c200 = Color(0xFFA4F4DF);
  static const c300 = Color(0xFF6FE7CC);
  static const c400 = Color(0xFF38D3B6);
  static const c500 = Color(0xFF14B8A6);
  static const c600 = Color(0xFF0D9488);
  static const c700 = Color(0xFF0F766E);
  static const c800 = Color(0xFF115E56);
  static const c900 = Color(0xFF134E48);
}

class AccentColors {
  static const c50 = Color(0xFFFFF8EB);
  static const c100 = Color(0xFFFEEFC7);
  static const c200 = Color(0xFFFDDF8A);
  static const c300 = Color(0xFFFCCB4D);
  static const c400 = Color(0xFFFBB924);
  static const c500 = Color(0xFFF59E0B);
  static const c600 = Color(0xFFD97706);
  static const c700 = Color(0xFFB45309);

  /// Text color on amber-filled surfaces (buttons, badges).
  static const ink = Color(0xFF4A2C00);
}

class InkColors {
  // Warm single light background (inDrive/wb style) — app ships light-only, so
  // this is the one page background everywhere. Was #FAFAF9 (near-white).
  static const c50 = Color(0xFFF1F0EC);
  static const c100 = Color(0xFFF5F5F4);
  static const c200 = Color(0xFFE7E5E4);
  static const c300 = Color(0xFFD6D3D1);
  static const c400 = Color(0xFFA8A29E);
  static const c500 = Color(0xFF78716C);
  static const c600 = Color(0xFF57534E);
  static const c700 = Color(0xFF44403C);
  static const c800 = Color(0xFF292524);
  static const c900 = Color(0xFF1C1917);
  static const c950 = Color(0xFF0C0A09);
}

class DangerColors {
  static const c50 = Color(0xFFFEF2F2);
  static const c100 = Color(0xFFFEE2E2);
  static const c200 = Color(0xFFFECACA);
  static const c300 = Color(0xFFFCA5A5);
  static const c400 = Color(0xFFF87171);
  static const c500 = Color(0xFFEF4444);
  static const c600 = Color(0xFFDC2626);
  static const c700 = Color(0xFFB91C1C);
}
