import 'package:flutter/rendering.dart';

final _token = RegExp(r'[MmLlHhVvCcSsAaZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

/// Minimal SVG path-data parser (M L H V C S A Z, absolute + relative) — just
/// enough for the map glyphs, since flutter_svg is not a dependency.
Path parseSvgPath(String d, {PathFillType fillType = PathFillType.nonZero}) {
  final t = _token.allMatches(d).map((m) => m.group(0)!).toList();
  final path = Path()..fillType = fillType;
  var i = 0;
  var cmd = '';
  var x = 0.0, y = 0.0, sx = 0.0, sy = 0.0;
  double? cx2, cy2; // last cubic control point (for S)
  // Reset by every non-cubic segment so S reflects only a preceding C/S.

  bool isCmd(String s) => RegExp(r'^[A-Za-z]$').hasMatch(s);
  double n() => double.parse(t[i++]);

  while (i < t.length) {
    if (isCmd(t[i])) {
      cmd = t[i++];
    } else if (cmd == '' || cmd == 'Z' || cmd == 'z') {
      throw FormatException('Number without a command at token $i');
    } else if (cmd == 'M') {
      cmd = 'L'; // implicit lineto after a moveto
    } else if (cmd == 'm') {
      cmd = 'l';
    }
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        sx = x;
        sy = y;
        path.moveTo(x, y);
        cx2 = cy2 = null;
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
        cx2 = cy2 = null;
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
        cx2 = cy2 = null;
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
        cx2 = cy2 = null;
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx2 = x2;
        cy2 = y2;
      case 'S':
        final x1 = cx2 != null ? 2 * x - cx2 : x;
        final y1 = cy2 != null ? 2 * y - cy2 : y;
        final x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx2 = x2;
        cy2 = y2;
      case 'A':
        final rx = n(), ry = n(), rot = n(), large = n() != 0, sweep = n() != 0;
        x = ox + n();
        y = oy + n();
        path.arcToPoint(Offset(x, y),
            radius: Radius.elliptical(rx, ry), rotation: rot, largeArc: large, clockwise: sweep);
        cx2 = cy2 = null;
      case 'Z':
        path.close();
        x = sx;
        y = sy;
        cx2 = cy2 = null;
      default:
        throw FormatException('Unsupported SVG path command: $cmd');
    }
  }
  return path;
}

/// Paints a 24×24-viewBox glyph scaled into the canvas, filled with [color].
class GlyphPainter extends CustomPainter {
  GlyphPainter(this.path, this.color);
  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 24;
    canvas
      ..save()
      ..translate((size.width - 24 * s) / 2, (size.height - 24 * s) / 2)
      ..scale(s);
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..isAntiAlias = true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlyphPainter old) => old.path != path || old.color != color;
}
