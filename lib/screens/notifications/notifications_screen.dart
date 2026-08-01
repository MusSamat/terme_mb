import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_app_data.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/query_error.dart';

/// Notifications — 1:1 port of notification-item.tsx: tinted icon-medallion
/// cards, unread cards get a colored bg+ring, medallion filled when unread.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/')),
        title: Text('notif.default_label'.tr(), style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w800, fontSize: 20, color: dark ? Colors.white : InkColors.c900)),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('Прочитать всё', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: dark ? BrandColors.c300 : BrandColors.c600)),
          ),
        ],
      ),
      body: ref.watch(notificationsListProvider).when(
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500)),
            error: (e, _) => QueryError(error: e, onRetry: () => ref.invalidate(notificationsListProvider)),
            data: (items) => ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _NotifCard(notif: items[i]),
            ),
          ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.notif});
  final MockNotif notif;

  ({IconData icon, Color color}) _visual() {
    switch (notif.kind) {
      case 'booking':
        return (icon: Icons.event_available, color: BrandColors.c600);
      case 'message':
        return (icon: Icons.chat_bubble, color: SkyColors.c500);
      case 'rating':
        return (icon: Icons.star, color: AccentColors.c500);
      default:
        return (icon: Icons.info, color: InkColors.c600);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final v = _visual();
    final unread = notif.unread;

    // Unread card: tinted bg + ring; read: white + ink ring.
    final cardBg = unread
        ? v.color.withValues(alpha: dark ? 0.1 : 0.08)
        : (dark ? InkColors.c900 : Colors.white);
    final cardBorder = unread ? v.color.withValues(alpha: 0.25) : (dark ? InkColors.c800 : InkColors.c100);

    // Medallion: filled when unread, tinted when read.
    final medBg = unread ? v.color : v.color.withValues(alpha: dark ? 0.15 : 0.15);
    final medFg = unread ? Colors.white : v.color;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: cardBorder),
        boxShadow: unread ? null : AppShadows.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: medBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(v.icon, size: 20, color: medFg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(notif.typeKey.tr(),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                    ),
                    Text(notif.timeLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: InkColors.c400)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(notif.body, style: const TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w600, color: InkColors.c500)),
              ],
            ),
          ),
          if (unread)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 6),
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: CoralColors.c500, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
