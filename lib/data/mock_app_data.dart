// Sample data for bookings / chats / notifications / loyalty so those screens
// render without a backend. Removed once the API + providers land (ТЗ step 2).

import 'package:easy_localization/easy_localization.dart';

import '../utils/date_format.dart';

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
    this.tripId,
    this.departureAt,
  });
  final String id;
  final String? tripId; // parent trip id — used to match a pending rating
  final DateTime? departureAt; // for timeline sorting in «Мои»
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
      tripId: (j['tripId'] ?? trip['id']) as String?,
      departureAt: dep,
      otherName: (other['name'] ?? '') as String,
      origin: (trip['originCity'] ?? '') as String,
      destination: (trip['destinationCity'] ?? '') as String,
      dateLabel: dep != null ? '${dep.day.toString().padLeft(2, '0')}.${dep.month.toString().padLeft(2, '0')}' : '',
      seats: (j['seatsCount'] ?? 1) as int,
      status: (j['status'] ?? 'pending') as String,
      // Total = price frozen at booking time (pricePerSeatSnapshot) × seats;
      // legacy rows without a snapshot fall back to the trip's live price.
      sum: (((j['pricePerSeatSnapshot'] ?? trip['pricePerSeat'] ?? 0) as num).toInt()) *
          ((j['seatsCount'] ?? 1) as int),
      // Verified badge: the DTO has no `verified` flag — an established
      // counterparty is one with at least one rating.
      verified: ((other['ratingCount'] ?? 0) as num) > 0,
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
          destination: 'Жалал-Абад',
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

  factory MockChat.fromJson(Map<String, dynamic> j) => MockChat(
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
          route: 'Ош → Жалал-Абад',
          lastMessage: 'Есть место для чемодана?',
          timeLabel: '1 ч',
          unread: 0),
      MockChat(
          bookingId: 'b3',
          otherName: 'Тимур А.',
          route: 'Бишкек → Каракол',
          lastMessage: 'Спасибо за поездку!',
          timeLabel: '2 дн',
          unread: 0,
          bookingStatus: 'completed'),
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
    this.id = '',
    this.type = '',
    this.route,
  });
  final String typeKey; // key under notif.type_*
  final String body;
  final String timeLabel;
  final bool unread;
  final String kind; // booking | message | rating | system
  final String id;
  final String type; // raw backend type
  final String? route; // in-app deep link, or null when not navigable

  factory MockNotif.fromJson(Map<String, dynamic> j) {
    final type = (j['type'] ?? '') as String;
    final payload = (j['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
    String kind = 'system';
    if (type.contains('message')) {
      kind = 'message';
    } else if (type.contains('booking') || type.contains('request')) {
      kind = 'booking';
    } else if (type.contains('rating') || type.contains('rate')) {
      kind = 'rating';
    }
    return MockNotif(
      id: (j['id'] ?? '') as String,
      type: type,
      // Unknown types fall back to the generic label instead of a raw key.
      typeKey: _knownNotifTypes.contains(type) ? 'notif.type_$type' : 'notif.default_label',
      // Build the sub-text from the localized per-type template (web parity) so
      // it always matches the app language and never shows an empty subtitle.
      body: notifBody(type, payload),
      timeLabel: (() {
        final c = DateTime.tryParse((j['createdAt'] ?? '') as String);
        return c != null ? shortRelative(c) : '';
      })(),
      unread: j['readAt'] == null,
      kind: kind,
      route: notifDeepLink(type, payload),
    );
  }
}

const _knownNotifTypes = {
  'new_booking_request',
  'booking_accepted',
  'booking_request_confirmed',
  'booking_rejected',
  'booking_expired',
  'booking_cancelled_by_passenger',
  'booking_cancelled_by_driver',
  'trip_cancelled',
  'trip_reminder',
  'trip_completed_rate',
  'request_response_received',
  'request_response_accepted',
  'request_response_declined',
  'request_cancelled_admin',
  'new_message',
  'rating_received',
  'rating_warning',
  'verification_approved',
  'verification_rejected',
  'verification_need_docs',
  'account_blocked',
  'loyalty_tier_changed',
  'security_alert_reuse',
};

String _notifTime(String? iso) {
  final d = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
  if (d == null) return '';
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}, $hh:$mm';
}

/// Localized notification sub-text, built from the type + payload — 1:1 port of
/// the web `buildBody`. Always renders in the app language; the raw server
/// `payload.body` is used only as a last-resort fallback.
String notifBody(String type, Map<String, dynamic> p) {
  String s(String k) => (p[k] ?? '') as String;
  Map<String, dynamic>? mp(Map<String, dynamic>? m, String k) => (m?[k] as Map?)?.cast<String, dynamic>();
  String route2(String from, String to) => from.isNotEmpty && to.isNotEmpty ? ' · $from → $to' : '';

  switch (type) {
    case 'new_booking_request':
      {
        final name = s('passengerName');
        if (name.isEmpty) return 'notif.body_new_booking_request_fallback'.tr();
        final seats = p['seatsCount'] as int?;
        return 'notif.body_new_booking_request'.tr(namedArgs: {
          'name': name,
          'route': route2(s('originCity'), s('destinationCity')),
          'seats': seats != null ? 'notif.seats_part'.tr(namedArgs: {'n': '$seats'}) : '',
        });
      }
    case 'booking_accepted':
      {
        final trip = mp(mp(p, 'booking'), 'trip');
        final driver = mp(trip, 'driver');
        final name = (driver?['name'] ?? '') as String;
        if (name.isEmpty) return 'notif.body_booking_accepted_fallback'.tr();
        return 'notif.body_booking_accepted'.tr(namedArgs: {
          'name': name,
          'route': route2((trip?['originCity'] ?? '') as String, (trip?['destinationCity'] ?? '') as String),
        });
      }
    case 'booking_request_confirmed':
      {
        final name = s('passengerName');
        return name.isEmpty
            ? 'notif.body_booking_request_confirmed_fallback'.tr()
            : 'notif.body_booking_request_confirmed'.tr(namedArgs: {'name': name});
      }
    case 'booking_rejected':
      {
        final trip = mp(mp(p, 'booking'), 'trip');
        final r = route2((trip?['originCity'] ?? '') as String, (trip?['destinationCity'] ?? '') as String);
        return r.isEmpty ? 'notif.body_booking_rejected_fallback'.tr() : 'notif.body_booking_rejected'.tr(namedArgs: {'route': r});
      }
    case 'booking_expired':
      return 'notif.body_booking_expired'.tr();
    case 'booking_cancelled_by_passenger':
      {
        final trip = mp(mp(p, 'booking'), 'trip');
        final r = route2((trip?['originCity'] ?? '') as String, (trip?['destinationCity'] ?? '') as String);
        return r.isEmpty
            ? 'notif.body_booking_cancelled_by_passenger_fallback'.tr()
            : 'notif.body_booking_cancelled_by_passenger'.tr(namedArgs: {'route': r});
      }
    case 'booking_cancelled_by_driver':
      {
        final trip = mp(mp(p, 'booking'), 'trip');
        final r = route2((trip?['originCity'] ?? '') as String, (trip?['destinationCity'] ?? '') as String);
        return r.isEmpty
            ? 'notif.body_booking_cancelled_by_driver_fallback'.tr()
            : 'notif.body_booking_cancelled_by_driver'.tr(namedArgs: {'route': r});
      }
    case 'trip_cancelled':
      {
        final from = s('originCity');
        final to = s('destinationCity');
        return from.isNotEmpty && to.isNotEmpty
            ? 'notif.body_trip_cancelled'.tr(namedArgs: {'route': '$from → $to'})
            : 'notif.body_trip_cancelled_fallback'.tr();
      }
    case 'trip_reminder':
      {
        final from = s('origin_city');
        final to = s('destination_city');
        if (from.isEmpty || to.isEmpty) return 'notif.body_trip_reminder_fallback'.tr();
        final dep = _notifTime(p['departure_at'] as String?);
        return 'notif.body_trip_reminder'.tr(namedArgs: {'route': '$from → $to', 'time': dep.isNotEmpty ? ' · $dep' : ''});
      }
    case 'request_response_received':
      {
        final name = s('driverName');
        if (name.isEmpty) return 'notif.body_request_response_received_fallback'.tr();
        final price = p['price'] as int?;
        final dep = _notifTime(p['departureTime'] as String?);
        return 'notif.body_request_response_received'.tr(namedArgs: {
          'name': name,
          'price': price != null ? 'notif.price_part'.tr(namedArgs: {'price': '$price'}) : '',
          'time': dep.isNotEmpty ? ' · $dep' : '',
        });
      }
    case 'request_response_accepted':
      {
        final name = s('passengerName');
        return name.isEmpty
            ? 'notif.body_request_response_accepted_fallback'.tr()
            : 'notif.body_request_response_accepted'.tr(namedArgs: {'name': name});
      }
    case 'request_response_declined':
      return 'notif.body_request_response_declined'.tr();
    case 'request_cancelled_admin':
      {
        final reason = (p['reason'] ?? p['body'] ?? '') as String;
        if (reason.isNotEmpty) return 'notif.body_request_cancelled_admin'.tr(namedArgs: {'reason': reason});
        final from = s('originCity');
        final to = s('destinationCity');
        return from.isNotEmpty && to.isNotEmpty
            ? 'notif.body_request_cancelled_admin_route'.tr(namedArgs: {'route': '$from → $to'})
            : 'notif.body_request_cancelled_admin_fallback'.tr();
      }
    case 'new_message':
      {
        final preview = s('preview');
        return preview.isEmpty ? 'notif.body_new_message_fallback'.tr() : 'notif.body_new_message'.tr(namedArgs: {'preview': preview});
      }
    case 'rating_received':
      {
        final rater = s('raterName');
        if (rater.isEmpty) return 'notif.body_rating_received_fallback'.tr();
        final score = p['score'];
        return 'notif.body_rating_received'.tr(namedArgs: {'rater': rater, 'score': score != null ? ' ★ $score' : ''});
      }
    case 'rating_warning':
      {
        final rating = p['rating'];
        final r = rating is num ? rating.toStringAsFixed(1) : '< 4.0';
        return 'notif.body_rating_warning'.tr(namedArgs: {'rating': r});
      }
    case 'verification_approved':
      return 'notif.body_verification_approved'.tr();
    case 'verification_rejected':
      {
        final reason = (p['reason'] ?? p['body'] ?? '') as String;
        return reason.isNotEmpty ? reason : 'notif.body_verification_rejected'.tr();
      }
    case 'verification_need_docs':
      {
        final docs = (p['docs'] as List?)?.cast<String>() ?? const [];
        return docs.isEmpty
            ? 'notif.body_verification_need_docs_fallback'.tr()
            : 'notif.body_verification_need_docs'.tr(namedArgs: {'docs': docs.join(', ')});
      }
    case 'account_blocked':
      {
        final reason = (p['reason'] ?? p['body'] ?? '') as String;
        return reason.isNotEmpty ? reason : 'notif.body_account_blocked'.tr();
      }
    case 'loyalty_tier_changed':
      {
        final tier = s('tier');
        return tier.isEmpty
            ? 'notif.body_loyalty_tier_changed_fallback'.tr()
            : 'notif.body_loyalty_tier_changed'.tr(namedArgs: {'tier': tier});
      }
    case 'security_alert_reuse':
      return 'notif.body_security_alert_reuse'.tr();
    case 'trip_completed_rate':
      {
        final from = s('origin_city');
        final to = s('destination_city');
        return from.isNotEmpty && to.isNotEmpty
            ? 'notif.body_trip_completed_rate'.tr(namedArgs: {'route': '$from → $to'})
            : 'notif.body_trip_completed_rate_fallback'.tr();
      }
    default:
      // Unknown type (e.g. request_cancelled_admin) → keep the server text if any.
      final body = (p['body'] ?? p['reason'] ?? '') as String;
      return body.isNotEmpty ? body : 'notif.default_label'.tr();
  }
}

/// Maps a notification type + payload to an in-app route, or null when it isn't
/// navigable (those just get marked read). Mirrors web buildDeepLink, adapted to
/// the Flutter routes (no /my/requests → personal hub /my/bookings).
String? notifDeepLink(String type, Map<String, dynamic> payload) {
  String? bookingId() {
    final b = (payload['booking'] as Map?)?.cast<String, dynamic>();
    final m = (payload['message'] as Map?)?.cast<String, dynamic>();
    // Payload key style varies by emitter: DTO-carrying events are camelCase,
    // cron/raw events are snake_case — accept both.
    return (b?['id'] ?? payload['bookingId'] ?? payload['booking_id'] ?? m?['bookingId'])
        as String?;
  }

  switch (type) {
    case 'new_booking_request':
    case 'booking_request_confirmed':
    case 'booking_rejected':
    case 'booking_expired':
    case 'booking_cancelled_by_passenger':
    case 'booking_cancelled_by_driver':
    case 'trip_reminder':
    case 'trip_completed_rate':
    case 'request_response_received':
    case 'request_response_accepted':
    case 'request_response_declined':
    case 'request_cancelled_admin':
      return '/my/bookings';
    case 'booking_accepted':
    case 'new_message': {
      final id = bookingId();
      return id != null ? '/my/bookings/$id/chat' : '/my/bookings';
    }
    case 'trip_cancelled': {
      final tripId = (payload['tripId'] ?? payload['trip_id']) as String?;
      return tripId != null ? '/trips/$tripId' : '/trips';
    }
    case 'rating_received':
      return '/profile';
    case 'verification_approved':
    case 'verification_rejected':
    case 'verification_need_docs':
      return '/profile/driver';
    default:
      return null;
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
