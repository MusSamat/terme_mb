import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/self_user.dart';
import '../theme/role_theme.dart';
import '../utils/config.dart';
import 'core_providers.dart';
import 'data_providers.dart' show profileServiceProvider;

enum AuthStatus { idle, loading, authenticated, anonymous }

enum ActiveMode { passenger, driver }

class AuthState {
  const AuthState({
    required this.status,
    required this.activeMode,
    this.user,
  });

  final AuthStatus status;
  final ActiveMode activeMode;
  final SelfUser? user;

  const AuthState.initial()
      : status = AuthStatus.idle,
        activeMode = ActiveMode.passenger,
        user = null;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({AuthStatus? status, ActiveMode? activeMode, SelfUser? user}) {
    return AuthState(
      status: status ?? this.status,
      activeMode: activeMode ?? this.activeMode,
      user: user ?? this.user,
    );
  }
}

/// Mirror of the web Zustand `useAuth` store.
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final box = ref.watch(hiveBoxProvider);
    final mode = _parseMode(box.get(StorageKeys.activeMode) as String?);
    return AuthState(status: AuthStatus.idle, activeMode: mode);
  }

  Box<dynamic> get _box => ref.read(hiveBoxProvider);

  void setStatus(AuthStatus status) => state = state.copyWith(status: status);

  /// The one place the mode changes. Signed in → saved as users.preferredMode
  /// (same mode on web, mobile and the Telegram bot); guests keep it locally.
  void setActiveMode(ActiveMode mode) {
    if (mode == state.activeMode) return;
    state = state.copyWith(activeMode: mode, user: state.user?.copyWith(preferredMode: mode.name));
    _box.put(StorageKeys.activeMode, mode.name);
    if (state.isAuthenticated) {
      unawaited(ref
          .read(profileServiceProvider)
          .update(preferredMode: mode.name)
          .then<void>((_) {}, onError: (_) {/* local choice stands; next save retries */}));
    }
  }

  /// Called after a successful login/refresh once the SelfUser is loaded.
  void setSession(SelfUser user, {String? accessToken}) {
    if (accessToken != null) {
      ref.read(tokenStoreProvider).set(accessToken);
    }
    _box.put(StorageKeys.sessionHint, '1');
    // Cache the profile so the next cold start can render the logged-in shell
    // instantly (optimistic hydrate) before the network refresh completes.
    _box.put(StorageKeys.cachedUser, jsonEncode(user.toJson()));
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      activeMode: _resolveMode(user),
    );
  }

  void updateUser(SelfUser user) => state = state.copyWith(user: user);

  /// Last known profile, for optimistic hydrate on cold start. Null if none or
  /// unparseable.
  SelfUser? readCachedUser() {
    try {
      final raw = _box.get(StorageKeys.cachedUser) as String?;
      if (raw == null) return null;
      return SelfUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  void clearSession() {
    ref.read(tokenStoreProvider).clear();
    // Drop the persisted refresh cookie so a restart can't silently re-login.
    unawaited(ref.read(dioClientProvider).cookieJar.deleteAll());
    _box.delete(StorageKeys.sessionHint);
    _box.delete(StorageKeys.cachedUser);
    state = AuthState(status: AuthStatus.anonymous, activeMode: state.activeMode);
  }

  // The server-side preference wins once signed in (it's shared across clients).
  ActiveMode _resolveMode(SelfUser user) {
    final mode = _parseMode(user.preferredMode);
    _box.put(StorageKeys.activeMode, mode.name);
    return mode;
  }

  static ActiveMode _parseMode(String? v) =>
      v == 'driver' ? ActiveMode.driver : ActiveMode.passenger;
}

/// Current UI role: guest when anonymous, else passenger/driver by active mode.
final uiRoleProvider = Provider<UiRole>((ref) {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return UiRole.guest;
  return auth.activeMode == ActiveMode.driver ? UiRole.driver : UiRole.passenger;
});

final roleThemeProvider = Provider<RoleTheme>((ref) {
  return roleThemeFor(ref.watch(uiRoleProvider));
});
