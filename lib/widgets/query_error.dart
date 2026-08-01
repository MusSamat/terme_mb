import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../api/friendly_error.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';

/// Inline error block for a failed load — 1:1 port of query-error.tsx:
/// danger medallion + friendly message + «Повторить» retry.
class QueryError extends StatelessWidget {
  const QueryError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl3),
          border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: dark ? DangerColors.c500.withValues(alpha: 0.15) : DangerColors.c100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off, size: 28, color: dark ? DangerColors.c400 : DangerColors.c600),
            ),
            const SizedBox(height: 12),
            Text(
              friendlyError(error),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: InkColors.c500),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onRetry,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: dark ? InkColors.c800 : InkColors.c100,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh, size: 16, color: dark ? InkColors.c200 : InkColors.c700),
                  const SizedBox(width: 6),
                  Text('errors.repeat'.tr(),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? InkColors.c100 : InkColors.c800)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
