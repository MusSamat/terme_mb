import 'package:easy_localization/easy_localization.dart';

/// Splits a departure DateTime into a (date, time) pair matching the web's
/// `formatDepartureLabel`. Time is HH:mm; date is Сегодня/Завтра or dd.MM.
({String date, String time}) departureLabel(DateTime dt) {
  final local = dt.toLocal();
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

  final now = DateTime.now();
  final d0 = DateTime(now.year, now.month, now.day);
  final target = DateTime(local.year, local.month, local.day);
  final diff = target.difference(d0).inDays;

  final String date;
  if (diff == 0) {
    date = tr('feed.today');
  } else if (diff == 1) {
    date = tr('feed.tomorrow');
  } else {
    date = '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}';
  }
  return (date: date, time: time);
}

String hhmm(DateTime dt) {
  final l = dt.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Short relative label for lists (notifications, etc.): «сейчас», «5 мин»,
/// «2 ч», «3 дн», then a compact dd.MM. Keeps the timestamp column narrow so it
/// never squeezes the title.
String shortRelative(DateTime dt) {
  final l = dt.toLocal();
  final diff = DateTime.now().difference(l);
  if (diff.inMinutes < 1) return tr('time.now');
  if (diff.inMinutes < 60) return '${diff.inMinutes} ${tr('time.min')}';
  if (diff.inHours < 24) return '${diff.inHours} ${tr('time.hour')}';
  if (diff.inDays < 7) return '${diff.inDays} ${tr('time.day')}';
  return '${l.day.toString().padLeft(2, '0')}.${l.month.toString().padLeft(2, '0')}';
}
