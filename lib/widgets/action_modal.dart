import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimens.dart';
import 'app_button.dart';

/// Confirmation / result modal — 1:1 port of action-modal.tsx. Centered card,
/// tinted icon medallion, title, body, stacked action buttons.
enum ModalTone { brand, grape, accent, danger, sky, ink }

({Color bg, Color fg}) _medallion(ModalTone tone, bool dark) {
  switch (tone) {
    case ModalTone.brand:
      return (bg: dark ? BrandColors.c500.withValues(alpha: 0.15) : BrandColors.c100, fg: dark ? BrandColors.c300 : BrandColors.c600);
    case ModalTone.grape:
      return (bg: dark ? GrapeColors.c500.withValues(alpha: 0.15) : GrapeColors.c100, fg: dark ? GrapeColors.c300 : GrapeColors.c600);
    case ModalTone.accent:
      return (bg: dark ? AccentColors.c500.withValues(alpha: 0.15) : AccentColors.c100, fg: dark ? AccentColors.c300 : AccentColors.c600);
    case ModalTone.danger:
      return (bg: dark ? DangerColors.c500.withValues(alpha: 0.1) : DangerColors.c100, fg: dark ? DangerColors.c400 : DangerColors.c600);
    case ModalTone.sky:
      return (bg: dark ? SkyColors.c500.withValues(alpha: 0.15) : SkyColors.c100, fg: dark ? SkyColors.c300 : SkyColors.c600);
    case ModalTone.ink:
      return (bg: dark ? InkColors.c800 : InkColors.c100, fg: dark ? InkColors.c300 : InkColors.c600);
  }
}

/// Low-level: a centered result/confirm dialog. Returns whatever the buttons
/// pop with (bool for confirms).
Future<T?> showActionModal<T>(
  BuildContext context, {
  required IconData icon,
  required String title,
  ModalTone tone = ModalTone.brand,
  String? body,
  Widget? primary,
  Widget? secondary,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    useRootNavigator: true,
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      final dark = Theme.of(ctx).brightness == Brightness.dark;
      final m = _medallion(tone, dark);
      return Dialog(
        backgroundColor: dark ? InkColors.c900 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl3)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: m.bg, shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: m.fg),
              ),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 18, height: 1.3, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
              if (body != null) ...[
                const SizedBox(height: 6),
                Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: InkColors.c500)),
              ],
              if (primary != null || secondary != null) ...[
                const SizedBox(height: 20),
                if (primary != null) primary,
                if (secondary != null) ...[const SizedBox(height: 8), secondary],
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// Success result modal (brand medallion + check).
Future<void> showSuccessModal(BuildContext context, {required String title, String? body, String? primaryLabel, VoidCallback? onPrimary}) {
  return showActionModal<void>(
    context,
    icon: Icons.check_circle,
    tone: ModalTone.brand,
    title: title,
    body: body,
    primary: primaryLabel == null
        ? null
        : AppButton(label: primaryLabel, variant: AppButtonVariant.brand, onPressed: () {
            Navigator.of(context).pop();
            onPrimary?.call();
          }),
  );
}

/// Error result modal (danger medallion + alert).
Future<void> showErrorModal(BuildContext context, {required String title, String? body, String? primaryLabel}) {
  return showActionModal<void>(
    context,
    icon: Icons.error,
    tone: ModalTone.danger,
    title: title,
    body: body,
    primary: AppButton(label: primaryLabel ?? 'OK', variant: AppButtonVariant.outline, onPressed: () => Navigator.of(context).pop()),
  );
}

/// Confirmation modal — returns true if confirmed. [danger] uses the red tone
/// for destructive actions (cancel booking, delete, logout).
Future<bool> showConfirmModal(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  required String cancelLabel,
  bool danger = false,
  IconData? icon,
}) async {
  final result = await showActionModal<bool>(
    context,
    icon: icon ?? (danger ? Icons.warning_amber_rounded : Icons.help_outline),
    tone: danger ? ModalTone.danger : ModalTone.brand,
    title: title,
    body: body,
    primary: Builder(builder: (ctx) {
      return AppButton(
        label: confirmLabel,
        variant: danger ? AppButtonVariant.brand : AppButtonVariant.brand,
        onPressed: () => Navigator.of(ctx).pop(true),
      );
    }),
    secondary: Builder(builder: (ctx) {
      return AppButton(label: cancelLabel, variant: AppButtonVariant.outline, onPressed: () => Navigator.of(ctx).pop(false));
    }),
  );
  return result ?? false;
}
