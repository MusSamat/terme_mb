import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../widgets/pill_nav.dart';

/// Hosts the four main tab branches and the floating pill nav.
/// The nav hides itself when the keyboard is open (per ТЗ §6.2).
class RootShell extends ConsumerWidget {
  const RootShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(authProvider).isAuthenticated;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      // Let the pill float over content; content adds its own bottom clearance.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: keyboardOpen
          ? null
          : PillNav(
              currentIndex: navigationShell.currentIndex,
              onSelect: (i) => _onSelect(context, i, authed),
              onCreate: () => context.push('/trips/create'),
              // TODO: wire real unread count from unreadProvider.
              chatUnread: 0,
            ),
    );
  }

  void _onSelect(BuildContext context, int index, bool authed) {
    if (!authed) {
      if (index == 0) {
        navigationShell.goBranch(0);
      } else {
        context.push('/auth/login');
      }
      return;
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
