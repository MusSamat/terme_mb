import 'package:easy_localization/easy_localization.dart';

import 'errors.dart';

/// Turns an API error into a friendly, localized message — 1:1 with the web
/// `friendlyError`: prefer a code-specific message (`api_error_codes.*`), then
/// the offline case, then the server message, then a generic fallback.
String friendlyError(Object error) {
  final e = extractError(error);

  if (e.code == AppException.networkOffline) return 'offline.no_connection'.tr();
  if (e.code == AppException.rateLimited) return _rateLimited(e);

  return _message(e);
}

String _message(AppException e) {
  // Reason-specific message FIRST (api_errors.cannot_book_own_trip, …) — the
  // backend puts the actionable detail in details.reason, so it's more useful
  // than the generic code. Mirrors the web friendlyError priority.
  final reason = e.details?['reason']?.toString();
  if (reason != null && reason.isNotEmpty) {
    final reasonKey = 'api_errors.$reason';
    final reasonMsg = reasonKey.tr();
    if (reasonMsg != reasonKey) return reasonMsg;
  }

  // Code-specific dictionary (api_error_codes.SEATS_NOT_AVAILABLE, …).
  final codeKey = 'api_error_codes.${e.code}';
  final codeMsg = codeKey.tr();
  if (codeMsg != codeKey) return codeMsg;

  // Server-provided message (already localized on the backend).
  if (e.message.isNotEmpty) return e.message;

  return 'errors.global_desc'.tr();
}

/// 429: a bucket-specific text when we have one (OTP send / verify caps,
/// contact reveals), else the generic one — plus «Осталось N сек./мин.» when
/// the server sent Retry-After and the wait is short enough to be useful.
String _rateLimited(AppException e) {
  final bucket = e.rateLimitBucket;
  var base = '';
  if (bucket != null && bucket.isNotEmpty) {
    final key = 'api_rate_limits.$bucket';
    final msg = key.tr();
    if (msg != key) base = msg;
  }
  if (base.isEmpty) base = _message(e);
  final wait = retryWaitText(e.retryAfter);
  return wait == null ? base : '$base $wait';
}

/// «Осталось 42 сек.» / «Осталось 12 мин.»; null without a usable wait (none,
/// or over an hour — the daily caps say «завтра» themselves).
String? retryWaitText(int? seconds) {
  if (seconds == null || seconds <= 0 || seconds > 3600) return null;
  if (seconds < 120) return 'rate_limit.left_sec'.tr(namedArgs: {'n': '$seconds'});
  return 'rate_limit.left_min'.tr(namedArgs: {'n': '${(seconds / 60).ceil()}'});
}
