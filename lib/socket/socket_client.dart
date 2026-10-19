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
          .build(),
    );

    s.onConnectError((data) {
      final msg = data?.toString() ?? '';
      // Auth rejected by the server middleware (expired / missing token): socket.io
      // won't retry by itself. Don't loop on the same token — the next refresh
      // (TokenStore.onRefreshed → refreshAuth) reconnects with a fresh one.
      if ((msg.contains('auth_required') || msg.contains('auth_failed')) &&
          _tokens.accessToken != null &&
          _tokens.accessToken != _authToken) {
        _stamp(s);
        s.connect();
      }
    });

    return s;
  }

  // True between connect() and disconnect(): the app wants a live socket.
  bool _wanted = false;
  String? _authToken;

  void _stamp(io.Socket s) {
    _authToken = _tokens.accessToken;
    s.auth = {'token': _authToken};
  }

  void connect() {
    _wanted = true;
    // No token yet (cold start before the first refresh) → refreshAuth connects
    // once it lands; connecting bare would only bounce with auth_required.
    if (_tokens.accessToken == null) return;
    final s = socket;
    _stamp(s);
    if (!s.connected) s.connect();
  }

  void disconnect() {
    _wanted = false;
    _socket?.disconnect();
  }

  bool get connected => _socket?.connected ?? false;

  // Listener / emit passthroughs (used by the global listener + chat thread).
  void on(String event, void Function(dynamic) handler) => socket.on(event, handler);
  void off(String event, [void Function(dynamic)? handler]) => _socket?.off(event, handler);
  void emit(String event, [dynamic data]) => _socket?.emit(event, data);

  void refreshAuth() {
    if (!_wanted || _tokens.accessToken == null) return;
    final s = socket;
    _stamp(s);
    // Reconnect with the new token (mirrors web refreshSocketAuth).
    if (s.connected) {
      s.disconnect().connect();
    } else {
      s.connect();
    }
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
