import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../providers/data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/offline_banner.dart';
import 'router.dart';

class TappjetApp extends ConsumerWidget {
  const TappjetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(apiBootstrapProvider); // attach dio refresh → auth/token store

    return MaterialApp.router(
      title: 'Tappjet',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          const OfflineBanner(),
          const ToastOverlay(),
        ],
      ),
    );
  }
}
