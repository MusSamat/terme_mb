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
  });

  final String code;
  final String message;
  final String? messageKg;
  final Map<String, dynamic>? details;
  final String? requestId;
  final int? statusCode;

  static const tokenExpired = 'TOKEN_EXPIRED';
  static const networkOffline = 'NETWORK_OFFLINE';
  static const seatsNotAvailable = 'SEATS_NOT_AVAILABLE';

  bool get isTokenExpired => code == tokenExpired;

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
  }

  return AppException(code: 'UNKNOWN', message: error.toString());
}
