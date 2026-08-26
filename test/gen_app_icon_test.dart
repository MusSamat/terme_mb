import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/theme/colors.dart';
import 'package:terme_mb/widgets/logo_mark.dart';

/// Renders the brand mark to a 1024×1024 PNG (full-bleed teal + white plane)
/// at assets/images/app_icon.png — the source for flutter_launcher_icons.
/// Run: flutter test test/gen_app_icon_test.dart
void main() {
  test('generate app_icon.png', () async {
    const dim = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Full teal background (launchers mask corners themselves).
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [BrandColors.c500, BrandColors.c600],
      ).createShader(const Rect.fromLTWH(0, 0, dim, dim));
    canvas.drawRect(const Rect.fromLTWH(0, 0, dim, dim), bg);

    // White plane + amber dot (plain = no inner tile), centered with padding.
    canvas.save();
    canvas.translate(dim * 0.12, dim * 0.12);
    paintTermeLogo(canvas, const Size(dim * 0.76, dim * 0.76), plain: true);
    canvas.restore();

    final image = await recorder.endRecording().toImage(dim.toInt(), dim.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('assets/images/app_icon.png').writeAsBytesSync(bytes!.buffer.asUint8List());

    expect(File('assets/images/app_icon.png').existsSync(), isTrue);
  });
}
