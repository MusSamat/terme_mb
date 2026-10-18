import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/colors.dart';

/// OpenStreetMap base layer shared by every map in the app.
TileLayer osmTiles() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'kg.terme.termeMb',
      maxNativeZoom: 19,
    );

/// Centre of Kyrgyzstan — default camera when nothing better is known.
const kgCenter = LatLng(41.6, 74.6);

/// Small «© OpenStreetMap» credit (tile usage policy).
class OsmCredit extends StatelessWidget {
  const OsmCredit({super.key});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomRight,
        child: Container(
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          color: Colors.white.withValues(alpha: 0.75),
          child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: InkColors.c600)),
        ),
      );
}

/// Round pin marker (origin teal / destination accent).
class PinDot extends StatelessWidget {
  const PinDot({super.key, required this.color, this.icon = Icons.circle, this.size = 30});
  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Icon(icon, size: size * 0.5, color: Colors.white),
      );
}
