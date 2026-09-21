import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/data_providers.dart';

/// Live "N онлайн" pill — pulsing green dot + real, server-counted number.
/// Hidden below [_min] real users (small numbers read as dead). Never fabricates.
class OnlineBadge extends ConsumerWidget {
  const OnlineBadge({super.key});

  static const int _min = 10;
  static const Color _dot = Color(0xFF10B981); // emerald-500
  static const Color _text = Color(0xFF047857); // emerald-700

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineCountProvider).asData?.value ?? 0;
    if (online < _min) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x1A10B981), // emerald-500 @ 10%
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x3310B981)), // emerald-500 @ 20%
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulsingDot(color: _dot),
          const SizedBox(width: 6),
          Text('$online',
              style: const TextStyle(fontWeight: FontWeight.w800, color: _text, fontSize: 13)),
          const SizedBox(width: 4),
          Text('presence.online'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF059669), fontSize: 13)),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value; // 0..1
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding, fading ring.
              Opacity(
                opacity: (1 - t) * 0.6,
                child: Container(
                  width: 6 + t * 8,
                  height: 6 + t * 8,
                  decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            ],
          );
        },
      ),
    );
  }
}
