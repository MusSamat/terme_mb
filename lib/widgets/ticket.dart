import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// A "ticket" card: a surface split by a perforated divider with semicircle
/// notches punched into each edge (top = trip, bottom = stub). Light mode is a
/// plain white sheet (border + soft shadow give it depth on the near-white
/// feed); dark mode is warm graphite. The notch color must match the feed
/// background so the cutouts read as holes.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.dark, required this.top, required this.bottom});

  final bool dark;
  final Widget top;
  final Widget bottom;

  @override
  Widget build(BuildContext context) {
    final fill = dark ? const Color(0xFF232322) : Colors.white;
    final line = dark ? const Color(0xFF3C3C3A) : const Color(0xFFE7E5E4); // ink-200
    // Notch = the feed background behind the card, so cutouts look punched.
    final notch = dark ? InkColors.c950 : InkColors.c50;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
        border: dark ? null : Border.all(color: InkColors.c100),
        boxShadow: dark
            ? null
            : const [BoxShadow(color: Color(0x0F1C1917), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 0), child: top),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(height: 16, child: CustomPaint(painter: _PerfPainter(notch, line))),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 14), child: bottom),
        ],
      ),
    );
  }
}

class _PerfPainter extends CustomPainter {
  _PerfPainter(this.notch, this.line);
  final Color notch;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    // Full circles at the edges — the card's rounded-rect clip keeps only the
    // inner halves → semicircle notches punched into each side.
    // Notch fill = the feed background, so the cutout is the exact same colour
    // as what's behind the card — no outline, no colour difference on the edges.
    final n = Paint()..color = notch..isAntiAlias = true;
    // Crisp 1px edge in the perforation colour so each cutout reads as a clean
    // punched hole (the card's rounded clip removes the outer half → arc only).
    final edge = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    for (final cx in [0.0, size.width]) {
      canvas.drawCircle(Offset(cx, midY), 8, n);
      canvas.drawCircle(Offset(cx, midY), 8, edge);
    }
    // Dashed perforation line — inset so it runs cleanly between the notches.
    final l = Paint()
      ..color = line
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    var x = 12.0;
    while (x < size.width - 12) {
      canvas.drawLine(Offset(x, midY), Offset(x + 4, midY), l);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(_PerfPainter old) => old.notch != notch || old.line != line;
}
