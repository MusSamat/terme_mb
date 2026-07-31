import 'package:socket_io_client/socket_io_client.dart' as io;

import '../utils/config.dart';
import '../api/token_store.dart';

/// Thin wrapper over socket.io — websocket-only transport, manual connect,
/// exponential backoff, and token re-auth on every (re)connect.
/// Mirrors tappjet_ft/src/lib/socket/client.ts.
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

  void connect() => socket.connect();
  void disconnect() => _socket?.disconnect();

  void refreshAuth() {
    final s = _socket;
    if (s == null) return;
    s.auth = {'token': _tokens.accessToken};
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
