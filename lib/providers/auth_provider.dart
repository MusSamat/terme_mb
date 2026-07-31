import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/self_user.dart';
import '../theme/role_theme.dart';
import '../utils/config.dart';
import 'core_providers.dart';

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

  void setActiveMode(ActiveMode mode) {
    state = state.copyWith(activeMode: mode);
    _box.put(StorageKeys.activeMode, mode.name);
  }

  /// Called after a successful login/refresh once the SelfUser is loaded.
  void setSession(SelfUser user, {String? accessToken}) {
    if (accessToken != null) {
      ref.read(tokenStoreProvider).set(accessToken);
    }
    _box.put(StorageKeys.sessionHint, '1');
    state = state.copyWith(
      status: AuthStatus.authenticated,
      user: user,
      activeMode: _resolveMode(user),
    );
  }

  void updateUser(SelfUser user) => state = state.copyWith(user: user);

  void clearSession() {
    ref.read(tokenStoreProvider).clear();
    _box.delete(StorageKeys.sessionHint);
    state = AuthState(status: AuthStatus.anonymous, activeMode: state.activeMode);
  }

  ActiveMode _resolveMode(SelfUser user) {
    // Keep stored preference if the user can act in that mode, else fall back.
    if (state.activeMode == ActiveMode.driver && user.isDriver) return ActiveMode.driver;
    if (user.isDriver && !user.isPassenger) return ActiveMode.driver;
    return ActiveMode.passenger;
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
