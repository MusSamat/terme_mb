import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// Box of the «me» marker (halo Ø48), centred on the user's coordinate.
const kMeMarkerSize = 48.0;

/// User location (spec «Me»): Ø16 ink dot with a 3px white ring and a teal
/// halo pulsing out to Ø48 every 1.6s (static when animations are disabled).
class MeMarker extends StatefulWidget {
  const MeMarker({super.key});

  @override
  State<MeMarker> createState() => _MeMarkerState();
}

class _MeMarkerState extends State<MeMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final Animation<double> _t = CurvedAnimation(parent: _pulse, curve: Curves.easeOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pulse.value = 0.6;
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: kMeMarkerSize,
        child: RepaintBoundary(
          child: CustomPaint(painter: MePainter(_t)),
        ),
      );
}

class MePainter extends CustomPainter {
  MePainter(this.t) : super(repaint: t);
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final v = t.value;
    canvas.drawCircle(
      c,
      8 + (size.shortestSide / 2 - 8) * v,
      Paint()..color = BrandColors.c600.withValues(alpha: 0.2 * (1 - v)),
    );
    canvas.drawCircle(c, 8, Paint()..color = Colors.white);
    canvas.drawCircle(c, 5, Paint()..color = InkColors.c900);
  }

  @override
  bool shouldRepaint(MePainter old) => old.t != t;
}
