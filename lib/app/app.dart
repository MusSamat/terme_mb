import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../providers/presence_provider.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/app_toast.dart';
import '../widgets/logo_mark.dart';
import '../widgets/offline_banner.dart';
import '../widgets/role_switch_overlay.dart';
import 'router.dart';

class TermeApp extends ConsumerWidget {
  const TermeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(apiBootstrapProvider); // attach dio refresh → auth/token store
    ref.watch(socketBootstrapProvider); // live socket (notifications/chat/bookings)
    ref.watch(presenceBootstrapProvider); // presence heartbeat (online counter)

    return MaterialApp.router(
      title: 'Terme',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Kyrgyz: the app (mirroring the web) uses the code `kg`, but Flutter's
      // bundled localizations register Kyrgyz as `ky`. Without these shims,
      // MaterialLocalizations.of() has no data for `kg` and any widget that needs
      // it (bottom sheets, tooltips, text-field selection…) throws — silently
      // killing taps on that subtree. Prepended so they win over the globals.
      localizationsDelegates: [
        const _KgMaterialDelegate(),
        const _KgCupertinoDelegate(),
        const _KgWidgetsDelegate(),
        ...context.localizationDelegates,
      ],
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const OfflineBanner(),
          const ToastOverlay(),
          // Full-screen loader while the session is being restored — hides the
          // login/guest UI so a cold start never flashes it. Skipped entirely
          // when the cached profile hydrated us straight to authenticated.
          const _StartupGate(),
          // Brief animated loader when the user flips Пассажир ⇄ Водитель.
          const _RoleSwitchGate(),
        ],
      ),
    );
  }
}

/// Branded full-screen loader shown while auth is `idle`/`loading` (cold-start
/// session restore). Invisible once resolved — including the optimistic-hydrate
/// path, which jumps straight to `authenticated` and never touches this.
class _StartupGate extends ConsumerWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authProvider.select((s) => s.status));
    if (status != AuthStatus.idle && status != AuthStatus.loading) {
      return const SizedBox.shrink();
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: ColoredBox(
        color: dark ? InkColors.c950 : InkColors.c50,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoMark(size: 72),
              SizedBox(height: 22),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Watches the active role and, when it flips, shows [RoleSwitchOverlay] for a
/// short beat (~1.5s) so the mode change reads as a deliberate transition.
class _RoleSwitchGate extends ConsumerStatefulWidget {
  const _RoleSwitchGate();

  @override
  ConsumerState<_RoleSwitchGate> createState() => _RoleSwitchGateState();
}

class _RoleSwitchGateState extends ConsumerState<_RoleSwitchGate> {
  bool _show = false;
  bool _targetDriver = false;
  Timer? _timer;

  void _trigger(bool driver) {
    _timer?.cancel();
    setState(() {
      _show = true;
      _targetDriver = driver;
    });
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fire only on an actual change (skip the initial null → value resolve).
    ref.listen<ActiveMode>(authProvider.select((s) => s.activeMode),
        (prev, next) {
      if (prev != null && prev != next) {
        _trigger(next == ActiveMode.driver);
      }
    });
    if (!_show) return const SizedBox.shrink();
    return RoleSwitchOverlay(driver: _targetDriver);
  }
}

/// Flutter's built-in localizations key Kyrgyz as `ky`; this app uses `kg`.
/// These shims load the `ky` framework data whenever the app locale is `kg`
/// (and pass every other locale straight through), so MaterialLocalizations /
/// CupertinoLocalizations / WidgetsLocalizations resolve for Kyrgyz.
Locale _frameworkLocale(Locale l) => l.languageCode == 'kg' ? const Locale('ky') : l;

class _KgMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _KgMaterialDelegate();
  @override
  bool isSupported(Locale locale) => GlobalMaterialLocalizations.delegate.isSupported(_frameworkLocale(locale));
  @override
  Future<MaterialLocalizations> load(Locale locale) => GlobalMaterialLocalizations.delegate.load(_frameworkLocale(locale));
  @override
  bool shouldReload(_KgMaterialDelegate old) => false;
}

class _KgCupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _KgCupertinoDelegate();
  @override
  bool isSupported(Locale locale) => GlobalCupertinoLocalizations.delegate.isSupported(_frameworkLocale(locale));
  @override
  Future<CupertinoLocalizations> load(Locale locale) => GlobalCupertinoLocalizations.delegate.load(_frameworkLocale(locale));
  @override
  bool shouldReload(_KgCupertinoDelegate old) => false;
}

class _KgWidgetsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _KgWidgetsDelegate();
  @override
  bool isSupported(Locale locale) => GlobalWidgetsLocalizations.delegate.isSupported(_frameworkLocale(locale));
  @override
  Future<WidgetsLocalizations> load(Locale locale) => GlobalWidgetsLocalizations.delegate.load(_frameworkLocale(locale));
  @override
  bool shouldReload(_KgWidgetsDelegate old) => false;
}
