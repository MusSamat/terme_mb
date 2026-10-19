import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/colors.dart';

/// Diameter 36…52 px, log-scaled by count (1 → 36, ≥1000 → 52).
double clusterDiameter(int count) => 36 + 16 * math.min(1.0, math.log(math.max(count, 1)) / math.ln10 / 3);

/// Server grid cluster (spec «Cluster»): white disc, 3px teal ring, teal count.
class ClusterMarker extends StatelessWidget {
  const ClusterMarker({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final d = clusterDiameter(count);
    return Container(
      width: d,
      height: d,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: BrandColors.c600, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Text(
        count > 999 ? '999+' : '$count',
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontSize: d < 44 ? 13 : 14, height: 1, fontWeight: FontWeight.w800, color: BrandColors.c600),
      ),
    );
  }
}
