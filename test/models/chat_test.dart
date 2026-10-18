import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/models/chat.dart';

void main() {
  group('ChatSummary.fromJson', () {
    final c = ChatSummary.fromJson({
      'bookingId': 'b1',
      'otherName': 'Азамат',
      'route': 'Бишкек → Ош',
      'lastMessage': 'ок',
      'lastMessageAt': '2026-01-05T12:00:00Z',
      'unreadCount': 2,
      'bookingStatus': 'accepted',
    });
    test('bookingId', () => expect(c.bookingId, 'b1'));
    test('otherName', () => expect(c.otherName, 'Азамат'));
    test('route', () => expect(c.route, 'Бишкек → Ош'));
    test('timeLabel: ISO → compact dd.MM for older messages', () => expect(c.timeLabel, '05.01'));
    test('unread from unreadCount', () => expect(c.unread, 2));
    test('bookingStatus', () => expect(c.bookingStatus, 'accepted'));
  });

  group('ChatSummary.fromJson — defaults', () {
    final c = ChatSummary.fromJson({'bookingId': 'b2'});
    test('unread defaults 0', () => expect(c.unread, 0));
    test('bookingStatus defaults accepted', () => expect(c.bookingStatus, 'accepted'));
    test('otherName empty', () => expect(c.otherName, ''));
  });

  group('ChatSummary.isActive — mirrors web ACTIVE_CHAT_STATUSES', () {
    ChatSummary withStatus(String s) => ChatSummary(
        bookingId: 'b', otherName: 'x', route: 'r', lastMessage: 'm', timeLabel: 't', unread: 0, bookingStatus: s);
    test('pending → active', () => expect(withStatus('pending').isActive, true));
    test('viewed → active', () => expect(withStatus('viewed').isActive, true));
    test('accepted → active', () => expect(withStatus('accepted').isActive, true));
    test('completed → archived', () => expect(withStatus('completed').isActive, false));
    test('cancelled → archived', () => expect(withStatus('cancelled').isActive, false));
    test('rejected → archived', () => expect(withStatus('rejected').isActive, false));
    test('no_show → archived', () => expect(withStatus('no_show').isActive, false));
  });
}
