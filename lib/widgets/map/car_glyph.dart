import 'package:flutter/widgets.dart';

import 'svg_path.dart';

/// Car, front view (driver trip) — spec glyph, viewBox 24, evenodd.
const carGlyphData =
    'M6.2 5.8C6.5 4.7 7.5 4 8.6 4h6.8c1.1 0 2.1.7 2.4 1.8L19 10h.5c.8 0 1.5.7 1.5 1.5V17c0 .6-.4 1-1 1h-1v1.5'
    'c0 .8-.7 1.5-1.5 1.5S16 20.3 16 19.5V18H8v1.5C8 20.3 7.3 21 6.5 21S5 20.3 5 19.5V18H4c-.6 0-1-.4-1-1v-5.5'
    'C3 10.7 3.7 10 4.5 10H5l1.2-4.2ZM7.3 10h9.4l-.9-3.3c-.1-.4-.5-.7-.9-.7H9.1c-.4 0-.8.3-.9.7L7.3 10Z'
    'M7 15.4a1.4 1.4 0 1 0 0-2.8 1.4 1.4 0 0 0 0 2.8Zm10 0a1.4 1.4 0 1 0 0-2.8 1.4 1.4 0 0 0 0 2.8Z'
    'M10 14.2h4v1.4h-4z';

final Path carGlyphPath = parseSvgPath(carGlyphData, fillType: PathFillType.evenOdd);

class CarGlyph extends StatelessWidget {
  const CarGlyph({super.key, this.size = 22, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: GlyphPainter(carGlyphPath, color));
}
