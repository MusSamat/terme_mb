import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/role_theme.dart';
import '../../widgets/logo_mark.dart';

/// Welcome / onboarding — port of tappjet_ft welcome-screen. The two role
/// buttons save the first-selected role (activeMode) and enter the app.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  // Enter the app in [mode], persisting it as the default role everywhere.
  void _continueAs(BuildContext context, WidgetRef ref, ActiveMode mode) {
    ref.read(authProvider.notifier).setActiveMode(mode);
    context.go('/');
  }

  Widget _roleButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = roleThemeFor(UiRole.passenger);
    final chips = [
      'welcome.chip_verified'.tr(),
      'welcome.chip_cheap'.tr(),
      'welcome.chip_fast'.tr(),
      'welcome.chip_chat'.tr(),
    ];

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: role.headerGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const LogoMark(plain: true, size: 88),
                const SizedBox(height: 20),
                Text('welcome.title'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: 10),
                Text('welcome.subtitle'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.9))),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in chips)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(c,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                  ],
                ),
                const Spacer(),
                Column(
                  children: [
                    _roleButton(
                      icon: Icons.person,
                      label: 'welcome.cta_passenger'.tr(),
                      color: BrandColors.c600,
                      onTap: () =>
                          _continueAs(context, ref, ActiveMode.passenger),
                    ),
                    const SizedBox(height: 10),
                    _roleButton(
                      icon: Icons.directions_car_filled,
                      label: 'welcome.cta_driver'.tr(),
                      color: GrapeColors.c600,
                      onTap: () => _continueAs(context, ref, ActiveMode.driver),
                    ),
                    const SizedBox(height: 10),
                    // Returning users can jump straight to sign-in.
                    TextButton(
                      onPressed: () => context.go('/auth/login'),
                      child: Text('welcome.cta_primary'.tr(),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
