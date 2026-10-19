import 'package:dio/dio.dart';

/// Canonical API error shape:
/// { error: { code, message, message_kg?, details?, request_id? } }
class AppException implements Exception {
  AppException({
    required this.code,
    required this.message,
    this.messageKg,
    this.details,
    this.requestId,
    this.statusCode,
    this.retryAfter,
  });

  final String code;
  final String message;
  final String? messageKg;
  final Map<String, dynamic>? details;
  final String? requestId;
  final int? statusCode;

  /// Seconds until a 429 clears (the Retry-After header of the route limiters);
  /// null when the server didn't say (DB-level OTP caps).
  final int? retryAfter;

  static const tokenExpired = 'TOKEN_EXPIRED';
  static const rateLimited = 'RATE_LIMITED';
  static const networkOffline = 'NETWORK_OFFLINE';
  static const seatsNotAvailable = 'SEATS_NOT_AVAILABLE';

  bool get isTokenExpired => code == tokenExpired;

  /// Rate-limiter bucket of a 429 (`otp_send_min`, `otp_send_ip_hour`, …).
  String? get rateLimitBucket {
    if (code != rateLimited) return null;
    return details?['bucket']?.toString();
  }

  @override
  String toString() => 'AppException($code, $message)';
}

/// Maps a DioException into an [AppException] using the backend error envelope,
/// falling back to a synthetic NETWORK_OFFLINE for transport failures.
AppException extractError(Object error) {
  if (error is AppException) return error;

  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final e = data['error'] as Map;
      return AppException(
        code: (e['code'] ?? 'UNKNOWN').toString(),
        message: (e['message'] ?? '').toString(),
        messageKg: e['message_kg']?.toString(),
        details: (e['details'] as Map?)?.cast<String, dynamic>(),
        requestId: e['request_id']?.toString(),
        statusCode: error.response?.statusCode,
        retryAfter: int.tryParse(error.response?.headers.value('retry-after')?.trim() ?? ''),
      );
    }

    final isTransport = error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout;
    if (isTransport) {
      return AppException(
        code: AppException.networkOffline,
        message: 'Network is unavailable',
      );
    }

    // A response came back but WITHOUT our JSON envelope — a 502/504 from the
    // proxy (HTML body), or an unexpected 5xx/4xx. Never surface the raw
    // DioException dump: map to a friendly code and let friendlyError localize.
    final status = error.response?.statusCode;
    if (status != null) {
      return AppException(
        code: status >= 500 ? 'SERVER_ERROR' : 'REQUEST_ERROR',
        message: '',
        statusCode: status,
      );
    }
  }

  // Unknown failure — generic (message empty so friendlyError uses global_desc,
  // never a raw toString()).
  return AppException(code: 'UNKNOWN', message: '');
}

/// A 429 from the per-number «one code a minute» cap: the code is already on
/// its way, so the UI runs its resend countdown (server wait, else 60 s).
int? otpResendCooldown(Object error) {
  final e = extractError(error);
  if (e.rateLimitBucket != 'otp_send_min') return null;
  return (e.retryAfter ?? 60).clamp(1, 120);
}
