import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/data/mock_app_data.dart';

void main() {
  group('MockChat.fromJson', () {
    final c = MockChat.fromJson({
      'bookingId': 'b1',
      'otherName': 'Азамат',
      'route': 'Бишкек → Ош',
      'lastMessage': 'ок',
      'lastMessageAt': '5 мин',
      'unreadCount': 2,
      'bookingStatus': 'accepted',
    });
    test('bookingId', () => expect(c.bookingId, 'b1'));
    test('otherName', () => expect(c.otherName, 'Азамат'));
    test('route', () => expect(c.route, 'Бишкек → Ош'));
    test('timeLabel from lastMessageAt', () => expect(c.timeLabel, '5 мин'));
    test('unread from unreadCount', () => expect(c.unread, 2));
    test('bookingStatus', () => expect(c.bookingStatus, 'accepted'));
  });

  group('MockChat.fromJson — defaults', () {
    final c = MockChat.fromJson({'bookingId': 'b2'});
    test('unread defaults 0', () => expect(c.unread, 0));
    test('bookingStatus defaults accepted', () => expect(c.bookingStatus, 'accepted'));
    test('otherName empty', () => expect(c.otherName, ''));
  });

  group('MockChat.isActive — mirrors web ACTIVE_CHAT_STATUSES', () {
    MockChat withStatus(String s) => MockChat(
        bookingId: 'b', otherName: 'x', route: 'r', lastMessage: 'm', timeLabel: 't', unread: 0, bookingStatus: s);
    test('pending → active', () => expect(withStatus('pending').isActive, true));
    test('viewed → active', () => expect(withStatus('viewed').isActive, true));
    test('accepted → active', () => expect(withStatus('accepted').isActive, true));
    test('completed → archived', () => expect(withStatus('completed').isActive, false));
    test('cancelled → archived', () => expect(withStatus('cancelled').isActive, false));
    test('rejected → archived', () => expect(withStatus('rejected').isActive, false));
    test('no_show → archived', () => expect(withStatus('no_show').isActive, false));
  });

  group('mockChats sample splits into active + archived', () {
    final chats = mockChats();
    test('has at least one active', () => expect(chats.any((c) => c.isActive), true));
    test('has at least one archived (for the divider)', () => expect(chats.any((c) => !c.isActive), true));
  });
}
