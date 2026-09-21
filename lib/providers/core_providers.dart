import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../api/dio_client.dart';
import '../api/secure_cookie_storage.dart';
import '../api/token_store.dart';
import '../socket/socket_client.dart';
import '../utils/config.dart';

/// Opened in main() before runApp.
final hiveBoxProvider = Provider<Box<dynamic>>((ref) {
  throw UnimplementedError('hiveBoxProvider must be overridden in main()');
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  final store = TokenStore();
  ref.onDispose(store.dispose);
  return store;
});

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    ref.watch(tokenStoreProvider),
    cookieStorage: SecureCookieStorage(),
  );
});

final socketClientProvider = Provider<SocketClient>((ref) {
  final client = SocketClient(ref.watch(tokenStoreProvider));
  ref.onDispose(client.dispose);
  return client;
});

/// Theme mode, persisted in Hive (read synchronously to avoid first-frame flash).
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final box = ref.watch(hiveBoxProvider);
    return _parse(box.get(StorageKeys.theme) as String?);
  }

  void set(ThemeMode mode) {
    state = mode;
    ref.read(hiveBoxProvider).put(StorageKeys.theme, mode.name);
  }

  static ThemeMode _parse(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
