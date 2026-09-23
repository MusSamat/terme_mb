import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../widgets/pill_nav.dart';
import '../widgets/role_select_sheet.dart';

/// Hosts the four main tab branches and the floating pill nav.
/// The nav hides itself when the keyboard is open (per ТЗ §6.2).
class RootShell extends ConsumerWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authProvider).status;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    // Live unread chat count for the nav badge (0 when logged out).
    final chatUnread = status == AuthStatus.authenticated ? (ref.watch(unreadChatProvider).valueOrNull ?? 0) : 0;

    return Scaffold(
      // Let the pill float over content; content adds its own bottom clearance.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: keyboardOpen
          ? null
          : PillNav(
              currentIndex: navigationShell.currentIndex,
              // Divert to login ONLY when definitively anonymous — while auth is
              // still resolving (idle/loading on cold start or token refresh) the
              // tab must still switch, otherwise «Мои» silently no-ops / bounces
              // to login for a logged-in user.
              onSelect: (i) => _onSelect(context, i, status == AuthStatus.anonymous),
              // One «+», two outcomes — ask «поездка (водитель) / заявка
              // (пассажир)», set the mode, then open the create form.
              onCreate: () => showRoleSelectSheet(context, ref, create: true),
              chatUnread: chatUnread,
            ),
    );
  }

  void _onSelect(BuildContext context, int index, bool anon) {
    if (anon && index != 0) {
      context.push('/auth/login');
      return;
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
