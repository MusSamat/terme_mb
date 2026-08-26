import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Terme brand mark — exact geometry from terme_ft `LogoMark`
/// (viewBox 48×48): white paper-plane (two facets), amber point dot, two white
/// spark dots. `plain` drops the teal tile (for the plane on a teal surface).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 40, this.plain = false});

  final double size;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(plain: plain)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.plain});
  final bool plain;

  @override
  void paint(Canvas canvas, Size size) => paintTermeLogo(canvas, size, plain: plain);

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.plain != plain;
}

/// Draws the brand mark into [canvas] scaled to [size] (viewBox 48×48).
/// Public so tooling (app-icon generation) can reuse the exact geometry.
void paintTermeLogo(Canvas canvas, Size size, {bool plain = false}) {
  canvas.save();
  canvas.scale(size.width / 48);

  {
    if (!plain) {
      final tile = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BrandColors.c500, BrandColors.c600], // #14B8A6 → #0D9488
        ).createShader(const Rect.fromLTWH(0, 0, 48, 48));
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 48, 48), const Radius.circular(14)),
        tile,
      );
    }

    // Paper-plane facets.
    final facet1 = Path()
      ..moveTo(14.4, 28.8)
      ..lineTo(35.5, 12.5)
      ..lineTo(25.9, 31.7)
      ..close();
    canvas.drawPath(facet1, Paint()..color = Colors.white.withValues(alpha: 0.6));

    final facet2 = Path()
      ..moveTo(14.4, 28.8)
      ..lineTo(35.5, 12.5)
      ..lineTo(25, 25)
      ..close();
    canvas.drawPath(facet2, Paint()..color = Colors.white);

    // Amber point dot + two white spark dots.
    canvas.drawCircle(const Offset(12.5, 35.5), 3.1, Paint()..color = AccentColors.c400);
    final spark = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(const Offset(19, 30), 1.5, spark);
    canvas.drawCircle(const Offset(24, 24.5), 1.5, spark);
  }
  canvas.restore();
}

/// «Terme» wordmark — «Tapp» ink, «jet» brand teal (display font, 900).
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.fontSize = 24});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = TextStyle(
      fontFamily: 'Manrope',
      fontFamilyFallback: const ['Manrope'],
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
    );
    return Text.rich(TextSpan(children: [
      TextSpan(text: 'Tapp', style: base.copyWith(color: dark ? Colors.white : InkColors.c900)),
      TextSpan(text: 'jet', style: base.copyWith(color: dark ? BrandColors.c400 : BrandColors.c600)),
    ]));
  }
}
