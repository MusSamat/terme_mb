import 'package:socket_io_client/socket_io_client.dart' as io;

import '../utils/config.dart';
import '../api/token_store.dart';

/// Thin wrapper over socket.io — websocket-only transport, manual connect,
/// exponential backoff, and token re-auth on every (re)connect.
/// Mirrors terme_ft/src/lib/socket/client.ts.
class SocketClient {
  SocketClient(this._tokens) {
    // Re-authenticate the socket whenever the access token changes.
    _tokens.onRefreshed.listen((_) => refreshAuth());
  }

  final TokenStore _tokens;
  io.Socket? _socket;

  io.Socket get socket => _socket ??= _create();

  io.Socket _create() {
    final s = io.io(
      AppConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .enableReconnection()
          .setAuth({'token': _tokens.accessToken})
          .build(),
    );

    s.onConnectError((data) {
      final msg = data?.toString() ?? '';
      if (msg.contains('auth_required') || msg.contains('auth_failed')) {
        // The refresh happens in the dio layer; re-auth then reconnect.
        refreshAuth();
        s.connect();
      }
    });

    return s;
  }

  void connect() {
    final s = socket;
    // Always stamp the current token before connecting (the socket may have been
    // created before auth completed, or after a token refresh).
    s.auth = {'token': _tokens.accessToken};
    if (!s.connected) s.connect();
  }

  void disconnect() => _socket?.disconnect();

  bool get connected => _socket?.connected ?? false;

  // Listener / emit passthroughs (used by the global listener + chat thread).
  void on(String event, void Function(dynamic) handler) => socket.on(event, handler);
  void off(String event, [void Function(dynamic)? handler]) => _socket?.off(event, handler);
  void emit(String event, [dynamic data]) => _socket?.emit(event, data);

  void refreshAuth() {
    final s = _socket;
    if (s == null) return;
    s.auth = {'token': _tokens.accessToken};
    // Reconnect with the new token (mirrors web refreshSocketAuth).
    if (s.connected) s.disconnect().connect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
