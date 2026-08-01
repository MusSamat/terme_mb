import 'package:easy_localization/easy_localization.dart';

import 'errors.dart';

/// Turns an API error into a friendly, localized message — 1:1 with the web
/// `friendlyError`: prefer a code-specific message (`api_error_codes.*`), then
/// the offline case, then the server message, then a generic fallback.
String friendlyError(Object error) {
  final e = extractError(error);

  if (e.code == AppException.networkOffline) return 'offline.no_connection'.tr();

  // Code-specific dictionary (api_error_codes.SEATS_NOT_AVAILABLE, …).
  final codeKey = 'api_error_codes.${e.code}';
  final codeMsg = codeKey.tr();
  if (codeMsg != codeKey) return codeMsg;

  // Server-provided message (already localized on the backend).
  if (e.message.isNotEmpty) return e.message;

  return 'errors.global_desc'.tr();
}
