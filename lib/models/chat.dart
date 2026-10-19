import '../utils/date_format.dart';
class ChatSummary {
  const ChatSummary({
    required this.bookingId,
    required this.otherName,
    required this.route,
    required this.lastMessage,
    required this.timeLabel,
    required this.unread,
    this.avatarUrl,
    this.bookingStatus = 'accepted',
  });
  final String bookingId;
  final String otherName;
  final String route;
  final String lastMessage;
  final String timeLabel;
  final int unread;
  final String? avatarUrl;
  final String bookingStatus; // pending | viewed | accepted → active; else archived

  /// Mirrors the web ACTIVE_CHAT_STATUSES set (chat-hub.tsx).
  bool get isActive => const {'pending', 'viewed', 'accepted'}.contains(bookingStatus);

  factory ChatSummary.fromJson(Map<String, dynamic> j) => ChatSummary(
        bookingId: j['bookingId'] as String,
        otherName: (j['otherName'] ?? '') as String,
        route: (j['route'] ?? '') as String,
        lastMessage: (j['lastMessage'] ?? '') as String,
        // Human label, not the raw ISO string the backend sends.
        timeLabel: (() {
          final t = DateTime.tryParse((j['lastMessageAt'] ?? '') as String);
          return t != null ? shortRelative(t.toLocal()) : '';
        })(),
        unread: (j['unreadCount'] ?? 0) as int,
        avatarUrl: j['otherAvatarUrl'] as String?,
        bookingStatus: (j['bookingStatus'] ?? 'accepted') as String,
      );
}

class ChatMessage {
  const ChatMessage({this.id, required this.text, required this.mine, required this.timeLabel, this.read = true});
  final String? id; // server id; null while an optimistic send is in flight
  final String text;
  final bool mine;
  final String timeLabel;
  final bool read;
}
