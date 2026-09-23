import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/feed_filters.dart';
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
  // Watch ONLY the auth status — not the whole AuthState. Watching everything
  // rebuilt (recreated) the GoRouter on every activeMode change, resetting
  // navigation to initialLocation '/'. That's why picking a role in the create
  // sheet landed on the home hub instead of the create form.
  final status = ref.watch(authProvider.select((s) => s.status));

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/',
    redirect: (context, state) {
      // Only gate once we've resolved to a definite anonymous state — never
      // during idle/loading (avoids bouncing on cold start / silent refresh).
      if (status != AuthStatus.anonymous) return null;
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
            GoRoute(path: '/', builder: (c, s) => const HomeFeedScreen(), routes: [
              GoRoute(path: 'requests', builder: (c, s) => const RequestsFeedScreen()),
            ]),
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
        builder: (c, s) => const CreateScreen(),
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
        builder: (c, s) {
          final q = s.uri.queryParameters;
          return SearchResultsScreen(
            driver: q['mode'] == 'requests',
            openFilters: q['filters'] == '1',
            initial: FeedFilters(
              from: q['from'] ?? '',
              to: q['to'] ?? '',
              date: q['date'] ?? '',
              seats: int.tryParse(q['seats'] ?? ''),
            ),
          );
        },
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
        path: '/auth/register',
        // Auth is unified & passwordless — registration happens inside the login
        // flow (new number → name+surname). Keep the path as a redirect.
        redirect: (c, s) => '/auth/login',
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/onboarding',
        builder: (c, s) => const OnboardingScreen(),
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
});
