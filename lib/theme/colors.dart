import 'package:flutter/painting.dart';

/// Canonical palette — 1:1 port of terme_ft/tailwind.config.ts.
/// Do NOT hardcode colors in widgets; read them through the theme (AppColors
/// ThemeExtension) or these token classes.
///
/// brand = teal (passenger), grape = indigo (driver), ink = warm stone
/// (guest/neutral), accent = amber CTA (text on amber = AccentColors.ink).

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
  static const c50 = Color(0xFFFAFAF9);
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

class GrapeColors {
  static const c50 = Color(0xFFEEF2FF);
  static const c100 = Color(0xFFE0E7FF);
  static const c200 = Color(0xFFC7D2FE);
  static const c300 = Color(0xFFA5B4FC);
  static const c400 = Color(0xFF818CF8);
  static const c500 = Color(0xFF6366F1);
  static const c600 = Color(0xFF4F46E5);
  static const c700 = Color(0xFF4338CA);
}

class CoralColors {
  static const c50 = Color(0xFFFFF1F2);
  static const c100 = Color(0xFFFFE4E6);
  static const c200 = Color(0xFFFECDD3);
  static const c300 = Color(0xFFFDA4AF);
  static const c400 = Color(0xFFFB7185);
  static const c500 = Color(0xFFF43F5E);
  static const c600 = Color(0xFFE11D48);
  static const c700 = Color(0xFFBE123C);
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

class SkyColors {
  static const c50 = Color(0xFFF0F9FF);
  static const c100 = Color(0xFFE0F2FE);
  static const c200 = Color(0xFFBAE6FD);
  static const c300 = Color(0xFF7DD3FC);
  static const c400 = Color(0xFF38BDF8);
  static const c500 = Color(0xFF0EA5E9);
  static const c600 = Color(0xFF0284C7);
  static const c700 = Color(0xFF0369A1);
}

class SemanticColors {
  static const success = Color(0xFF14B8A6);
  static const error = Color(0xFFF43F5E);
  static const warning = Color(0xFFF59E0B);
}
