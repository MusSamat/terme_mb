import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/config.dart';
import '../../widgets/action_modal.dart';
import '../../widgets/driver_avatar.dart';

/// Profile — 1:1 port of tappjet_ft profile mobile layout: add-phone banner →
/// hero card (trust chips + stat strip) → quick settings → pill tabs →
/// about / cars / reviews / history / settings.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _tab = 0;
  static const _tabs = ['about', 'cars', 'reviews', 'history', 'settings'];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final isDriver = user?.isDriver ?? false;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              14, 12, 14, AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom),
          children: [
            if (user != null && !user.phoneVerified) ...[
              _addPhoneBanner(dark),
              const SizedBox(height: 14),
            ],
            _heroCard(dark, user, isDriver),
            const SizedBox(height: 14),
            _SettingsCard(),
            const SizedBox(height: 14),
            _pillTabs(dark),
            const SizedBox(height: 14),
            _tabContent(dark, isDriver, user?.loyaltyPoints ?? 0),
          ],
        ),
      ),
    );
  }

  // ── Add-phone banner ───────────────────────────────────────────────────────
  Widget _addPhoneBanner(bool dark) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: dark ? AccentColors.c500.withValues(alpha: 0.1) : AccentColors.c50,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: dark ? AccentColors.c500.withValues(alpha: 0.2) : AccentColors.c200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('profile.add_phone_title'.tr(),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AccentColors.c700)),
                  Text('profile.add_phone_sub'.tr(),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AccentColors.c700.withValues(alpha: 0.8))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AccentColors.c500, borderRadius: BorderRadius.circular(999), boxShadow: AppShadows.cta),
              child: Text('profile.add_phone_cta'.tr(),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AccentColors.ink)),
            ),
          ],
        ),
      );

  // ── Hero card ──────────────────────────────────────────────────────────────
  Widget _heroCard(bool dark, dynamic user, bool isDriver) {
    final rating = user?.rating as double?;
    final ratingCount = (user?.ratingCount as int?) ?? 0;
    final points = (user?.loyaltyPoints as int?) ?? 0;
    final name = (user?.name as String?) ?? 'roles.guest'.tr();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl4),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DriverAvatar(name: name, size: AvatarSize.xl, square: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
                      ),
                      if (isDriver) ...[const SizedBox(width: 4), const Icon(Icons.verified, size: 18, color: BrandColors.c600)],
                    ]),
                    const SizedBox(height: 2),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '★ ${rating != null ? rating.toStringAsFixed(1) : '—'}',
                          style: const TextStyle(color: AccentColors.c600, fontWeight: FontWeight.w700)),
                      TextSpan(text: ' · ${'profile.rating_count'.tr(namedArgs: {'n': '$ratingCount'})}'),
                      if ((user?.joinYear as int?) != null)
                        TextSpan(text: ' · ${'profile.badge_since'.tr(namedArgs: {'year': '${user!.joinYear}'})}'),
                    ]), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c400)),
                  ],
                ),
              ),
            ],
          ),
          _trustChips(dark, user, isDriver),
          const SizedBox(height: 12),
          _statStrip(dark, ratingCount, rating, points),
        ],
      ),
    );
  }

  Widget _trustChips(bool dark, dynamic user, bool isDriver) {
    final chips = <String>[
      if ((user?.phoneVerified as bool?) ?? false) 'profile.chip_phone',
      if (isDriver) 'profile.chip_docs',
      if (isDriver) 'profile.chip_car',
      if ((user?.telegramLinked as bool?) ?? false) 'profile.chip_telegram',
    ];
    if (chips.isEmpty) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in chips)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: dark ? BrandColors.c500.withValues(alpha: 0.15) : BrandColors.c50,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(c.tr(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: dark ? BrandColors.c300 : BrandColors.c700)),
            ),
        ],
      ),
    );
  }

  Widget _statStrip(bool dark, int ratingCount, double? rating, int points) {
    Widget stat(String value, String label, Color valueColor) => Expanded(
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1, color: valueColor)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400)),
          ]),
        );
    final divider = Container(width: 1, color: dark ? InkColors.c700 : InkColors.c200);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: dark ? InkColors.c800.withValues(alpha: 0.6) : InkColors.c50,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
      ),
      child: IntrinsicHeight(
        child: Row(children: [
          stat('$ratingCount', 'profile.stat_reviews'.tr(), dark ? Colors.white : InkColors.c900),
          divider,
          stat(rating != null ? rating.toStringAsFixed(1) : '—', 'profile.stat_rating'.tr(), AccentColors.c600),
          divider,
          stat('$points', 'profile.stat_points'.tr(), CoralColors.c500),
        ]),
      ),
    );
  }

  // ── Pill tabs ────────────────────────────────────────────────────────────
  Widget _pillTabs(bool dark) {
    String label(String k) => switch (k) {
          'about' => 'profile.tab_about'.tr(),
          'cars' => 'profile.tab_cars'.tr(),
          'reviews' => 'profile.tab_reviews'.tr(),
          'history' => 'profile.tab_history'.tr(),
          _ => 'profile.tab_settings'.tr(),
        };
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final active = i == _tab;
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            behavior: HitTestBehavior.opaque,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active ? BrandColors.c600 : (dark ? InkColors.c900 : Colors.white),
                borderRadius: BorderRadius.circular(999),
                border: active ? null : Border.all(color: dark ? InkColors.c700 : InkColors.c200),
              ),
              child: Text(label(_tabs[i]),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                      color: active ? Colors.white : (dark ? InkColors.c300 : InkColors.c600))),
            ),
          );
        },
      ),
    );
  }

  Widget _tabContent(bool dark, bool isDriver, int points) => switch (_tabs[_tab]) {
        'about' => _about(dark, isDriver, points),
        'cars' => _cars(dark, isDriver),
        'reviews' => _reviews(dark),
        'history' => _hintCard(dark, 'profile.history_hint'.tr()),
        _ => _settings(dark, isDriver),
      };

  // ── About tab ──────────────────────────────────────────────────────────────
  Widget _about(bool dark, bool isDriver, int points) {
    return Column(
      children: [
        if (!isDriver) ...[
          GestureDetector(
            onTap: () => context.push('/profile/driver'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: GrapeColors.c600, borderRadius: BorderRadius.circular(AppRadii.xl3), boxShadow: AppShadows.indigoCta),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.directions_car_filled, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('profile.become_driver_title'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('profile.become_driver_sub'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
          const SizedBox(height: 14),
        ],
        _card(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.format_quote, size: 16, color: BrandColors.c600),
            const SizedBox(width: 8),
            Text('profile.bio_title'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
          ]),
          const SizedBox(height: 8),
          Text('profile.bio_placeholder'.tr(), style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w600, color: InkColors.c400)),
        ])),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => context.push('/loyalty'),
          behavior: HitTestBehavior.opaque,
          child: _card(dark, Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: dark ? AccentColors.c500.withValues(alpha: 0.15) : AccentColors.c100, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.card_giftcard, size: 18, color: AccentColors.c600),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('profile.quick_bonuses'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? InkColors.c100 : InkColors.c800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: dark ? AccentColors.c500.withValues(alpha: 0.15) : AccentColors.c100, borderRadius: BorderRadius.circular(999)),
              child: Text('$points', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AccentColors.c700)),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 18, color: InkColors.c300),
          ])),
        ),
      ],
    );
  }

  Widget _cars(bool dark, bool isDriver) {
    if (!isDriver) {
      return _hintCard(dark, 'empty.driver_trips.description'.tr());
    }
    return _card(dark, Row(children: [
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: dark ? GrapeColors.c500.withValues(alpha: 0.15) : GrapeColors.c50, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.directions_car, color: GrapeColors.c600),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Toyota Camry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
          const Text('01KG 777 · Белый · 4 места', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400)),
        ]),
      ),
    ]));
  }

  Widget _reviews(bool dark) {
    final reviews = [
      ('Нургуль', 5, 'Отличный водитель, доехали быстро и комфортно.'),
      ('Данияр', 5, 'Пунктуальный, аккуратная езда. Рекомендую!'),
    ];
    return Column(
      children: [
        for (final r in reviews)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: dark ? InkColors.c900 : Colors.white,
              borderRadius: BorderRadius.circular(AppRadii.xl3),
              boxShadow: AppShadows.card,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(r.$1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                const Spacer(),
                Row(children: [for (var i = 0; i < r.$2; i++) const Icon(Icons.star, size: 13, color: AccentColors.c400)]),
              ]),
              const SizedBox(height: 4),
              Text(r.$3, style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: InkColors.c500)),
            ]),
          ),
      ],
    );
  }

  // ── Settings tab ─────────────────────────────────────────────────────────
  Widget _settings(bool dark, bool isDriver) {
    return Column(
      children: [
        _card(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHead(dark, 'profile.personal_section'.tr()),
          _formField(dark, 'Имя', ref.watch(authProvider).user?.name ?? ''),
          const SizedBox(height: 10),
          _formField(dark, 'profile.bio_title'.tr(), '', lines: 3),
        ])),
        if (isDriver) ...[
          const SizedBox(height: 14),
          _card(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _cardHead(dark, 'profile.car_photo_section'.tr()),
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: dark ? InkColors.c800 : InkColors.c50,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
              ),
              child: const Center(child: Icon(Icons.add_a_photo_outlined, color: InkColors.c400)),
            ),
          ])),
        ],
        const SizedBox(height: 14),
        _card(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHead(dark, 'profile.password_section'.tr()),
          _formField(dark, 'password_form.current_label'.tr(), '', obscure: true),
          const SizedBox(height: 10),
          _formField(dark, 'password_form.new_label'.tr(), '', obscure: true),
        ])),
        const SizedBox(height: 14),
        _card(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _cardHead(dark, 'profile.phone_section'.tr()),
          _formField(dark, 'profile.chip_phone'.tr(), ref.watch(authProvider).user?.phone ?? ''),
        ])),
        const SizedBox(height: 14),
        _card(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('profile.session_section'.tr().toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: InkColors.c400)),
          const SizedBox(height: 12),
          _sessionBtn(dark, Icons.devices, 'profile.logout_all'.tr(), InkColors.c700, () {
            ref.read(authProvider.notifier).clearSession();
            context.go('/');
          }),
          const SizedBox(height: 8),
          _sessionBtn(dark, Icons.logout, 'profile.logout_btn'.tr(), CoralColors.c600, () async {
            final notifier = ref.read(authProvider.notifier);
            final ok = await showConfirmModal(
              context,
              icon: Icons.logout,
              title: 'profile.logout_btn'.tr(),
              confirmLabel: 'profile.logout_btn'.tr(),
              cancelLabel: 'book_form.cancel'.tr(),
              danger: true,
            );
            if (!ok || !mounted) return;
            notifier.clearSession();
            context.go('/');
          }),
          const SizedBox(height: 8),
          _sessionBtn(dark, Icons.download, 'profile.export_btn'.tr(), InkColors.c500, () {}),
          const SizedBox(height: 8),
          _sessionBtn(dark, Icons.delete_outline, 'profile.delete_btn'.tr(), CoralColors.c600, () => context.push('/profile/delete')),
        ])),
      ],
    );
  }

  Widget _cardHead(bool dark, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
      );

  Widget _formField(bool dark, String label, String value, {int lines = 1, bool obscure = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: InkColors.c400)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: dark ? InkColors.c800 : InkColors.c50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
            ),
            child: TextField(
              controller: TextEditingController(text: value),
              maxLines: obscure ? 1 : lines,
              obscureText: obscure,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900),
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      );

  Widget _sessionBtn(bool dark, IconData icon, String label, Color color, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dark ? InkColors.c800 : InkColors.c50,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );

  Widget _hintCard(bool dark, String text) => _card(
        dark,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: InkColors.c500)),
          ),
        ),
      );

  Widget _card(bool dark, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.xl3),
          boxShadow: AppShadows.card,
        ),
        child: child,
      );
}

/// Quick settings — [RU|KG] + [☀|🌙], 1:1 with tappjet_ft SettingsCard.
class _SettingsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mode = ref.watch(themeModeProvider);
    final locale = context.locale.languageCode;
    final isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && dark);

    void setLocale(String code) {
      context.setLocale(Locale(code));
      ref.read(hiveBoxProvider).put(StorageKeys.locale, code);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl4),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segmented(
              options: const [('ru', 'RU', null), ('kg', 'KG', null)],
              selected: locale == 'kg' ? 'kg' : 'ru',
              onSelect: setLocale,
              dark: dark,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Segmented(
              options: const [('light', '', Icons.light_mode), ('dark', '', Icons.dark_mode)],
              selected: isDark ? 'dark' : 'light',
              onSelect: (v) => ref.read(themeModeProvider.notifier).set(v == 'dark' ? ThemeMode.dark : ThemeMode.light),
              dark: dark,
            ),
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.selected, required this.onSelect, required this.dark});
  final List<(String, String, IconData?)> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: dark ? InkColors.c800 : InkColors.c100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (value, label, icon) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(value),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected ? (dark ? InkColors.c950 : Colors.white) : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: value == selected ? AppShadows.xs : null,
                  ),
                  child: icon != null
                      ? Icon(icon, size: 16, color: value == selected ? (dark ? Colors.white : InkColors.c900) : InkColors.c400)
                      : Text(label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: value == selected ? (dark ? Colors.white : InkColors.c900) : InkColors.c400)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
