import 'package:flutter/material.dart';

/// The capture guide shape, drawn over a full-screen live camera preview.
enum CaptureGuide { idCard, car, passport, selfie }

/// Paints the guide over the camera feed: dims everything OUTSIDE the shape and
/// strokes the outline white — the same visual language as the web CameraCapture
/// overlay. Full-screen portrait (the car is the exact SVG silhouette).
class CaptureOverlayPainter extends CustomPainter {
  CaptureOverlayPainter(this.guide, {this.dim = 0.42});
  final CaptureGuide guide;
  final double dim;

  Paint _stroke([double w = 3]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true
    ..color = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size);
    // Dim everything outside the guide window.
    final outside = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), shape);
    canvas.drawPath(outside, Paint()..color = Colors.black.withValues(alpha: dim));
    canvas.drawPath(shape, _stroke());

    // Document frame → add L-shaped corner brackets for a scanner look.
    if (guide == CaptureGuide.idCard || guide == CaptureGuide.passport) {
      _corners(canvas, _frameRect(size));
    }
  }

  Path _shape(Size size) {
    switch (guide) {
      case CaptureGuide.selfie:
        final w = size.width * 0.62;
        return Path()..addOval(Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.42), width: w, height: w * 1.25));
      case CaptureGuide.car:
        return _carPath(size);
      case CaptureGuide.idCard:
      case CaptureGuide.passport:
        return Path()..addRRect(RRect.fromRectAndRadius(_frameRect(size), const Radius.circular(22)));
    }
  }

  Rect _frameRect(Size size) {
    final w = size.width * 0.9;
    final h = w * 2 / 3; // 3:2 landscape document window
    return Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.42), width: w, height: h);
  }

  void _corners(Canvas canvas, Rect r) {
    const arm = 34.0, rad = 22.0;
    final p = _stroke(3);
    canvas.drawPath(Path()
      ..moveTo(r.left, r.top + arm)
      ..lineTo(r.left, r.top + rad)
      ..arcToPoint(Offset(r.left + rad, r.top), radius: const Radius.circular(rad))
      ..lineTo(r.left + arm, r.top), p);
    canvas.drawPath(Path()
      ..moveTo(r.right - arm, r.top)
      ..lineTo(r.right - rad, r.top)
      ..arcToPoint(Offset(r.right, r.top + rad), radius: const Radius.circular(rad))
      ..lineTo(r.right, r.top + arm), p);
    canvas.drawPath(Path()
      ..moveTo(r.right, r.bottom - arm)
      ..lineTo(r.right, r.bottom - rad)
      ..arcToPoint(Offset(r.right - rad, r.bottom), radius: const Radius.circular(rad))
      ..lineTo(r.right - arm, r.bottom), p);
    canvas.drawPath(Path()
      ..moveTo(r.left + arm, r.bottom)
      ..lineTo(r.left + rad, r.bottom)
      ..arcToPoint(Offset(r.left, r.bottom - rad), radius: const Radius.circular(rad))
      ..lineTo(r.left, r.bottom - arm), p);
  }

  // Exact car-front silhouette (SVG viewBox 500×743), fit to a portrait screen.
  Path _carPath(Size size) {
    const bw = 500.0, bh = 743.2;
    final s = (size.width * 0.92 / bw) < (size.height * 0.8 / bh) ? size.width * 0.92 / bw : size.height * 0.8 / bh;
    final dx = (size.width - bw * s) / 2;
    final dy = (size.height - bh * s) / 2;
    double mx(double x) => dx + x * s;
    double my(double y) => dy + y * s;
    return Path()
      ..moveTo(mx(364.9), my(0))
      ..lineTo(mx(326.4), my(9.4))
      ..lineTo(mx(321.2), my(75.9))
      ..lineTo(mx(241.2), my(13.5))
      ..lineTo(mx(18.7), my(13.5))
      ..lineTo(mx(2.1), my(27))
      ..lineTo(mx(4.2), my(95.6))
      ..lineTo(mx(53), my(108.1))
      ..lineTo(mx(53), my(634.1))
      ..lineTo(mx(18.7), my(636.2))
      ..lineTo(mx(2.1), my(650.7))
      ..lineTo(mx(0), my(707.9))
      ..lineTo(mx(14.6), my(727.7))
      ..lineTo(mx(247.4), my(727.7))
      ..lineTo(mx(321.2), my(666.3))
      ..lineTo(mx(326.4), my(733.9))
      ..lineTo(mx(363.8), my(743.2))
      ..lineTo(mx(379.4), my(724.5))
      ..lineTo(mx(379.4), my(678.8))
      ..lineTo(mx(363.8), my(646.6))
      ..quadraticBezierTo(mx(442.8), my(605), mx(463.6), my(579.5))
      ..quadraticBezierTo(mx(484.4), my(554.1), mx(492.2), my(524.5))
      ..quadraticBezierTo(mx(500), my(494.8), mx(498.9), my(362.2))
      ..quadraticBezierTo(mx(497.9), my(229.7), mx(488.5), my(204.2))
      ..quadraticBezierTo(mx(479.2), my(178.8), mx(464.1), my(160.6))
      ..lineTo(mx(449.1), my(142.4))
      ..lineTo(mx(363.8), my(96.7))
      ..lineTo(mx(379.4), my(64.4))
      ..lineTo(mx(379.4), my(18.7))
      ..close();
  }

  @override
  bool shouldRepaint(CaptureOverlayPainter old) => old.guide != guide || old.dim != dim;
}
