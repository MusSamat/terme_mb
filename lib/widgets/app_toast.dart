import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimens.dart';

/// Toast — 1:1 port of quick-toast.tsx. 3 buckets: success → brand,
/// error → danger, info → ink. Icons: CheckCircle / AlertCircle / Info.
enum ToastVariant { success, error, info }

class ToastItem {
  ToastItem(this.id, this.variant, this.title, this.body);
  final int id;
  final ToastVariant variant;
  final String title;
  final String body;
}

/// Module-level queue so any layer can push a toast without context.
class Toasts {
  Toasts._();
  static final ValueNotifier<List<ToastItem>> items = ValueNotifier(<ToastItem>[]);
  static int _seq = 0;

  static void push(ToastVariant variant, String title, [String body = '']) {
    final item = ToastItem(_seq++, variant, title, body);
    items.value = [...items.value, item];
  }

  static void success(String title, [String body = '']) => push(ToastVariant.success, title, body);
  static void error(String title, [String body = '']) => push(ToastVariant.error, title, body);
  static void info(String title, [String body = '']) => push(ToastVariant.info, title, body);

  static void remove(int id) => items.value = items.value.where((e) => e.id != id).toList();
}

/// App-wide overlay hosting the toast stack. Mounted once via MaterialApp.builder.
class ToastOverlay extends StatelessWidget {
  const ToastOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      left: 20,
      right: 20,
      bottom: 96 + safeBottom,
      child: ValueListenableBuilder<List<ToastItem>>(
        valueListenable: Toasts.items,
        builder: (context, list, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final t in list) _ToastCard(key: ValueKey(t.id), item: t)],
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({super.key, required this.item});
  final ToastItem item;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2600), () => Toasts.remove(widget.item.id));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (bg, icon, shadow) = switch (widget.item.variant) {
      ToastVariant.success => (BrandColors.c600, Icons.check_circle, AppShadows.brandCta),
      ToastVariant.error => (DangerColors.c500, Icons.error, AppShadows.lift),
      ToastVariant.info => (dark ? InkColors.c700 : InkColors.c800, Icons.info, AppShadows.lift),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.xl2), boxShadow: shadow),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (widget.item.body.isNotEmpty)
                      Text(widget.item.body, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Toasts.remove(widget.item.id),
                child: Icon(Icons.close, size: 16, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
