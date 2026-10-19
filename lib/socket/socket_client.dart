import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../utils/config.dart';
import '../api/token_store.dart';
import 'socket_reauth.dart';

/// Thin wrapper over socket.io — websocket-only transport, manual connect,
/// exponential backoff, and token re-auth on every (re)connect.
/// Mirrors terme_ft/src/lib/socket/client.ts.
///
/// The server drops a socket when its access token expires (`auth:expired`,
/// then 'io server disconnect'), when the user gets blocked, and rejects
/// handshakes with expired tokens / over the per-user cap. socket.io doesn't
/// recover any of those by itself — [SocketReauth] refreshes the token via
/// [refresh] (the shared HTTP single-flight) and reconnects with backoff.
class SocketClient {
  SocketClient(this._tokens, {Future<String?> Function()? refresh}) {
    _reauth = SocketReauth(
      refresh: refresh ?? () async => null,
      currentToken: () => _tokens.accessToken,
      reconnect: _reconnectWith,
      wanted: () => _wanted,
    );
    // Re-authenticate the socket whenever the access token changes.
    _tokenSub = _tokens.onRefreshed.listen((_) => refreshAuth());
  }

  late final StreamSubscription<String?> _tokenSub;
  late final SocketReauth _reauth;

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

    s.onConnect((_) {
      _connecting = false;
      _reauth.onConnected();
    });
    // Middleware rejections arrive as 'error' in this client version (and as
    // 'connect_error' in others) — handle both the same way.
    void onHandshakeError(dynamic data) {
      _connecting = false;
      _reauth.handle(classifyHandshakeError(data));
    }

    s.onConnectError(onHandshakeError);
    s.onError(onHandshakeError);
    // The server announces expiry right before it drops the socket.
    s.on('auth:expired', (_) => _reauth.recover(refreshToken: true));
    s.onDisconnect((reason) {
      _connecting = false;
      _reauth.handle(classifyDisconnect(reason));
    });

    return s;
  }

  // True between connect() and disconnect(): the app wants a live socket.
  bool _wanted = false;
  // A connect() is in flight — a second one would send a duplicate CONNECT.
  bool _connecting = false;

  void _stamp(io.Socket s) => s.auth = {'token': _tokens.accessToken};

  void _open(io.Socket s) {
    if (s.connected || _connecting) return;
    _connecting = true;
    s.connect();
  }

  void connect() {
    _wanted = true;
    // No token yet (cold start before the first refresh) → refreshAuth connects
    // once it lands; connecting bare would only bounce with auth_required.
    if (_tokens.accessToken == null) return;
    final s = socket;
    _stamp(s);
    _open(s);
  }

  void disconnect() {
    _wanted = false;
    _connecting = false;
    _reauth.reset();
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
      s.disconnect(); // fires 'disconnect' (client reason) synchronously
      _connecting = true;
      s.connect();
    } else {
      _open(s);
    }
  }

  // Recovery path: the refresh normally already reconnected via refreshAuth
  // (TokenStore.onRefreshed); this only covers a token that didn't change.
  void _reconnectWith(String token) {
    if (!_wanted) return;
    final s = socket;
    s.auth = {'token': token};
    _open(s);
  }

  void dispose() {
    _tokenSub.cancel();
    _reauth.reset();
    _socket?.dispose();
    _socket = null;
  }
}
