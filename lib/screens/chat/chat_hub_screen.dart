import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_app_data.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/empty_state.dart';

class ChatHubScreen extends StatelessWidget {
  const ChatHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chats = mockChats();

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        title: Text('chat.title'.tr(),
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: chats.isEmpty
          ? EmptyState(
              icon: Icons.forum_outlined,
              title: 'chat.empty_title'.tr(),
              description: 'chat.empty_hint'.tr())
          : ListView.builder(
              padding: EdgeInsets.only(
                  bottom: AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom),
              itemCount: chats.length,
              itemBuilder: (_, i) => _ChatRow(chat: chats[i]),
            ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat});
  final MockChat chat;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => context.push('/my/bookings/${chat.bookingId}/chat'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            DriverAvatar(name: chat.otherName, size: AvatarSize.md),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(chat.otherName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: dark ? Colors.white : InkColors.c900)),
                      ),
                      Text(chat.timeLabel,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600, color: InkColors.c400)),
                    ],
                  ),
                  Text(chat.route,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: InkColors.c400)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(chat.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: chat.unread > 0 ? FontWeight.w700 : FontWeight.w600,
                                color: chat.unread > 0
                                    ? (dark ? InkColors.c100 : InkColors.c800)
                                    : InkColors.c400)),
                      ),
                      if (chat.unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: CoralColors.c500, borderRadius: BorderRadius.circular(999)),
                          child: Text('${chat.unread}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
