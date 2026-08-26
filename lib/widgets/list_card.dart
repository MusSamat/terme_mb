import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimens.dart';

/// Unified «Мои» / Requests card — one shape for bookings, trips, requests and
/// favourites. Head row carries a type dot + one-format date + role chip +
/// status pill; then the route; then an optional actor strip; then an optional
/// full-width action row. Expired favourites pass [dimmed] + [ribbon].
class ListCard extends StatelessWidget {
  const ListCard({
    super.key,
    required this.grape, // false = trip (teal dot), true = request (indigo dot)
    required this.when,
    this.role,
    this.status,
    required this.origin,
    required this.destination,
    this.avatar,
    this.actorName,
    this.actorSub,
    this.trailing,
    this.actions,
    this.onTap,
    this.onLongPress,
    this.dimmed = false,
    this.ribbon,
  });

  final bool grape;
  final String when;
  final String? role;
  final String? status;
  final String origin;
  final String destination;
  final Widget? avatar;
  final String? actorName;
  final Widget? actorSub;
  final Widget? trailing;
  final List<Widget>? actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool dimmed;
  final String? ribbon;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dot = grape ? GrapeColors.c600 : BrandColors.c600;

    final card = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl3),
          border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
          boxShadow: dark ? null : AppShadows.card,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Head: type dot · date · role chip · status pill. The left group
          // shrinks/ellipsises and the status label is short, so long statuses
          // like «Отменена пассажиром» never overflow the row on a phone.
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Flexible(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: Text(when, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: dark ? InkColors.c300 : InkColors.c600))),
                if (role != null) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: dark ? InkColors.c800 : InkColors.c100, borderRadius: BorderRadius.circular(999)),
                      child: Text(role!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: InkColors.c500)),
                    ),
                  ),
                ],
              ]),
            ),
            if (status != null) ...[const SizedBox(width: 8), _statusPill(dark, status!)],
          ]),
          const SizedBox(height: 9),
          // Route — full width, ellipsised city names, never squeezed by badges.
          Row(children: [
            Flexible(child: Text(origin, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 15, color: InkColors.c500)),
            Flexible(child: Text(destination, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900))),
          ]),
          // Actor strip
          if (avatar != null || actorName != null || trailing != null) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.only(top: 11),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: dark ? InkColors.c800 : InkColors.c100))),
              child: Row(children: [
                if (avatar != null) ...[avatar!, const SizedBox(width: 9)],
                if (actorName != null || actorSub != null)
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (actorName != null)
                        Text(actorName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                      if (actorSub != null) ...[const SizedBox(height: 2), actorSub!],
                    ]),
                  )
                else
                  const Spacer(),
                if (trailing != null) trailing!,
              ]),
            ),
          ],
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < actions!.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: actions![i]),
              ],
            ]),
          ],
        ]),
      ),
    );

    return _wrap(card);
  }

  // Compact, overflow-safe status pill — short one-word label + grouped colour.
  Widget _statusPill(bool dark, String s) {
    final c = _statusColors(s, dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(999)),
      child: Text('status_short.$s'.tr(),
          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.fg)),
    );
  }

  ({Color bg, Color fg}) _statusColors(String s, bool dark) {
    switch (s) {
      case 'accepted':
      case 'active':
      case 'open':
      case 'completed':
        return (bg: dark ? BrandColors.c500.withValues(alpha: 0.15) : BrandColors.c50, fg: dark ? BrandColors.c300 : BrandColors.c700);
      case 'pending':
      case 'viewed':
        return (bg: dark ? AccentColors.c500.withValues(alpha: 0.15) : AccentColors.c50, fg: dark ? AccentColors.c400 : AccentColors.c700);
      case 'rejected':
      case 'cancelled':
      case 'cancelled_by_passenger':
      case 'cancelled_by_driver':
      case 'cancelled_late':
      case 'no_show':
      case 'expired':
      case 'closed':
        return (bg: dark ? CoralColors.c500.withValues(alpha: 0.15) : CoralColors.c50, fg: dark ? CoralColors.c300 : CoralColors.c700);
      default:
        return (bg: dark ? InkColors.c800 : InkColors.c100, fg: dark ? InkColors.c300 : InkColors.c600);
    }
  }

  Widget _wrap(Widget card) {
    if (!dimmed && ribbon == null) return card;
    return Stack(children: [
      dimmed ? Opacity(opacity: 0.55, child: IgnorePointer(child: card)) : card,
      if (ribbon != null)
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: InkColors.c700, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.timer_off_outlined, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(ribbon!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
            ]),
          ),
        ),
    ]);
  }
}

/// Small helper for a compact meta sub-line (rating · phone · seats).
Widget listCardSub(List<InlineSpan> spans) => Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: InkColors.c500),
    );

enum ListBtnKind { primary, ghost, danger }

/// Full-width action button used inside [ListCard.actions]. Colour follows the
/// card accent (teal for trips, indigo for requests) for the primary variant.
class ListCardButton extends StatelessWidget {
  const ListCardButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.kind = ListBtnKind.ghost,
    this.grape = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final ListBtnKind kind;
  final bool grape;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = grape ? GrapeColors.c600 : BrandColors.c600;
    late final Color bg;
    late final Color fg;
    late final Color? border;
    switch (kind) {
      case ListBtnKind.primary:
        bg = accent;
        fg = Colors.white;
        border = null;
      case ListBtnKind.danger:
        bg = dark ? InkColors.c900 : Colors.white;
        fg = CoralColors.c600;
        border = dark ? CoralColors.c700 : CoralColors.c200;
      case ListBtnKind.ghost:
        bg = dark ? InkColors.c800 : Colors.white;
        fg = dark ? InkColors.c100 : InkColors.c700;
        border = dark ? InkColors.c700 : InkColors.c200;
    }
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: border != null ? Border.all(color: border) : null,
          ),
          // Shrink-to-fit so long labels («Редактировать поездку») never overflow
          // a narrow third-of-row button on a phone.
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 15, color: fg), const SizedBox(width: 6)],
                Text(label, maxLines: 1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
