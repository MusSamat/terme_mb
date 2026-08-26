import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/api/errors.dart';

Response<dynamic> _resp(int status, dynamic data) => Response(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
      data: data,
    );

DioException _dioWithEnvelope(int status, Map<String, dynamic> error) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: _resp(status, {'error': error}),
      type: DioExceptionType.badResponse,
    );

DioException _transport(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
    );

void main() {
  group('extractError — passthrough', () {
    test('an AppException is returned as-is', () {
      final original = AppException(code: 'X', message: 'y');
      expect(identical(extractError(original), original), true);
    });
  });

  group('extractError — backend envelope', () {
    final e = extractError(_dioWithEnvelope(409, {
      'code': 'SEATS_NOT_AVAILABLE',
      'message': 'Мест нет',
      'message_kg': 'Орун жок',
      'details': {'reason': 'sold_out'},
      'request_id': 'req-1',
    }));

    test('code', () => expect(e.code, 'SEATS_NOT_AVAILABLE'));
    test('message', () => expect(e.message, 'Мест нет'));
    test('messageKg', () => expect(e.messageKg, 'Орун жок'));
    test('details.reason', () => expect(e.details?['reason'], 'sold_out'));
    test('requestId', () => expect(e.requestId, 'req-1'));
    test('statusCode from response', () => expect(e.statusCode, 409));
  });

  group('extractError — envelope with missing fields', () {
    final e = extractError(_dioWithEnvelope(400, {}));
    test('code falls back to UNKNOWN', () => expect(e.code, 'UNKNOWN'));
    test('message falls back to empty', () => expect(e.message, ''));
    test('messageKg null', () => expect(e.messageKg, isNull));
    test('details null', () => expect(e.details, isNull));
    test('statusCode still captured', () => expect(e.statusCode, 400));
  });

  group('extractError — transport failures → NETWORK_OFFLINE', () {
    for (final type in [
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ]) {
      test('$type maps to NETWORK_OFFLINE', () {
        expect(extractError(_transport(type)).code, AppException.networkOffline);
      });
    }
  });

  group('extractError — non-envelope / unknown', () {
    test('DioException without envelope + non-transport → UNKNOWN', () {
      final e = extractError(DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: _resp(500, 'raw string body'),
        type: DioExceptionType.badResponse,
      ));
      expect(e.code, 'UNKNOWN');
    });
    test('arbitrary object → UNKNOWN with toString message', () {
      final e = extractError(StateError('boom'));
      expect(e.code, 'UNKNOWN');
      expect(e.message, contains('boom'));
    });
  });

  group('AppException', () {
    test('isTokenExpired true for TOKEN_EXPIRED', () {
      expect(AppException(code: AppException.tokenExpired, message: '').isTokenExpired, true);
    });
    test('isTokenExpired false otherwise', () {
      expect(AppException(code: 'OTHER', message: '').isTokenExpired, false);
    });
    test('toString includes code and message', () {
      expect(AppException(code: 'C', message: 'M').toString(), 'AppException(C, M)');
    });
    test('static constants', () {
      expect(AppException.tokenExpired, 'TOKEN_EXPIRED');
      expect(AppException.networkOffline, 'NETWORK_OFFLINE');
      expect(AppException.seatsNotAvailable, 'SEATS_NOT_AVAILABLE');
    });
  });
}
