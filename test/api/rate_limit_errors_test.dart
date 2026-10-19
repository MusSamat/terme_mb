import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
// Localization / Translations are not re-exported; reach into src to seed the
// static instance for tests (same approach as localized_test.dart).
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:terme_mb/api/errors.dart';
import 'package:terme_mb/api/friendly_error.dart';

void _load(String lang) {
  final map = json.decode(File('assets/l10n/$lang.json').readAsStringSync()) as Map<String, dynamic>;
  Localization.load(Locale(lang), translations: Translations(map));
}

DioException _err(int status, Map<String, dynamic> error, {String? retryAfter}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    response: Response(
      requestOptions: req,
      statusCode: status,
      data: {'error': error},
      headers: Headers.fromMap({if (retryAfter != null) 'retry-after': [retryAfter]}),
    ),
    type: DioExceptionType.badResponse,
  );
}

DioException _limited(String? bucket, {String? reason, String? retryAfter}) => _err(
      429,
      {
        'code': 'RATE_LIMITED',
        'message': 'Too many requests',
        'details': {if (bucket != null) 'bucket': bucket, if (reason != null) 'reason': reason},
      },
      retryAfter: retryAfter,
    );

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('extractError — 429 extras', () {
    test('Retry-After header → retryAfter seconds; bucket exposed', () {
      final e = extractError(_limited('otp_send_ip_hour', retryAfter: '1800'));
      expect(e.retryAfter, 1800);
      expect(e.rateLimitBucket, 'otp_send_ip_hour');
      expect(e.statusCode, 429);
    });
    test('no header → null; bucket only for RATE_LIMITED', () {
      expect(extractError(_limited('otp_send_min')).retryAfter, isNull);
      expect(
        extractError(_err(409, {'code': 'CONFLICT', 'message': '', 'details': {'bucket': 'x'}})).rateLimitBucket,
        isNull,
      );
    });
  });

  group('otpResendCooldown', () {
    test('per-number minute cap → server wait, else 60 s', () {
      expect(otpResendCooldown(_limited('otp_send_min', retryAfter: '42')), 42);
      expect(otpResendCooldown(_limited('otp_send_min', reason: 'too_soon')), 60);
    });
    test('other caps / errors → null', () {
      expect(otpResendCooldown(_limited('otp_send_day', retryAfter: '80000')), isNull);
      expect(otpResendCooldown(_err(503, {'code': 'OTP_BUDGET_EXCEEDED', 'message': ''})), isNull);
    });
  });

  group('friendlyError — ru', () {
    setUpAll(() => _load('ru'));

    test('OTP_BUDGET_EXCEEDED (503)', () {
      expect(
        friendlyError(_err(503, {'code': 'OTP_BUDGET_EXCEEDED', 'message': 'x', 'details': {'scope': 'global'}})),
        'Сервис отправки кодов временно перегружен. Попробуйте позже.',
      );
    });
    test('CONTACT_LIMIT (429) — reveal flow shows the daily-limit text', () {
      expect(
        friendlyError(_err(429, {
          'code': 'CONTACT_LIMIT',
          'message': 'x',
          'details': {'reason': 'contact_reveal_daily_limit', 'limit': 20},
        })),
        'Достигнут дневной лимит просмотра номеров. Попробуйте завтра.',
      );
    });
    test('generic RATE_LIMITED', () {
      expect(friendlyError(_limited('public_read')), 'Слишком много запросов. Подождите минуту.');
      expect(friendlyError(_limited(null)), 'Слишком много запросов. Подождите минуту.');
    });
    test('generic RATE_LIMITED + short Retry-After → seconds left', () {
      expect(friendlyError(_limited('chat_send', retryAfter: '37')),
          'Слишком много запросов. Подождите минуту. Осталось 37 сек.');
    });
    test('OTP minute cap (service level, reason too_soon) — bucket text wins', () {
      expect(friendlyError(_limited('otp_send_min', reason: 'too_soon')),
          'Код уже отправлен на этот номер. Новый можно запросить через минуту.');
    });
    test('per-IP hourly OTP cap with Retry-After → minutes left', () {
      expect(friendlyError(_limited('otp_send_ip_hour', retryAfter: '1730')),
          'Слишком много запросов кода из этой сети. Попробуйте позже. Осталось 29 мин.');
    });
    test('daily caps say «завтра», no countdown for hours-long waits', () {
      expect(friendlyError(_limited('otp_send_day', retryAfter: '80000')),
          'Лимит кодов для этого номера на сегодня исчерпан. Попробуйте завтра.');
      expect(friendlyError(_limited('otp_send_ip_day', retryAfter: '50000')),
          'Лимит кодов для этой сети на сегодня исчерпан. Попробуйте завтра.');
    });
  });

  group('friendlyError — kg', () {
    setUpAll(() => _load('kg'));

    test('new codes are Kyrgyz', () {
      expect(friendlyError(_err(503, {'code': 'OTP_BUDGET_EXCEEDED', 'message': 'x'})),
          'Код жөнөтүү кызматы убактылуу ашыкча жүктөлгөн. Кийинчерээк аракет кылыңыз.');
      expect(friendlyError(_err(429, {'code': 'CONTACT_LIMIT', 'message': 'x'})),
          'Номер көрүүнүн күндүк чегине жеттиңиз. Эртең кайра аракет кылыңыз.');
      expect(friendlyError(_limited('otp_send_min', retryAfter: '42')),
          'Бул номерге код жөнөтүлдү. Жаңысын бир мүнөттөн кийин сурасаңыз болот. 42 сек. калды.');
    });
  });
}
