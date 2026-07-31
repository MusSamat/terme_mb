import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/self_user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';

/// Login — phone entry + Telegram (wired in ТЗ step 3). For now the real auth
/// is stubbed; the DEV block below fakes a session so the authed app (5-tab
/// nav, «Мои», «Чаты», «Профиль») is navigable. Remove when auth lands.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    void devLogin(ActiveMode mode) {
      final user = SelfUser(
        id: 'dev-user',
        name: mode == ActiveMode.driver ? 'Дев Водитель' : 'Дев Пассажир',
        roles: mode == ActiveMode.driver ? const ['passenger', 'driver'] : const ['passenger'],
        phone: '+996700000000',
        phoneVerified: true,
        telegramLinked: true,
        language: context.locale.languageCode == 'kg' ? 'kg' : 'ru',
        rating: 4.8,
        ratingCount: 24,
        loyaltyTier: 'traveler',
        loyaltyPoints: 180,
      );
      ref.read(authProvider.notifier).setActiveMode(mode);
      ref.read(authProvider.notifier).setSession(user, accessToken: 'dev-token');
      context.go('/');
    }

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => context.canPop() ? context.pop() : context.go('/'),
                  child: const Icon(Icons.arrow_back),
                ),
              ),
              const Spacer(),
              Text('Tappjet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: dark ? BrandColors.c300 : BrandColors.c600)),
              const SizedBox(height: 8),
              Text('nav.login'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: InkColors.c400)),
              const SizedBox(height: 28),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: dark ? InkColors.c900 : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
                ),
                child: Row(children: [
                  const Text('+996 ',
                      style: TextStyle(fontWeight: FontWeight.w800, color: InkColors.c500)),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        hintText: '700 123 456',
                        hintStyle: const TextStyle(color: InkColors.c400),
                        border: InputBorder.none,
                      ),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: dark ? Colors.white : InkColors.c900),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              AppButton(label: 'feed.find_trip'.tr(), onPressed: () {}),
              const SizedBox(height: 10),
              AppButton(
                label: 'Telegram',
                variant: AppButtonVariant.outline,
                icon: Icons.send,
                onPressed: () {},
              ),
              const Spacer(),
              // ── DEV login (temporary) ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dark ? InkColors.c900 : InkColors.c100,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
                ),
                child: Column(
                  children: [
                    const Text('DEV — быстрый вход без бэкенда',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: InkColors.c400)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: 'Пассажир',
                            variant: AppButtonVariant.brand,
                            height: 44,
                            onPressed: () => devLogin(ActiveMode.passenger),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppButton(
                            label: 'Водитель',
                            variant: AppButtonVariant.grape,
                            height: 44,
                            onPressed: () => devLogin(ActiveMode.driver),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
