import 'package:flutter/material.dart';

import '../models/metrics.dart';
import '../theme/colors.dart';

/// Creator-only engagement counters — views · likes · calls. Shown on the
/// trip/request detail when [metrics] is non-null (1:1 with the web
/// ListingMetrics: only the listing's owner sees it).
class ListingMetricsRow extends StatelessWidget {
  const ListingMetricsRow({super.key, required this.metrics});
  final Metrics? metrics;

  @override
  Widget build(BuildContext context) {
    final m = metrics;
    if (m == null) return const SizedBox.shrink();
    Widget stat(IconData icon, int n) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: InkColors.c400),
          const SizedBox(width: 4),
          Text('$n', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
        ]);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      stat(Icons.visibility_outlined, m.views),
      const SizedBox(width: 14),
      stat(Icons.favorite_border, m.likes),
      const SizedBox(width: 14),
      stat(Icons.call_outlined, m.contacts),
    ]);
  }
}
