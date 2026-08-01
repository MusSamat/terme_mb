import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_app_data.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/query_error.dart';

/// Chat hub — 1:1 port of chat-hub.tsx (mobile): header with active count,
/// a notifications inbox row, then the conversation list (active + archive).
class ChatHubScreen extends ConsumerWidget {
  const ChatHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final chatsAsync = ref.watch(chatSummariesProvider);
    final activeCount = chatsAsync.asData?.value.length ?? 0;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              color: dark ? InkColors.c900 : Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('chat.hub_title'.tr(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
                  const SizedBox(height: 2),
                  Text(activeCount > 0 ? 'chat.active_count'.tr(namedArgs: {'n': '$activeCount'}) : 'chat.no_active'.tr(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
                ],
              ),
            ),
            // Notifications row
            GestureDetector(
              onTap: () => context.push('/notifications'),
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: dark ? InkColors.c900 : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: dark ? InkColors.c800 : InkColors.c100))),
                child: Row(children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: dark ? BrandColors.c500.withValues(alpha: 0.15) : BrandColors.c50, shape: BoxShape.circle),
                      child: Icon(Icons.notifications, size: 20, color: dark ? BrandColors.c300 : BrandColors.c600),
                    ),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: CoralColors.c500, borderRadius: BorderRadius.circular(999), border: Border.all(color: dark ? InkColors.c900 : Colors.white, width: 2)),
                        child: const Text('2', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                      ),
                    ),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('chat.notifications_row'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                        Text('chat.notifications_none'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c500)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: InkColors.c400),
                ]),
              ),
            ),
            Expanded(
              child: Container(
                color: dark ? InkColors.c900 : Colors.white,
                child: chatsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500)),
                  error: (e, _) => QueryError(error: e, onRetry: () => ref.invalidate(chatSummariesProvider)),
                  data: (chats) => chats.isEmpty
                      ? _empty(dark)
                      : ListView(
                          padding: EdgeInsets.only(bottom: AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom),
                          children: [for (final c in chats) _ChatRow(chat: c)],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(bool dark) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: dark ? InkColors.c800 : InkColors.c100, shape: BoxShape.circle),
              child: const Icon(Icons.chat_bubble_outline, size: 32, color: InkColors.c400),
            ),
            const SizedBox(height: 12),
            Text('chat.no_chats'.tr(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: dark ? InkColors.c200 : InkColors.c700)),
            const SizedBox(height: 4),
            Text('chat.hub_empty_hint'.tr(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: InkColors.c400)),
          ],
        ),
      );
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            DriverAvatar(name: chat.otherName, size: AvatarSize.md),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(chat.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900))),
                    Text(chat.timeLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: InkColors.c400)),
                  ]),
                  Text(chat.route, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: InkColors.c400)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Expanded(
                      child: Text(chat.lastMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: chat.unread > 0 ? FontWeight.w700 : FontWeight.w600,
                              color: chat.unread > 0 ? (dark ? InkColors.c100 : InkColors.c800) : InkColors.c400)),
                    ),
                    if (chat.unread > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: CoralColors.c500, borderRadius: BorderRadius.circular(999)),
                        child: Text('${chat.unread}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
