import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:terme_mb/providers/auth_provider.dart';
import 'package:terme_mb/providers/core_providers.dart';
import 'package:terme_mb/models/self_user.dart';
import 'package:terme_mb/screens/screens.dart';

/// Renders every screen and asserts no exception (layout errors like an
/// unbounded Expanded throw during pump — this catches them across all screens).
void main() {
  late Box<dynamic> box;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('tj_test');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('terme_test');
  });

  Widget wrap(Widget child, {bool driver = false}) {
    return EasyLocalization(
      supportedLocales: const [Locale('ru'), Locale('kg')],
      path: 'assets/l10n',
      fallbackLocale: const Locale('ru'),
      child: ProviderScope(
        overrides: [hiveBoxProvider.overrideWithValue(box)],
        child: _Harness(driver: driver, child: child),
      ),
    );
  }

  final screens = <String, Widget>{
    'home': const HomeFeedScreen(),
    'trip-detail': const TripDetailScreen(id: 't1'),
    'trip-detail-book': const TripDetailScreen(id: 't2'),
    'profile': const ProfileScreen(),
    'my-bookings': const MyBookingsScreen(),
    'chat-hub': const ChatHubScreen(),
    'chat-thread': const ChatThreadScreen(bookingId: 'b1'),
    'notifications': const NotificationsScreen(),
    'loyalty': const LoyaltyScreen(),
    'requests-feed': const RequestsFeedScreen(),
    'request-detail': const RequestDetailScreen(id: 'r1'),
    'rate': const RateScreen(tripId: 't1', rateeId: 'd1'),
    'complaint': const ComplaintScreen(),
    'create': const CreateScreen(),
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
    'onboarding': const OnboardingScreen(),
    'public-profile': const PublicProfileScreen(id: 'd1'),
    'driver-verification': const DriverVerificationScreen(),
    'legal': const LegalScreen(kind: 'about'),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders without exception', (tester) async {
      await tester.pumpWidget(wrap(entry.value));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '${entry.key} threw during render');
    });
  }
}

/// Seeds an authenticated session, then hosts the screen in a MaterialApp.
class _Harness extends ConsumerStatefulWidget {
  const _Harness({required this.child, required this.driver});
  final Widget child;
  final bool driver;

  @override
  ConsumerState<_Harness> createState() => _HarnessState();
}

class _HarnessState extends ConsumerState<_Harness> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).setSession(
            SelfUser(
              id: 'u1',
              name: 'Тест',
              roles: widget.driver ? const ['passenger', 'driver'] : const ['passenger'],
              phone: '+996700000000',
              phoneVerified: true,
              telegramLinked: true,
              language: 'ru',
              rating: 4.8,
              ratingCount: 20,
            ),
            accessToken: 'test',
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: widget.child,
    );
  }
}
