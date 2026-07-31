import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_app_data.dart';
import '../../theme/colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = mockNotifs();

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text('notif.default_label'.tr(),
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('Прочитать всё',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: dark ? BrandColors.c300 : BrandColors.c600)),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
        itemBuilder: (_, i) => _NotifTile(notif: items[i]),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.notif});
  final MockNotif notif;

  ({IconData icon, Color color}) _visual() {
    switch (notif.kind) {
      case 'booking':
        return (icon: Icons.event_available, color: BrandColors.c500);
      case 'message':
        return (icon: Icons.chat_bubble, color: SkyColors.c500);
      case 'rating':
        return (icon: Icons.star, color: AccentColors.c500);
      default:
        return (icon: Icons.info, color: GrapeColors.c500);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final v = _visual();
    return Container(
      color: notif.unread ? (dark ? InkColors.c900 : BrandColors.c50.withValues(alpha: 0.4)) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: v.color.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: Icon(v.icon, size: 20, color: v.color),
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
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: dark ? Colors.white : InkColors.c900)),
                    ),
                    Text(notif.timeLabel,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600, color: InkColors.c400)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(notif.body,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, height: 1.35, color: InkColors.c500)),
              ],
            ),
          ),
          if (notif.unread)
            Container(
              margin: const EdgeInsets.only(left: 8, top: 6),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: BrandColors.c500, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
