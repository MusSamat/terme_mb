import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../data/mock_app_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/config.dart';
import '../../utils/date_format.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/query_error.dart';

/// Chat thread — 1:1 port of chat-panel / message-bubble / message-composer.
/// Bubbles (mine = brand right, other = white left with avatar), status ticks,
/// rounded composer with a circular send button. History is loaded from the
/// backend; sends are optimistic and persisted via REST.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.bookingId});
  final String bookingId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final List<MockMessage> _messages = [];
  final _input = TextEditingController();
  bool _loaded = false;
  bool _sending = false;
  String? _myId;
  void Function(dynamic)? _onSocketMessage;

  @override
  void initState() {
    super.initState();
    if (AppConfig.useMock) return;
    _myId = ref.read(authProvider).user?.id;
    // Mark the whole thread read on open (web chat-panel behavior), then refresh
    // the unread badges.
    ref.read(chatServiceProvider).markAllRead(widget.bookingId).then((_) {
      if (!mounted) return;
      ref.invalidate(unreadChatProvider);
      ref.invalidate(chatSummariesProvider);
    }).catchError((_) {/* best-effort */});
    final socket = ref.read(socketClientProvider);
    socket.connect();
    // Incoming messages arrive on our user room (server emits chat:message to the
    // recipient). Append the ones for THIS booking sent by the other party.
    _onSocketMessage = (data) {
      try {
        final m = ((data as Map)['message'] as Map?)?.cast<String, dynamic>();
        if (m == null) return;
        if (m['bookingId'] != widget.bookingId) return;
        if (_myId != null && m['senderId'] == _myId) return; // ignore own echo
        final created = DateTime.tryParse((m['createdAt'] ?? '') as String)?.toLocal();
        if (!mounted) return;
        setState(() {
          _messages.insert(0, MockMessage(
            text: (m['text'] ?? '') as String,
            mine: false,
            timeLabel: created != null ? hhmm(created) : 'chat.now'.tr(),
            read: true,
          ));
        });
      } catch (_) {/* ignore malformed frame */}
    };
    socket.on('chat:message', _onSocketMessage!);
  }

  @override
  void dispose() {
    _input.dispose();
    if (!AppConfig.useMock && _onSocketMessage != null) {
      ref.read(socketClientProvider).off('chat:message', _onSocketMessage);
    }
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.insert(0, MockMessage(text: text, mine: true, timeLabel: 'chat.now'.tr(), read: false));
      _input.clear();
      _sending = true;
    });
    try {
      if (!AppConfig.useMock) {
        await ref.read(chatServiceProvider).sendMessage(widget.bookingId, text);
      }
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  MockChat _fallbackChat() =>
      MockChat(bookingId: widget.bookingId, otherName: '—', route: '', lastMessage: '', timeLabel: '', unread: 0);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final summaries = ref.watch(chatSummariesProvider).valueOrNull ?? const <MockChat>[];
    // Prefer the summary; when the thread was deep-linked and isn't in the list
    // yet, fall back to the booking fetched by id (web getBooking behavior).
    final booking = ref.watch(bookingDetailProvider(widget.bookingId)).valueOrNull;
    final chat = summaries.firstWhere(
      (c) => c.bookingId == widget.bookingId,
      orElse: () => booking != null
          ? MockChat(
              bookingId: widget.bookingId,
              otherName: booking.otherName,
              route: '${booking.origin} → ${booking.destination}',
              lastMessage: '',
              timeLabel: '',
              unread: 0,
              bookingStatus: booking.status)
          : _fallbackChat(),
    );
    final threadAsync = ref.watch(chatThreadProvider(widget.bookingId));

    // Seed the mutable list once from the loaded history.
    ref.listen(chatThreadProvider(widget.bookingId), (_, next) {
      next.whenData((d) {
        if (!_loaded && mounted) {
          setState(() {
            _messages
              ..clear()
              ..addAll(d);
            _loaded = true;
          });
        }
      });
    });

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c900 : Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/chat'),
        ),
        title: Row(children: [
          DriverAvatar(name: chat.otherName, size: AvatarSize.sm),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(chat.otherName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                Text('chat.online'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BrandColors.c500)),
              ],
            ),
          ),
        ]),
      ),
      body: Column(
        children: [
          // Trip summary bar (route + booked status)
          Container(
            width: double.infinity,
            color: dark ? BrandColors.c500.withValues(alpha: 0.1) : BrandColors.c50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Icon(Icons.directions_car_filled, size: 16, color: dark ? BrandColors.c300 : BrandColors.c600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(chat.route,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: dark ? BrandColors.c200 : BrandColors.c800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: dark ? BrandColors.c500.withValues(alpha: 0.2) : BrandColors.c100,
                    borderRadius: BorderRadius.circular(999)),
                child: Text('chat.booked'.tr(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: dark ? BrandColors.c200 : BrandColors.c700)),
              ),
            ]),
          ),
          Expanded(
            child: !_loaded && threadAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (!_loaded && threadAsync.hasError)
                    ? QueryError(
                        error: threadAsync.error!,
                        onRetry: () => ref.invalidate(chatThreadProvider(widget.bookingId)),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _Bubble(msg: _messages[i], otherName: chat.otherName),
                      ),
          ),
          _Composer(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.msg, required this.otherName});
  final MockMessage msg;
  final String otherName;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mine = msg.mine;
    final bg = mine ? BrandColors.c600 : (dark ? InkColors.c800 : Colors.white);
    final fg = mine ? Colors.white : (dark ? InkColors.c100 : InkColors.c800);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 6),
          bottomRight: Radius.circular(mine ? 6 : 16),
        ),
        boxShadow: mine ? null : AppShadows.xs,
        border: mine ? null : Border.all(color: dark ? InkColors.c700 : InkColors.c100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg.text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35, color: fg)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(msg.timeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: mine ? Colors.white.withValues(alpha: 0.8) : InkColors.c500)),
              if (mine) ...[
                const SizedBox(width: 3),
                Icon(msg.read ? Icons.done_all : Icons.done, size: 14, color: msg.read ? Colors.white : Colors.white.withValues(alpha: 0.6)),
              ],
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            DriverAvatar(name: otherName, size: AvatarSize.sm),
            const SizedBox(width: 8),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        border: Border(top: BorderSide(color: dark ? InkColors.c800 : InkColors.c100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: dark ? InkColors.c800 : InkColors.c100, borderRadius: BorderRadius.circular(16)),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: dark ? Colors.white : InkColors.c900),
                decoration: InputDecoration(
                  hintText: 'chat.placeholder'.tr(),
                  hintStyle: const TextStyle(color: InkColors.c400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: BrandColors.c600, shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
