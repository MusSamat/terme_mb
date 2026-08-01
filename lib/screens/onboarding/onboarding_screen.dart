import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/role_theme.dart';
import '../../widgets/app_button.dart';
import '../../widgets/logo_mark.dart';

/// Welcome / onboarding — port of tappjet_ft welcome-screen.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                        fontFamily: 'Fredoka',
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
                Container(
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'welcome.cta_primary'.tr(),
                          onPressed: () => context.go('/auth/login'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: Text('welcome.cta_guest'.tr(),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
