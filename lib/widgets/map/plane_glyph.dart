import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import 'map_marker.dart';
import 'svg_path.dart';

/// Plane (airport) — spec glyph, viewBox 24.
const planeGlyphData =
    'M21 15.5v-1.7l-8-5V3.5a1.5 1.5 0 0 0-3 0v5.3l-8 5v1.7l8-2.5v5.2l-2 1.5v1.3l3.5-1 3.5 1v-1.3l-2-1.5V13l8 2.5Z';

final Path planeGlyphPath = parseSvgPath(planeGlyphData);

class PlaneGlyph extends StatelessWidget {
  const PlaneGlyph({super.key, this.size = 22, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: GlyphPainter(planeGlyphPath, color));
}

/// The airport on a map: the listing pin silhouette (deep teal) with the plane.
/// Size [kMapPinSize]; place with `Marker(alignment: Alignment.topCenter)`.
class AirportMarker extends StatelessWidget {
  const AirportMarker({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
        size: kMapPinSize,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: PinPainter(BrandColors.c800))),
          const Positioned(left: 9, top: 9, child: PlaneGlyph(size: 22, color: Colors.white)),
        ]),
      );
}
