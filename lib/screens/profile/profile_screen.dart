import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../theme/role_theme.dart';
import '../../utils/config.dart';
import '../../widgets/driver_avatar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final role = ref.watch(roleThemeProvider);
    final auth = ref.watch(authProvider);
    final user = auth.user;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _hero(context, role, user?.name ?? 'roles.guest'.tr(), user?.rating, user?.ratingCount ?? 0,
              user?.phoneVerified ?? false, user?.isDriver ?? false, user?.telegramLinked ?? false),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom),
            child: Column(
              children: [
                if (user != null) _statsRow(dark, user.loyaltyPoints, user.loyaltyTier),
                const SizedBox(height: 12),
                _linkTile(context, dark, Icons.card_giftcard, 'profile.loyalty_link'.tr(),
                    () => context.push('/loyalty')),
                if (user != null && !user.isDriver)
                  _linkTile(context, dark, Icons.directions_car_outlined, 'profile.badge_driver'.tr(),
                      () => context.push('/profile/driver')),
                _linkTile(context, dark, Icons.notifications_outlined, 'notif.default_label'.tr(),
                    () => context.push('/notifications')),
                const SizedBox(height: 16),
                _settings(context, ref, dark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, RoleTheme role, String name, double? rating, int ratingCount,
      bool phone, bool driver, bool tg) {
    final badges = <String>[
      if (phone) 'profile.badge_phone'.tr(),
      if (driver) 'profile.badge_driver'.tr(),
      if (tg) 'profile.badge_telegram'.tr(),
    ];
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: role.headerGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadii.xl4)),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 20, 16, 20),
      child: Column(
        children: [
          DriverAvatar(name: name, size: AvatarSize.xl, verified: driver),
          const SizedBox(height: 10),
          Text(name,
              style: const TextStyle(
                  fontFamily: 'Fredoka', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          if (rating != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 15, color: Colors.white),
                const SizedBox(width: 4),
                Text('${rating.toStringAsFixed(1)} · ${'profile.rating_count'.tr(namedArgs: {'n': '$ratingCount'})}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9))),
              ],
            ),
          ],
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in badges)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(b,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsRow(bool dark, int points, String tier) {
    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : InkColors.c900)),
              Text(label,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: InkColors.c400)),
            ],
          ),
        );
    return _card(
      dark,
      Row(children: [
        stat('$points', 'profile.stat_points'.tr()),
        stat('loyalty.tiers.$tier'.tr(), 'profile.stat_tier'.tr()),
      ]),
    );
  }

  Widget _linkTile(BuildContext context, bool dark, IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: _card(
          dark,
          Row(children: [
            Icon(icon, size: 20, color: dark ? BrandColors.c300 : BrandColors.c600),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: dark ? Colors.white : InkColors.c900))),
            const Icon(Icons.chevron_right, size: 18, color: InkColors.c400),
          ]),
        ),
      ),
    );
  }

  Widget _settings(BuildContext context, WidgetRef ref, bool dark) {
    final mode = ref.watch(themeModeProvider);
    final locale = context.locale.languageCode;

    return _card(
      dark,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('profile.tab_settings'.tr(),
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : InkColors.c900)),
          const SizedBox(height: 12),
          // Theme
          _rowLabel('Тема', dark),
          const SizedBox(height: 6),
          _pillGroup([
            ('theme.light'.tr(), mode == ThemeMode.light, () => ref.read(themeModeProvider.notifier).set(ThemeMode.light)),
            ('theme.dark'.tr(), mode == ThemeMode.dark, () => ref.read(themeModeProvider.notifier).set(ThemeMode.dark)),
            ('Авто', mode == ThemeMode.system, () => ref.read(themeModeProvider.notifier).set(ThemeMode.system)),
          ], dark),
          const SizedBox(height: 12),
          // Language
          _rowLabel('Язык', dark),
          const SizedBox(height: 6),
          _pillGroup([
            ('locale.ru'.tr(), locale == 'ru', () => _setLocale(context, ref, 'ru')),
            ('locale.kg'.tr(), locale == 'kg', () => _setLocale(context, ref, 'kg')),
          ], dark),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              ref.read(authProvider.notifier).clearSession();
              context.go('/');
            },
            behavior: HitTestBehavior.opaque,
            child: const Row(children: [
              Icon(Icons.logout, size: 18, color: CoralColors.c500),
              SizedBox(width: 10),
              Text('Выйти',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: CoralColors.c500)),
            ]),
          ),
        ],
      ),
    );
  }

  void _setLocale(BuildContext context, WidgetRef ref, String code) {
    context.setLocale(Locale(code));
    ref.read(hiveBoxProvider).put(StorageKeys.locale, code);
  }

  Widget _rowLabel(String text, bool dark) => Text(text.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: InkColors.c400));

  Widget _pillGroup(List<(String, bool, VoidCallback)> items, bool dark) {
    return Row(
      children: [
        for (final (label, active, onTap) in items) ...[
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? BrandColors.c600 : (dark ? InkColors.c800 : InkColors.c100),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : (dark ? InkColors.c200 : InkColors.c700))),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card(bool dark, Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}
