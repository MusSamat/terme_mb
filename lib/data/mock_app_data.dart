// Sample data for bookings / chats / notifications / loyalty so those screens
// render without a backend. Removed once the API + providers land (ТЗ step 2).

class MockBooking {
  const MockBooking({
    required this.id,
    required this.otherName,
    required this.route,
    required this.dateLabel,
    required this.seats,
    required this.status,
    required this.sum,
    this.verified = false,
    this.avatarUrl,
  });
  final String id;
  final String otherName;
  final String route;
  final String dateLabel;
  final int seats;
  final String status; // key under bookings.status_*
  final int sum;
  final bool verified;
  final String? avatarUrl;
}

List<MockBooking> mockBookings() => const [
      MockBooking(
          id: 'b1',
          otherName: 'Азамат Кыдыров',
          route: 'Бишкек → Ош',
          dateLabel: 'Сегодня, 06:00',
          seats: 2,
          status: 'accepted',
          sum: 2400,
          verified: true),
      MockBooking(
          id: 'b2',
          otherName: 'Нургуль С.',
          route: 'Ош → Джалал-Абад',
          dateLabel: 'Сегодня, 09:30',
          seats: 1,
          status: 'pending',
          sum: 350),
      MockBooking(
          id: 'b3',
          otherName: 'Бек Осмонов',
          route: 'Талас → Бишкек',
          dateLabel: 'Вчера, 14:00',
          seats: 1,
          status: 'completed',
          sum: 700,
          verified: true),
    ];

class MockChat {
  const MockChat({
    required this.bookingId,
    required this.otherName,
    required this.route,
    required this.lastMessage,
    required this.timeLabel,
    required this.unread,
    this.avatarUrl,
  });
  final String bookingId;
  final String otherName;
  final String route;
  final String lastMessage;
  final String timeLabel;
  final int unread;
  final String? avatarUrl;
}

List<MockChat> mockChats() => const [
      MockChat(
          bookingId: 'b1',
          otherName: 'Азамат Кыдыров',
          route: 'Бишкек → Ош',
          lastMessage: 'Хорошо, буду у автовокзала к 5:45',
          timeLabel: '5 мин',
          unread: 2),
      MockChat(
          bookingId: 'b2',
          otherName: 'Нургуль С.',
          route: 'Ош → Джалал-Абад',
          lastMessage: 'Есть место для чемодана?',
          timeLabel: '1 ч',
          unread: 0),
    ];

class MockMessage {
  const MockMessage({required this.text, required this.mine, required this.timeLabel, this.read = true});
  final String text;
  final bool mine;
  final String timeLabel;
  final bool read;
}

List<MockMessage> mockThread() => const [
      MockMessage(text: 'Здравствуйте! Забронировал 2 места на утро.', mine: true, timeLabel: '08:12'),
      MockMessage(text: 'Здравствуйте! Принято 👍 Выезжаем в 6:00 от автовокзала.', mine: false, timeLabel: '08:14'),
      MockMessage(text: 'Отлично. Можно взять небольшой чемодан?', mine: true, timeLabel: '08:15'),
      MockMessage(text: 'Да, конечно. Багажник свободен.', mine: false, timeLabel: '08:16'),
      MockMessage(text: 'Хорошо, буду у автовокзала к 5:45', mine: false, timeLabel: '08:20', read: false),
    ];

class MockNotif {
  const MockNotif({
    required this.typeKey,
    required this.body,
    required this.timeLabel,
    required this.unread,
    required this.kind,
  });
  final String typeKey; // key under notif.type_*
  final String body;
  final String timeLabel;
  final bool unread;
  final String kind; // booking | message | rating | system
}

List<MockNotif> mockNotifs() => const [
      MockNotif(
          typeKey: 'notif.type_booking_accepted',
          body: 'Азамат принял вашу бронь · Бишкек → Ош',
          timeLabel: '5 мин',
          unread: true,
          kind: 'booking'),
      MockNotif(
          typeKey: 'notif.type_new_message',
          body: 'Нургуль С.: Есть место для чемодана?',
          timeLabel: '1 ч',
          unread: true,
          kind: 'message'),
      MockNotif(
          typeKey: 'notif.type_trip_completed_rate',
          body: 'Оцените поездку с Бек Осмонов · Талас → Бишкек',
          timeLabel: 'Вчера',
          unread: false,
          kind: 'rating'),
      MockNotif(
          typeKey: 'notif.type_loyalty_tier_changed',
          body: 'Новый уровень: Путешественник',
          timeLabel: '2 д',
          unread: false,
          kind: 'system'),
    ];

class MockLoyaltyTx {
  const MockLoyaltyTx({required this.points, required this.sourceKey, required this.dateLabel});
  final int points;
  final String sourceKey; // key under loyalty.sources.*
  final String dateLabel;
}

class MockLoyalty {
  const MockLoyalty({
    required this.tier,
    required this.points,
    required this.nextTier,
    required this.pointsToNext,
    required this.transactions,
  });
  final String tier; // key under loyalty.tiers.*
  final int points;
  final String? nextTier;
  final int pointsToNext;
  final List<MockLoyaltyTx> transactions;
}

MockLoyalty mockLoyalty() => const MockLoyalty(
      tier: 'traveler',
      points: 180,
      nextTier: 'expert',
      pointsToNext: 120,
      transactions: [
        MockLoyaltyTx(points: 10, sourceKey: 'trip_completed', dateLabel: 'Сегодня'),
        MockLoyaltyTx(points: 3, sourceKey: 'bonus', dateLabel: 'Вчера'),
        MockLoyaltyTx(points: 5, sourceKey: 'referral', dateLabel: '3 дня назад'),
      ],
    );
