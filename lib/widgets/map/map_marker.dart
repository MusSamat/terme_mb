import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import 'car_glyph.dart';
import 'passenger_glyph.dart';

/// Listing pin box: Ø40 circle + 8px pointer; the tip (bottom centre) is the
/// exact coordinate — place with `Marker(alignment: Alignment.topCenter)`.
const kMapPinSize = Size(40, 48);

/// Listing pin (spec «Marker»): teal disc, white ring, white glyph (car for
/// trips, person for requests), optional seats badge. Selected → ink, ×1.15.
class MapMarker extends StatelessWidget {
  const MapMarker({super.key, required this.requests, this.badge, this.selected = false});

  final bool requests;
  final int? badge;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fill = selected ? InkColors.c900 : BrandColors.c600;
    return AnimatedScale(
      scale: selected ? 1.15 : 1,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 160),
      child: SizedBox.fromSize(
        size: kMapPinSize,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: CustomPaint(painter: PinPainter(fill))),
          Positioned(
            left: 9,
            top: 9,
            child: requests
                ? const PassengerGlyph(size: 22, color: Colors.white)
                : const CarGlyph(size: 22, color: Colors.white),
          ),
          if (badge != null)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
                ),
                child: Text(
                  badge! > 9 ? '9+' : '$badge',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 11, height: 1, fontWeight: FontWeight.w800, color: BrandColors.c600),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Pin silhouette: disc + downward pointer, 2.5px white ring, soft shadow.
class PinPainter extends CustomPainter {
  PinPainter(this.fill);
  final Color fill;

  static const _ring = 2.5;

  Path _shape(Size s) {
    final r = s.width / 2 - _ring / 2;
    final c = Offset(s.width / 2, s.width / 2);
    final tip = s.height - _ring / 2;
    final pointer = Path()
      ..moveTo(c.dx - 7, c.dy + r - 3)
      ..lineTo(c.dx, tip)
      ..lineTo(c.dx + 7, c.dy + r - 3)
      ..close();
    return Path.combine(PathOperation.union, Path()..addOval(Rect.fromCircle(center: c, radius: r)), pointer);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size);
    canvas.drawPath(
      shape.shift(const Offset(0, 2)),
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = _ring
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(PinPainter old) => old.fill != fill;
}
