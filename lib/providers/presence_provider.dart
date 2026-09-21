import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import 'data_providers.dart';

/// Presence heartbeat — pings every 30s while authenticated. Watched once in
/// TermeApp (mirrors socketBootstrapProvider). The server throttles writes to
/// ~20s, so a 30s cadence is safe; OS suspends the timer while backgrounded.
final presenceBootstrapProvider = Provider<void>((ref) {
  Timer? timer;

  void beat() {
    if (ref.read(authProvider).isAuthenticated) {
      // Fire-and-forget; ignore transient/offline errors.
      ref.read(presenceServiceProvider).ping().catchError((_) {});
    }
  }

  void start() {
    beat();
    timer ??= Timer.periodic(const Duration(seconds: 30), (_) => beat());
  }

  void stop() {
    timer?.cancel();
    timer = null;
  }

  ref.listen<AuthState>(authProvider, (prev, next) {
    if (next.isAuthenticated) {
      start();
    } else {
      stop();
    }
  });

  if (ref.read(authProvider).isAuthenticated) start();
  ref.onDispose(stop);
});
