import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/widgets/map/car_glyph.dart';
import 'package:terme_mb/widgets/map/cluster_marker.dart';
import 'package:terme_mb/widgets/map/map_marker.dart';
import 'package:terme_mb/widgets/map/me_marker.dart';
import 'package:terme_mb/widgets/map/passenger_glyph.dart';
import 'package:terme_mb/widgets/map/svg_path.dart';

void _paint(CustomPainter p, [Size size = const Size(48, 48)]) {
  final rec = ui.PictureRecorder();
  p.paint(Canvas(rec), size);
  rec.endRecording().dispose();
}

void main() {
  group('parseSvgPath', () {
    test('absolute + relative lines, H/V, close', () {
      final b = parseSvgPath('M2 2h10v10H2z').getBounds();
      expect(b, const Rect.fromLTRB(2, 2, 12, 12));
    });

    test('arc commands produce a circle of the right size', () {
      final b = parseSvgPath('M12 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Z').getBounds();
      expect(b.width, closeTo(7, 0.05));
      expect(b.height, closeTo(7, 0.05));
      expect(b.center.dx, closeTo(12, 0.05));
    });

    test('S reflects the previous control point', () {
      final p = parseSvgPath('M0 0C0 10 10 10 10 0S20 -10 20 0');
      expect(p.getBounds().right, closeTo(20, 0.01));
      expect(p.getBounds().top, lessThan(0));
    });

    test('a number without a command is rejected', () {
      expect(() => parseSvgPath('5 5'), throwsFormatException);
    });
  });

  test('spec glyphs fit the 24×24 viewBox', () {
    for (final p in [carGlyphPath, passengerGlyphPath]) {
      final b = p.getBounds();
      expect(b.isEmpty, isFalse);
      expect(b.left, greaterThanOrEqualTo(0));
      expect(b.top, greaterThanOrEqualTo(0));
      expect(b.right, lessThanOrEqualTo(24));
      expect(b.bottom, lessThanOrEqualTo(24));
    }
    expect(carGlyphPath.fillType, PathFillType.evenOdd);
    // Windshield and the number plate are holes (evenodd): not filled.
    expect(carGlyphPath.contains(const Offset(12, 8)), isFalse);
    expect(carGlyphPath.contains(const Offset(12, 14.9)), isFalse);
    expect(carGlyphPath.contains(const Offset(12, 11.5)), isTrue);
    expect(passengerGlyphPath.contains(const Offset(12, 7.5)), isTrue);
    expect(passengerGlyphPath.contains(const Offset(12, 18)), isTrue);
  });

  test('painters paint without errors', () {
    _paint(GlyphPainter(carGlyphPath, Colors.white), const Size(22, 22));
    _paint(GlyphPainter(passengerGlyphPath, Colors.white), const Size(22, 22));
    _paint(PinPainter(Colors.teal), kMapPinSize);
    _paint(MePainter(const AlwaysStoppedAnimation(0.5)));
  });

  test('cluster diameter is log-scaled within 36…52', () {
    expect(clusterDiameter(1), 36);
    expect(clusterDiameter(10), greaterThan(clusterDiameter(2)));
    expect(clusterDiameter(1000), 52);
    expect(clusterDiameter(100000), 52);
  });

  testWidgets('markers render; me marker pulses and disposes its controller', (tester) async {
    await tester.pumpWidget(const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          MapMarker(requests: false, badge: 3),
          MapMarker(requests: true, selected: true),
          ClusterMarker(count: 1234),
          MeMarker(),
        ]),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('999+'), findsOneWidget);
    expect(find.byType(CarGlyph), findsOneWidget);
    expect(find.byType(PassengerGlyph), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
