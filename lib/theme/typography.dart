import 'package:flutter/material.dart';

/// Typography — 1:1 port of tailwind fontSize tokens.
/// Body font = Nunito (family 'Nunito'); display/headings = Fredoka
/// (family 'Fredoka') which lacks Cyrillic → fallback to Nunito 900.
///
/// Sizes are in logical px (tailwind rem * 16). Do NOT disable textScaler —
/// text must scale with the OS accessibility setting.
class AppTypography {
  static const _display = 'Fredoka';
  static const _body = 'Nunito';
  static const _dispFallback = <String>['Nunito'];

  static const display = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _dispFallback,
    fontSize: 32,
    height: 1.12,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  );

  static const h1 = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _dispFallback,
    fontSize: 24,
    height: 1.20,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  static const h2 = TextStyle(
    fontFamily: _display,
    fontFamilyFallback: _dispFallback,
    fontSize: 18,
    height: 1.30,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  static const bodyLg = TextStyle(
    fontFamily: _body,
    fontSize: 15,
    height: 1.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.15, // ~ -0.01em
  );

  static const body = TextStyle(
    fontFamily: _body,
    fontSize: 14,
    height: 1.5,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.14,
  );

  static const caption = TextStyle(
    fontFamily: _body,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );

  /// Uppercase field labels (Card-Field pattern).
  static const label = TextStyle(
    fontFamily: _body,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.88, // ~ 0.08em
  );

  static TextTheme textTheme(Color onSurface) {
    final t = TextStyle(color: onSurface);
    return TextTheme(
      displayLarge: display.merge(t),
      headlineLarge: h1.merge(t),
      headlineMedium: h2.merge(t),
      titleMedium: bodyLg.merge(t),
      bodyMedium: body.merge(t),
      bodySmall: caption.merge(t),
      labelSmall: label.merge(t),
    );
  }
}
