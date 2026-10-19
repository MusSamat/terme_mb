import 'dart:async';
import 'dart:math' as math;

/// What a socket drop / handshake rejection asks the client to do.
enum SocketRecovery {
  /// Token expired / rejected → refresh it, then reconnect.
  refresh,

  /// Transient server-side cap (too many connections) → retry with backoff.
  retry,

  /// Blocked / forbidden → stay disconnected.
  stop,

  /// Not ours (transport errors) — socket.io's own reconnection handles them.
  ignore,
}

/// Classifies a handshake rejection. The server's middleware errors arrive as
/// `{message: ...}`: `auth_required`, `auth_failed`, `forbidden`,
/// `too_many_connections`, or an AppError message («Access token has expired»
/// for TOKEN_EXPIRED, «Authentication required» for an invalid token).
SocketRecovery classifyHandshakeError(dynamic data) {
  final raw = data is Map ? (data['message'] ?? data['code'] ?? '') : (data ?? '');
  final msg = raw.toString().toLowerCase();
  if (msg.contains('forbidden') || msg.contains('blocked')) return SocketRecovery.stop;
  if (msg.contains('too_many_connections')) return SocketRecovery.retry;
  if (msg.contains('token_expired') ||
      msg.contains('token has expired') ||
      msg.contains('auth_required') ||
      msg.contains('auth_failed') ||
      msg.contains('authentication required')) {
    return SocketRecovery.refresh;
  }
  return SocketRecovery.ignore;
}

/// Classifies a `disconnect` reason. Only a server-initiated drop (token
/// expiry, blocked user) needs us: socket.io never reconnects it by itself.
SocketRecovery classifyDisconnect(dynamic reason) =>
    reason?.toString() == 'io server disconnect' ? SocketRecovery.refresh : SocketRecovery.ignore;

typedef ReauthScheduler = Timer Function(Duration delay, void Function() callback);

/// Socket re-auth with backoff: refresh the access token (shared single-flight
/// with HTTP) → reconnect with it. One recovery at a time, exponential delays,
/// capped attempts (reset on a successful connect), and nothing at all while
/// the app doesn't want a socket (logged out) or once a refresh fails — the
/// auth layer then runs the normal logout.
class SocketReauth {
  SocketReauth({
    required this.refresh,
    required this.currentToken,
    required this.reconnect,
    required this.wanted,
    ReauthScheduler? schedule,
    this.maxAttempts = 6,
  }) : _schedule = schedule ?? Timer.new;

  final Future<String?> Function() refresh;
  final String? Function() currentToken;
  final void Function(String token) reconnect;
  final bool Function() wanted;
  final int maxAttempts;
  final ReauthScheduler _schedule;

  static const _base = Duration(seconds: 1);
  static const _max = Duration(seconds: 30);

  int _attempts = 0;
  Timer? _timer;
  bool _busy = false;

  int get attempts => _attempts;
  bool get pending => _timer != null || _busy;

  /// 0 → immediately, then 1s, 2s, 4s … capped at 30s.
  static Duration delayFor(int attempt) {
    if (attempt <= 0) return Duration.zero;
    final ms = _base.inMilliseconds * math.pow(2, attempt - 1).toInt();
    return Duration(milliseconds: math.min(ms, _max.inMilliseconds));
  }

  void onConnected() {
    _attempts = 0;
    _cancelTimer();
  }

  /// Logged out / socket no longer wanted.
  void reset() {
    _attempts = 0;
    _cancelTimer();
  }

  void handle(SocketRecovery action) {
    if (action == SocketRecovery.refresh) recover(refreshToken: true);
    if (action == SocketRecovery.retry) recover(refreshToken: false);
  }

  void recover({required bool refreshToken}) {
    if (!wanted() || pending || _attempts >= maxAttempts) return;
    final delay = delayFor(_attempts++);
    _timer = _schedule(delay, () {
      _timer = null;
      unawaited(_run(refreshToken));
    });
  }

  Future<void> _run(bool refreshToken) async {
    if (!wanted()) return;
    _busy = true;
    String? token;
    try {
      token = refreshToken ? await refresh() : currentToken();
    } catch (_) {
      token = null;
    } finally {
      _busy = false;
    }
    if (token == null || !wanted()) return;
    reconnect(token);
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
