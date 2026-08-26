import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Lifecycle status pill — port of terme_ft status-badge. Label from the
/// `status.*` i18n namespace; color grouped by outcome.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final String status;

  ({Color bg, Color fg}) _colors(bool dark) {
    switch (status) {
      case 'accepted':
      case 'active':
      case 'open':
      case 'completed':
        return (
          bg: dark ? BrandColors.c500.withValues(alpha: 0.15) : BrandColors.c50,
          fg: dark ? BrandColors.c300 : BrandColors.c700,
        );
      case 'pending':
      case 'viewed':
        return (
          bg: dark ? AccentColors.c500.withValues(alpha: 0.15) : AccentColors.c50,
          fg: dark ? AccentColors.c400 : AccentColors.c700,
        );
      case 'rejected':
      case 'cancelled':
      case 'cancelled_by_passenger':
      case 'cancelled_by_driver':
      case 'cancelled_late':
      case 'no_show':
      case 'expired':
        return (
          bg: dark ? CoralColors.c500.withValues(alpha: 0.15) : CoralColors.c50,
          fg: dark ? CoralColors.c300 : CoralColors.c700,
        );
      default:
        return (
          bg: dark ? InkColors.c800 : InkColors.c100,
          fg: dark ? InkColors.c300 : InkColors.c600,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = _colors(dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(999)),
      child: Text('status.$status'.tr(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.fg)),
    );
  }
}
