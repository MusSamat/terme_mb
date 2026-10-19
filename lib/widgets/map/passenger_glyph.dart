import 'package:flutter/widgets.dart';

import 'svg_path.dart';

/// Person (passenger request) — spec glyph, viewBox 24: head + body.
const passengerGlyphData = 'M12 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z'
    'M5 19.5c0-3.6 3.1-6.5 7-6.5s7 2.9 7 6.5c0 .8-.7 1.5-1.5 1.5h-11c-.8 0-1.5-.7-1.5-1.5Z';

final Path passengerGlyphPath = parseSvgPath(passengerGlyphData);

class PassengerGlyph extends StatelessWidget {
  const PassengerGlyph({super.key, this.size = 22, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: GlyphPainter(passengerGlyphPath, color));
}
