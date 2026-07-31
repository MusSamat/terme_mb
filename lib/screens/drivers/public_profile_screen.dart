import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../theme/role_theme.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/verified_badge.dart';

class PublicProfileScreen extends StatelessWidget {
  const PublicProfileScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final role = roleThemeFor(UiRole.driver);
    // Static sample profile (real fetch in ТЗ step 2).
    const name = 'Азамат Кыдыров';
    const rating = 4.9;
    const ratingCount = 128;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: role.headerGradient,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadii.xl4)),
                ),
                padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 56, 16, 24),
                child: Column(
                  children: [
                    const DriverAvatar(name: name, size: AvatarSize.xl, verified: true),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name,
                            style: TextStyle(
                                fontFamily: 'Fredoka',
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        SizedBox(width: 6),
                        VerifiedBadge(size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('drivers.driver_badge'.tr(),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 4,
                left: 4,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _stat(dark, rating.toStringAsFixed(1), 'drivers.rating_label'.tr()),
                    _stat(dark, '$ratingCount', 'drivers.ratings_label'.tr()),
                    _stat(dark, '340', 'drivers.trips_label'.tr()),
                  ],
                ),
                const SizedBox(height: 16),
                _card(dark, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('drivers.car_section'.tr(),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : InkColors.c900)),
                    const SizedBox(height: 10),
                    _kv(dark, 'drivers.car_make_model'.tr(), 'Toyota Camry'),
                    _kv(dark, 'drivers.car_year'.tr(), '2019'),
                    _kv(dark, 'drivers.car_color'.tr(), 'Белый'),
                    _kv(dark, 'drivers.car_plate'.tr(), '01KG 777'),
                  ],
                )),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('drivers.reviews_title'.tr(),
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: dark ? Colors.white : InkColors.c900)),
                ),
                const SizedBox(height: 10),
                _review(dark, 'Нургуль', 5, 'Отличный водитель, доехали быстро и комфортно.'),
                _review(dark, 'Данияр', 5, 'Пунктуальный, аккуратная езда. Рекомендую!'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(bool dark, String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: dark ? Colors.white : InkColors.c900)),
            Text(label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: InkColors.c400)),
          ],
        ),
      );

  Widget _kv(bool dark, String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(k,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400))),
          Text(v,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : InkColors.c900)),
        ]),
      );

  Widget _review(bool dark, String name, int stars, String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(name,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : InkColors.c900)),
              const Spacer(),
              Row(children: [
                for (var i = 0; i < stars; i++)
                  const Icon(Icons.star, size: 13, color: AccentColors.c400),
              ]),
            ]),
            const SizedBox(height: 4),
            Text(text,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: InkColors.c500)),
          ],
        ),
      );

  Widget _card(bool dark, Widget child) => Container(
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
