import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/feed_filters.dart';
import '../models/place.dart';
import '../providers/auth_provider.dart';
import '../screens/screens.dart';
import 'root_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Routes that require an authenticated session (ТЗ §6.1).
const _protectedPrefixes = <String>[
  '/trips/create',
  '/my',
  '/chat',
  '/profile',
  '/notifications',
  '/loyalty',
  '/complaint',
];

final routerProvider = Provider<GoRouter>((ref) {
  // ONE router for the app's lifetime. Recreating it on every auth change reset
  // navigation to '/' and orphaned navigation done right after login (the
  // deferred «book this trip» resume went to the discarded router). Auth changes
  // only re-run the redirect via refreshListenable.
  final authTick = ValueNotifier<int>(0);
  ref.onDispose(authTick.dispose);
  late final GoRouter router;
  ref.listen<AuthStatus>(authProvider.select((s) => s.status), (prev, next) {
    authTick.value++;
    // Signed out (logout, account deleted, forced logout): drop every screen —
    // incl. imperative sub-pages — and land on home, as a fresh start.
    if (prev == AuthStatus.authenticated && next == AuthStatus.anonymous) {
      _rootKey.currentState?.popUntil((r) => r.isFirst);
      router.go('/');
    }
  });

  router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    refreshListenable: authTick,
    redirect: (context, state) {
      // Only gate once we've resolved to a definite anonymous state — never
      // during idle/loading (avoids bouncing on cold start / silent refresh).
      if (ref.read(authProvider).status != AuthStatus.anonymous) return null;
      final loc = state.matchedLocation;
      final isProtected = _protectedPrefixes.any(loc.startsWith);
      if (isProtected) return '/auth/login';
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RootShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (c, s) => const HomeFeedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/my/bookings',
              builder: (c, s) => MyBookingsScreen(tab: s.uri.queryParameters['tab']),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/chat', builder: (c, s) => const ChatHubScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
          ]),
        ],
      ),

      // Full-screen routes (no pill nav).
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/trips/create',
        // ?kind=trip|request comes from the entry point («+», airport screen…);
        // without it the form follows the current mode. Optional prefill:
        // extra = CreatePrefill.
        builder: (c, s) => CreateScreen(
          kind: s.uri.queryParameters['kind'],
          prefill: s.extra is CreatePrefill ? s.extra as CreatePrefill : null,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/trips/:id',
        builder: (c, s) => TripDetailScreen(
          id: s.pathParameters['id']!,
          autoBook: s.uri.queryParameters['book'] == '1',
        ),
        routes: [
          GoRoute(
            path: 'rate/:rateeId',
            builder: (c, s) => RateScreen(
              tripId: s.pathParameters['id']!,
              rateeId: s.pathParameters['rateeId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/results',
        // Filters travel as `extra` (places are objects, not query strings).
        builder: (c, s) {
          final q = s.uri.queryParameters;
          return SearchResultsScreen(
            driver: q['mode'] == 'requests',
            openFilters: q['filters'] == '1',
            initial: s.extra is FeedFilters ? s.extra as FeedFilters : const FeedFilters(),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/map',
        // ?kind=trips|requests&ride=airport; extra = destination Place.
        builder: (c, s) => MapScreen(
          requests: s.uri.queryParameters['kind'] == 'requests',
          ride: s.uri.queryParameters['ride'],
          to: s.extra is Place ? s.extra as Place : null,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/airport',
        builder: (c, s) => const AirportScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/requests/:id',
        builder: (c, s) => RequestDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/my/bookings/:id/chat',
        builder: (c, s) => ChatThreadScreen(bookingId: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/profile/driver',
        builder: (c, s) => const DriverVerificationScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/profile/delete',
        builder: (c, s) => const DeleteAccountScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/notifications',
        builder: (c, s) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/loyalty',
        builder: (c, s) => const LoyaltyScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/complaint',
        builder: (c, s) => ComplaintScreen(
          userId: s.uri.queryParameters['user'],
          tripId: s.uri.queryParameters['trip'],
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/drivers/:id',
        builder: (c, s) => PublicProfileScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/auth/login',
        builder: (c, s) => const LoginScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/about',
        builder: (c, s) => const LegalScreen(kind: 'about'),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/privacy',
        builder: (c, s) => const LegalScreen(kind: 'privacy'),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/terms',
        builder: (c, s) => const LegalScreen(kind: 'terms'),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
