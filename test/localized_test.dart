import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
// Localization / Translations are not re-exported; reach into src to seed the
// static instance for tests (no widget pump needed).
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terme_mb/api/errors.dart';
import 'package:terme_mb/api/friendly_error.dart';
import 'package:terme_mb/utils/date_format.dart';

/// Loads the real ru.json into easy_localization's static instance so the global
/// `tr()` used by friendlyError / date_format resolves against production
/// strings — without needing a full widget pump.
void loadRu() {
  final raw = File('assets/l10n/ru.json').readAsStringSync();
  final map = json.decode(raw) as Map<String, dynamic>;
  Localization.load(const Locale('ru'), translations: Translations(map));
}

DioException _envelope(Map<String, dynamic> error) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: 409, data: {'error': error}),
      type: DioExceptionType.badResponse,
    );

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    loadRu();
  });

  group('friendlyError — localized priority', () {
    test('reason (details.reason) is preferred over code', () {
      expect(
        friendlyError(_envelope({
          'code': 'CONFLICT',
          'message': 'raw server msg',
          'details': {'reason': 'cannot_book_own_trip'},
        })),
        'Вы не можете забронировать собственную поездку.',
      );
    });

    test('falls back to code dictionary when reason unknown', () {
      expect(
        friendlyError(_envelope({
          'code': 'SEATS_NOT_AVAILABLE',
          'message': 'raw',
          'details': {'reason': 'some_unmapped_reason'},
        })),
        'Мест больше нет. Попробуйте другую поездку.',
      );
    });

    test('offline code short-circuits to no_connection', () {
      expect(
        friendlyError(AppException(code: AppException.networkOffline, message: 'x')),
        'Нет соединения',
      );
    });

    test('server message used when neither reason nor code map', () {
      expect(
        friendlyError(_envelope({'code': 'TOTALLY_UNKNOWN_CODE_XYZ', 'message': 'Сервер сказал так'})),
        'Сервер сказал так',
      );
    });

    test('generic fallback when nothing else available', () {
      expect(
        friendlyError(_envelope({'code': 'TOTALLY_UNKNOWN_CODE_XYZ', 'message': ''})),
        'Произошла непредвиденная ошибка. Попробуйте обновить страницу.',
      );
    });

    test('empty reason string is skipped (falls to code)', () {
      expect(
        friendlyError(_envelope({
          'code': 'SEATS_NOT_AVAILABLE',
          'message': 'raw',
          'details': {'reason': ''},
        })),
        'Мест больше нет. Попробуйте другую поездку.',
      );
    });

    test('a plain AppException with an unmapped code returns its message', () {
      expect(friendlyError(AppException(code: 'ZZZ', message: 'boom')), 'boom');
    });
  });

  group('date_format.departureLabel — today/tomorrow words', () {
    test('same day → Сегодня', () {
      final now = DateTime.now();
      final label = departureLabel(DateTime(now.year, now.month, now.day, 8, 5));
      expect(label.date, 'Сегодня');
      expect(label.time, '08:05');
    });

    test('next day → Завтра', () {
      final t = DateTime.now().add(const Duration(days: 1));
      final label = departureLabel(DateTime(t.year, t.month, t.day, 14, 30));
      expect(label.date, 'Завтра');
      expect(label.time, '14:30');
    });

    test('far future → dd.MM', () {
      final t = DateTime.now().add(const Duration(days: 10));
      final label = departureLabel(DateTime(t.year, t.month, t.day, 9, 0));
      final expected = '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}';
      expect(label.date, expected);
    });
  });

  group('date_format.hhmm', () {
    test('formats a local time zero-padded', () {
      expect(hhmm(DateTime(2026, 8, 10, 7, 5)), '07:05');
    });
    test('midnight', () {
      expect(hhmm(DateTime(2026, 8, 10, 0, 0)), '00:00');
    });
    test('afternoon', () {
      expect(hhmm(DateTime(2026, 8, 10, 23, 59)), '23:59');
    });
  });
}
