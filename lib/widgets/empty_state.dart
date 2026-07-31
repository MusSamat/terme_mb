import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'app_button.dart';

/// Empty state — port of tappjet_ft empty-state. Icon medallion + title +
/// description + optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = this.tint ?? BrandColors.c600;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dark ? InkColors.c800 : InkColors.c100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: tint),
            ),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: dark ? Colors.white : InkColors.c900)),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(description!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: InkColors.c400)),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 220,
                child: AppButton(
                    label: actionLabel!, variant: AppButtonVariant.brand, height: 46, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thin alias used where the role-aware copy is already resolved by the caller.
class RoleEmptyState extends StatelessWidget {
  const RoleEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: icon,
        title: title,
        description: description,
        actionLabel: actionLabel,
        onAction: onAction,
      );
}
