import 'package:flutter/material.dart';
import 'colors.dart';

/// Radii — 1:1 port of tailwind borderRadius tokens.
class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xl2 = 16.0; // 2xl (1rem)
  static const xl3 = 20.0; // 3xl (1.25rem)
  static const xl4 = 28.0; // 4xl (1.75rem)
  static const xl5 = 36.0; // 5xl (2.25rem)

  static BorderRadius r(double v) => BorderRadius.circular(v);
}

/// Spacing scale — tailwind spacing (px).
class AppSpacing {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s6 = 24.0;
  static const s8 = 32.0;
}

/// Shadows — 1:1 port of tailwind boxShadow tokens.
class AppShadows {
  static const xs = <BoxShadow>[
    BoxShadow(color: Color(0x0D1C1917), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const soft = <BoxShadow>[
    BoxShadow(color: Color(0x1F0D9488), blurRadius: 12, spreadRadius: -2, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x241C1917), blurRadius: 30, spreadRadius: -14, offset: Offset(0, 10)),
  ];

  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x0D1C1917), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x291C1917), blurRadius: 32, spreadRadius: -16, offset: Offset(0, 12)),
  ];

  static const lift = <BoxShadow>[
    BoxShadow(color: Color(0x0F1C1917), blurRadius: 6, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x421C1917), blurRadius: 50, spreadRadius: -20, offset: Offset(0, 26)),
  ];

  /// Amber CTA glow.
  static const cta = <BoxShadow>[
    BoxShadow(color: Color(0x80F59E0B), blurRadius: 24, spreadRadius: -8, offset: Offset(0, 10)),
  ];

  /// Teal (brand) CTA glow.
  static const brandCta = <BoxShadow>[
    BoxShadow(color: Color(0x800D9488), blurRadius: 24, spreadRadius: -8, offset: Offset(0, 10)),
  ];

  /// Indigo (grape) CTA glow.
  static const indigoCta = <BoxShadow>[
    BoxShadow(color: Color(0x734F46E5), blurRadius: 24, spreadRadius: -8, offset: Offset(0, 10)),
  ];
}

/// Mobile layout clearances — ported from globals.css.
/// The floating pill nav is ~96px; sticky CTAs / sheet footers clear 124px
/// (pill + protruding center create-FAB). Add safe-area bottom on top.
class AppLayout {
  static const pillNavClearance = 96.0;
  static const stickyCtaClearance = 124.0;
  static const topNavHeight = 64.0;
  static const minTapTarget = 44.0;
}

/// Amber create-FAB gradient (accent-400 → accent-600, top-left → bottom-right).
const kCreateFabGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AccentColors.c400, AccentColors.c600],
);
