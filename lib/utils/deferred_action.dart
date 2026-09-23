import 'package:hive/hive.dart';

import 'config.dart';

/// Guest → login → resume. A protected action taken while anonymous is saved to
/// Hive before redirecting to the login screen; after a successful login the
/// login screen reads it back (within the TTL) and resumes the intent.
///
/// Payload shape: { "type": String, "payload": Map, "ts": int(ms since epoch) }.
class DeferredAction {
  const DeferredAction({required this.type, required this.payload});
  final String type;
  final Map<String, dynamic> payload;
}

/// 15-minute window (mirrors the web mini-app deferred-action TTL).
const _ttl = Duration(minutes: 15);

/// Persist an intent to resume after login. [payload] must be JSON-primitive.
void saveDeferredAction(Box<dynamic> box, {required String type, Map<String, dynamic> payload = const {}}) {
  box.put(StorageKeys.deferredAction, <String, dynamic>{
    'type': type,
    'payload': payload,
    'ts': DateTime.now().millisecondsSinceEpoch,
  });
}

/// Read and clear the saved intent. Returns null when absent, malformed, or
/// past its TTL — callers just fall through to their default (home).
DeferredAction? takeDeferredAction(Box<dynamic> box) {
  final raw = box.get(StorageKeys.deferredAction);
  box.delete(StorageKeys.deferredAction);
  if (raw is! Map) return null;
  final type = raw['type'];
  final ts = raw['ts'];
  if (type is! String || type.isEmpty || ts is! int) return null;
  if (DateTime.now().millisecondsSinceEpoch - ts > _ttl.inMilliseconds) return null;
  final payload = raw['payload'];
  return DeferredAction(
    type: type,
    payload: payload is Map ? payload.cast<String, dynamic>() : const {},
  );
}
