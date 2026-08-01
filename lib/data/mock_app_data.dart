// Sample data for bookings / chats / notifications / loyalty so those screens
// render without a backend. Removed once the API + providers land (ТЗ step 2).

class MockBooking {
  const MockBooking({
    required this.id,
    required this.otherName,
    required this.origin,
    required this.destination,
    required this.dateLabel,
    required this.seats,
    required this.status,
    required this.sum,
    this.verified = false,
    this.phone,
    this.comment,
    this.avatarUrl,
  });
  final String id;
  final String otherName;
  final String origin;
  final String destination;
  final String dateLabel;
  final int seats;
  final String status; // key under status.*
  final int sum;
  final bool verified;
  final String? phone;
  final String? comment;
  final String? avatarUrl;

  factory MockBooking.fromJson(Map<String, dynamic> j) {
    final trip = (j['trip'] as Map?)?.cast<String, dynamic>() ?? const {};
    final other = ((j['passenger'] ?? trip['driver']) as Map?)?.cast<String, dynamic>() ?? const {};
    final dep = trip['departureAt'] != null ? DateTime.tryParse(trip['departureAt'] as String) : null;
    return MockBooking(
      id: j['id'] as String,
      otherName: (other['name'] ?? '') as String,
      origin: (trip['originCity'] ?? '') as String,
      destination: (trip['destinationCity'] ?? '') as String,
      dateLabel: dep != null ? '${dep.day.toString().padLeft(2, '0')}.${dep.month.toString().padLeft(2, '0')}' : '',
      seats: (j['seatsCount'] ?? 1) as int,
      status: (j['status'] ?? 'pending') as String,
      sum: ((j['totalPrice'] ?? trip['pricePerSeat'] ?? 0) as num).toInt(),
      verified: (other['verified'] ?? false) as bool,
      phone: other['phone'] as String?,
      comment: j['comment'] as String?,
    );
  }
}

List<MockBooking> mockBookings() => const [
      MockBooking(
          id: 'b1',
          otherName: 'Азамат Кыдыров',
          origin: 'Бишкек',
          destination: 'Ош',
          dateLabel: 'Сегодня, 06:00',
          seats: 2,
          status: 'accepted',
          sum: 2400,
          verified: true,
          phone: '+996 700 123 456',
          comment: 'Буду у автовокзала к 5:45, небольшой чемодан.'),
      MockBooking(
          id: 'b2',
          otherName: 'Нургуль С.',
          origin: 'Ош',
          destination: 'Джалал-Абад',
          dateLabel: 'Сегодня, 09:30',
          seats: 1,
          status: 'pending',
          sum: 350),
      MockBooking(
          id: 'b3',
          otherName: 'Бек Осмонов',
          origin: 'Талас',
          destination: 'Бишкек',
          dateLabel: 'Вчера, 14:00',
          seats: 1,
          status: 'completed',
          sum: 700,
          verified: true,
          phone: '+996 555 987 654'),
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

  factory MockChat.fromJson(Map<String, dynamic> j) => MockChat(
        bookingId: j['bookingId'] as String,
        otherName: (j['otherName'] ?? '') as String,
        route: (j['route'] ?? '') as String,
        lastMessage: (j['lastMessage'] ?? '') as String,
        timeLabel: (j['lastMessageAt'] ?? '') as String,
        unread: (j['unreadCount'] ?? 0) as int,
        avatarUrl: j['otherAvatarUrl'] as String?,
      );
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

  factory MockNotif.fromJson(Map<String, dynamic> j) {
    final type = (j['type'] ?? '') as String;
    String kind = 'system';
    if (type.contains('message')) {
      kind = 'message';
    } else if (type.contains('booking') || type.contains('request')) {
      kind = 'booking';
    } else if (type.contains('rating') || type.contains('rate')) {
      kind = 'rating';
    }
    return MockNotif(
      typeKey: 'notif.type_$type',
      body: ((j['payload'] as Map?)?['body'] ?? '') as String,
      timeLabel: (j['createdAt'] ?? '') as String,
      unread: j['readAt'] == null,
      kind: kind,
    );
  }
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

  factory MockLoyaltyTx.fromJson(Map<String, dynamic> j) => MockLoyaltyTx(
        points: (j['points'] ?? 0) as int,
        sourceKey: (j['source'] ?? 'bonus') as String,
        dateLabel: (j['createdAt'] ?? '') as String,
      );
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

  factory MockLoyalty.fromJson(Map<String, dynamic> status, List<dynamic> txs) => MockLoyalty(
        tier: (status['tier'] ?? 'novice') as String,
        points: (status['points'] ?? 0) as int,
        nextTier: status['nextTier'] as String?,
        pointsToNext: (status['pointsToNextTier'] ?? 0) as int,
        transactions: txs.map((e) => MockLoyaltyTx.fromJson((e as Map).cast<String, dynamic>())).toList(),
      );
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
