import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:terme_mb/socket/socket_reauth.dart';

/// Captures scheduled callbacks so the test fires them by hand (no real timers).
class _Clock {
  final delays = <Duration>[];
  final _pending = <void Function()>[];

  Timer schedule(Duration d, void Function() cb) {
    delays.add(d);
    _pending.add(cb);
    return _FakeTimer(() => _pending.remove(cb));
  }

  Future<void> fire() async {
    final cbs = [..._pending];
    _pending.clear();
    for (final cb in cbs) {
      cb();
    }
    await Future<void>.delayed(Duration.zero);
  }

  int get queued => _pending.length;
}

class _FakeTimer implements Timer {
  _FakeTimer(this._onCancel);
  final void Function() _onCancel;
  bool _active = true;
  @override
  void cancel() {
    _active = false;
    _onCancel();
  }

  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
}

void main() {
  group('classifyHandshakeError', () {
    test('expired / rejected tokens → refresh', () {
      expect(classifyHandshakeError({'message': 'Access token has expired'}), SocketRecovery.refresh);
      expect(classifyHandshakeError({'message': 'TOKEN_EXPIRED'}), SocketRecovery.refresh);
      expect(classifyHandshakeError('auth_required'), SocketRecovery.refresh);
      expect(classifyHandshakeError({'message': 'auth_failed'}), SocketRecovery.refresh);
      expect(classifyHandshakeError({'message': 'Authentication required'}), SocketRecovery.refresh);
    });
    test('blocked user → stop; connection cap → retry; transport noise → ignore', () {
      expect(classifyHandshakeError({'message': 'forbidden'}), SocketRecovery.stop);
      expect(classifyHandshakeError({'message': 'too_many_connections'}), SocketRecovery.retry);
      expect(classifyHandshakeError('websocket error'), SocketRecovery.ignore);
      expect(classifyHandshakeError(null), SocketRecovery.ignore);
    });
  });

  group('classifyDisconnect', () {
    test('only a server-initiated drop needs re-auth', () {
      expect(classifyDisconnect('io server disconnect'), SocketRecovery.refresh);
      expect(classifyDisconnect('io client disconnect'), SocketRecovery.ignore);
      expect(classifyDisconnect('transport close'), SocketRecovery.ignore);
    });
  });

  group('SocketReauth', () {
    late _Clock clock;
    late bool wanted;
    late List<String> reconnected;
    late int refreshCalls;
    late Future<String?> Function() refreshImpl;
    late SocketReauth reauth;

    setUp(() {
      clock = _Clock();
      wanted = true;
      reconnected = [];
      refreshCalls = 0;
      refreshImpl = () async => 'fresh';
      reauth = SocketReauth(
        refresh: () {
          refreshCalls++;
          return refreshImpl();
        },
        currentToken: () => 'current',
        reconnect: reconnected.add,
        wanted: () => wanted,
        schedule: clock.schedule,
      );
    });

    test('auth:expired + server disconnect → ONE refresh, then reconnect with the new token', () async {
      reauth.recover(refreshToken: true); // auth:expired
      reauth.handle(classifyDisconnect('io server disconnect')); // the drop right after
      expect(clock.queued, 1);
      await clock.fire();
      expect(refreshCalls, 1);
      expect(reconnected, ['fresh']);
    });

    test('backoff grows 0 → 1s → 2s … capped at 30s', () {
      expect(SocketReauth.delayFor(0), Duration.zero);
      expect(SocketReauth.delayFor(1), const Duration(seconds: 1));
      expect(SocketReauth.delayFor(2), const Duration(seconds: 2));
      expect(SocketReauth.delayFor(4), const Duration(seconds: 8));
      expect(SocketReauth.delayFor(10), const Duration(seconds: 30));
    });

    test('repeated handshake failures back off and stop after maxAttempts (no tight loop)', () async {
      for (var i = 0; i < 10; i++) {
        reauth.handle(SocketRecovery.refresh);
        await clock.fire();
      }
      expect(refreshCalls, reauth.maxAttempts);
      expect(clock.delays.first, Duration.zero);
      expect(clock.delays[1], const Duration(seconds: 1));
      expect(clock.delays.last, SocketReauth.delayFor(reauth.maxAttempts - 1));
    });

    test('a successful connect resets the backoff', () async {
      reauth.handle(SocketRecovery.refresh);
      await clock.fire();
      reauth.handle(SocketRecovery.refresh);
      await clock.fire();
      expect(reauth.attempts, 2);
      reauth.onConnected();
      expect(reauth.attempts, 0);
      reauth.handle(SocketRecovery.refresh);
      expect(clock.delays.last, Duration.zero);
    });

    test('refresh failure → no reconnect (the auth layer logs out)', () async {
      refreshImpl = () async => throw Exception('401');
      reauth.recover(refreshToken: true);
      await clock.fire();
      expect(reconnected, isEmpty);

      refreshImpl = () async => null; // guest / dead session
      reauth.recover(refreshToken: true);
      await clock.fire();
      expect(reconnected, isEmpty);
    });

    test('logged out → nothing scheduled, and a pending recovery is dropped', () async {
      wanted = false;
      reauth.recover(refreshToken: true);
      expect(clock.queued, 0);

      wanted = true;
      reauth.recover(refreshToken: true);
      wanted = false; // logout before the timer fires
      reauth.reset();
      await clock.fire();
      expect(refreshCalls, 0);
      expect(reconnected, isEmpty);
    });

    test('logout during the refresh → no reconnect', () async {
      final gate = Completer<String?>();
      refreshImpl = () => gate.future;
      reauth.recover(refreshToken: true);
      await clock.fire();
      wanted = false;
      gate.complete('fresh');
      await Future<void>.delayed(Duration.zero);
      expect(reconnected, isEmpty);
    });

    test('connection cap → retry with the current token, no refresh', () async {
      reauth.handle(SocketRecovery.retry);
      await clock.fire();
      expect(refreshCalls, 0);
      expect(reconnected, ['current']);
    });

    test('blocked / ignored reasons schedule nothing', () {
      reauth.handle(SocketRecovery.stop);
      reauth.handle(SocketRecovery.ignore);
      expect(clock.queued, 0);
    });
  });
}
