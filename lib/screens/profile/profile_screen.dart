import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/config.dart';
import '../../utils/image_pick.dart';
import '../../widgets/action_modal.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/query_error.dart';
import 'cars_card.dart';
import 'history_view.dart';
import 'password_change_card.dart';
import 'phone_change_card.dart';
import 'profile_edit_card.dart';

/// Profile — 1:1 port of terme_ft profile mobile layout: add-phone banner →
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

    // История / Настройки open as full sub-pages (back arrow → profile) instead
    // of crowding the tab row; the pills carry only the 3 content sections.
    final isSubPage = _tabs[_tab] == 'history' || _tabs[_tab] == 'settings';

    return PopScope(
      canPop: !isSubPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && mounted) setState(() => _tab = 0);
      },
      child: Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              14, 12, 14, AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom),
          children: isSubPage
              ? [
                  _subHeader(dark),
                  const SizedBox(height: 8),
                  _tabContent(dark, isDriver, user?.loyaltyPoints ?? 0),
                ]
              : [
                  if (user != null && !user.phoneVerified) ...[
                    _addPhoneBanner(dark),
                    const SizedBox(height: 14),
                  ],
                  _heroCard(dark, user, isDriver),
                  const SizedBox(height: 14),
                  _pillTabs(dark),
                  const SizedBox(height: 14),
                  _tabContent(dark, isDriver, user?.loyaltyPoints ?? 0),
                  const SizedBox(height: 14),
                  _menuCard(dark),
                ],
        ),
      ),
      ),
    );
  }

  // Sub-page header (История / Настройки) with a back arrow to the profile root.
  Widget _subHeader(bool dark) {
    final title = _tabs[_tab] == 'history' ? 'profile.tab_history'.tr() : 'profile.tab_settings'.tr();
    return Row(children: [
      GestureDetector(
        onTap: () => setState(() => _tab = 0),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(Icons.arrow_back, color: dark ? Colors.white : InkColors.c900),
        ),
      ),
      const SizedBox(width: 4),
      Text(title, style: TextStyle(fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
    ]);
  }

  // Menu list under the content tabs — the quick RU/KG + theme toggles, then
  // История поездок and Настройки as tappable rows (open as sub-pages).
  Widget _menuCard(bool dark) {
    return Column(children: [
      _SettingsCard(),
      const SizedBox(height: 14),
      _card(
        dark,
        Column(children: [
          _menuRow(dark, Icons.history, 'profile.tab_history'.tr(), () => setState(() => _tab = _tabs.indexOf('history'))),
          Divider(height: 1, color: dark ? InkColors.c800 : InkColors.c100),
          _menuRow(dark, Icons.settings_outlined, 'profile.tab_settings'.tr(), () => setState(() => _tab = _tabs.indexOf('settings'))),
        ]),
      ),
    ]);
  }

  Widget _menuRow(bool dark, IconData icon, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Icon(icon, size: 20, color: dark ? InkColors.c300 : InkColors.c600),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? InkColors.c100 : InkColors.c800))),
            const Icon(Icons.chevron_right, size: 20, color: InkColors.c400),
          ]),
        ),
      );

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
              GestureDetector(
                onTap: _changeAvatar,
                behavior: HitTestBehavior.opaque,
                child: Stack(children: [
                  DriverAvatar(name: name, imageUrl: ref.watch(authProvider).user?.avatarUrl, size: AvatarSize.xl, square: true),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: BrandColors.c600, shape: BoxShape.circle, border: Border.all(color: dark ? InkColors.c900 : Colors.white, width: 2)),
                      child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                    ),
                  ),
                ]),
              ),
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

  // ── Content pills — 3 sections that fit the width (no horizontal overflow);
  // История / Настройки moved to the menu list below. ────────────────────────
  Widget _pillTabs(bool dark) {
    const shown = ['about', 'cars', 'reviews'];
    String label(String k) => switch (k) {
          'about' => 'profile.tab_about'.tr(),
          'cars' => 'profile.tab_cars'.tr(),
          _ => 'profile.tab_reviews'.tr(),
        };
    return Row(
      children: [
        for (final k in shown) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = _tabs.indexOf(k)),
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 40,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _tabs[_tab] == k ? BrandColors.c600 : (dark ? InkColors.c900 : Colors.white),
                  borderRadius: BorderRadius.circular(999),
                  border: _tabs[_tab] == k ? null : Border.all(color: dark ? InkColors.c700 : InkColors.c200),
                ),
                // Long labels (e.g. «Өзүм жөнүндө» in kg) shrink to fit one line
                // instead of wrapping/overflowing the pill.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label(k),
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: _tabs[_tab] == k ? FontWeight.w900 : FontWeight.w700,
                          color: _tabs[_tab] == k ? Colors.white : (dark ? InkColors.c300 : InkColors.c600))),
                ),
              ),
            ),
          ),
          if (k != shown.last) const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _tabContent(bool dark, bool isDriver, int points) => switch (_tabs[_tab]) {
        'about' => _about(dark, isDriver, points),
        'cars' => _cars(dark, isDriver),
        'reviews' => _reviews(dark),
        'history' => ProfileHistoryView(dark: dark),
        _ => _settings(dark, isDriver),
      };

  // Profile-completion nudge — 1:1 with the web ProfileCompletion component.
  // Five 20% steps; hides itself once the profile is 100% complete.
  Widget _profileCompletion(bool dark, bool isDriver) {
    final user = ref.watch(authProvider).user;
    final steps = <({bool done, String label, bool hint})>[
      (done: user?.phoneVerified ?? false, label: 'profile.completion_phone'.tr(), hint: false),
      (done: (user?.name ?? '').isNotEmpty, label: 'profile.completion_name'.tr(), hint: false),
      (done: (user?.avatarUrl ?? '').isNotEmpty, label: 'profile.completion_avatar'.tr(), hint: true),
      (done: (user?.bio ?? '').trim().isNotEmpty, label: 'profile.completion_bio'.tr(), hint: true),
      (done: isDriver, label: 'profile.completion_driver'.tr(), hint: true),
    ];
    final pct = steps.fold<int>(0, (s, step) => s + (step.done ? 20 : 0));
    if (pct == 100) return const SizedBox.shrink();
    final hintText = 'profile.completion_hint'.tr(namedArgs: {'pct': '20'});

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: dark ? AccentColors.c500.withValues(alpha: 0.08) : AccentColors.c50,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: dark ? AccentColors.c500.withValues(alpha: 0.3) : AccentColors.c200),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Text('profile.completion_title'.tr(namedArgs: {'pct': '$pct'}),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
            ),
            Text('$pct%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AccentColors.c700)),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: dark ? AccentColors.c500.withValues(alpha: 0.15) : AccentColors.c100,
              valueColor: const AlwaysStoppedAnimation(AccentColors.c500),
            ),
          ),
          const SizedBox(height: 14),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Icon(step.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16, color: step.done ? BrandColors.c600 : InkColors.c300),
                const SizedBox(width: 8),
                Text(step.label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: step.done ? FontWeight.w600 : FontWeight.w700,
                        decoration: step.done ? TextDecoration.lineThrough : null,
                        color: step.done ? InkColors.c400 : (dark ? InkColors.c200 : InkColors.c700))),
                if (!step.done && step.hint) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: dark ? AccentColors.c500.withValues(alpha: 0.15) : AccentColors.c100,
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(hintText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AccentColors.c700)),
                  ),
                ],
              ]),
            ),
        ]),
      ),
    );
  }

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
        _profileCompletion(dark, isDriver),
        _card(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.format_quote, size: 16, color: BrandColors.c600),
            const SizedBox(width: 8),
            Text('profile.bio_title'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
          ]),
          const SizedBox(height: 8),
          Builder(builder: (_) {
            // Mirror the web: show the user's real bio, fall back to placeholder.
            final bio = ref.watch(authProvider).user?.bio?.trim() ?? '';
            final hasBio = bio.isNotEmpty;
            return Text(hasBio ? bio : 'profile.bio_placeholder'.tr(),
                style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: hasBio ? (dark ? InkColors.c200 : InkColors.c700) : InkColors.c400));
          }),
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
    // Cars belong to the user, not the active mode — always show the garage
    // (add / select / remove), so «Авто» is never mysteriously empty.
    return _card(dark, CarsCard(dark: dark));
  }

  Widget _reviews(bool dark) {
    final myId = ref.watch(authProvider).user?.id;
    if (myId == null) return const SizedBox.shrink();
    return ref.watch(userRatingsProvider(myId)).when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: BrandColors.c500))),
      error: (e, _) => QueryError(error: e, onRetry: () => ref.invalidate(userRatingsProvider(myId))),
      data: (reviews) => reviews.isEmpty
          ? _hintCard(dark, 'drivers.no_reviews'.tr())
          : Column(
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
                        Text(r.raterName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                        const Spacer(),
                        Row(children: [for (var i = 0; i < r.score; i++) const Icon(Icons.star, size: 13, color: AccentColors.c400)]),
                      ]),
                      if ((r.comment ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(r.comment!, style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: InkColors.c500)),
                      ],
                    ]),
                  ),
              ],
            ),
    );
  }

  Future<void> _changeAvatar() async {
    try {
      final img = await pickCompressedImage();
      if (img == null) return;
      final url = await ref.read(profileServiceProvider).uploadAvatar(img);
      final cur = ref.read(authProvider).user;
      if (cur != null) ref.read(authProvider.notifier).updateUser(cur.copyWith(avatarUrl: url));
      Toasts.success('profile.saved'.tr());
    } catch (e) {
      Toasts.error(friendlyError(e));
    }
  }

  // ── Settings tab ─────────────────────────────────────────────────────────
  // GDPR data export — pull the bytes and drop them in a file the OS can share.
  Future<void> _exportData() async {
    try {
      final bytes = await ref.read(profileServiceProvider).exportData();
      final file = File('${Directory.systemTemp.path}/terme_export_${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsBytes(bytes);
      if (mounted) Toasts.success('toasts.saved'.tr());
    } catch (e) {
      if (mounted) Toasts.error(friendlyError(e));
    }
  }

  Widget _settings(bool dark, bool isDriver) {
    return Column(
      children: [
        _card(dark, ProfileEditCard(dark: dark)),
        if (isDriver) ...[
          const SizedBox(height: 14),
          _card(dark, CarsCard(dark: dark)),
        ],
        const SizedBox(height: 14),
        _card(dark, PasswordChangeCard(dark: dark)),
        const SizedBox(height: 14),
        _card(dark, PhoneChangeCard(dark: dark)),
        const SizedBox(height: 14),
        _card(dark, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('profile.session_section'.tr().toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: InkColors.c400)),
          const SizedBox(height: 12),
          _sessionBtn(dark, Icons.devices, 'profile.logout_all'.tr(), InkColors.c700, () async {
            try {
              await ref.read(authServiceProvider).logoutAll(); // revoke every device
            } catch (_) {/* clear locally regardless */}
            ref.read(authProvider.notifier).clearSession();
            if (mounted) context.go('/');
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
            try {
              await ref.read(authServiceProvider).logout(); // revoke this device's token
            } catch (_) {/* clear locally regardless */}
            notifier.clearSession();
            if (mounted) context.go('/');
          }),
          const SizedBox(height: 8),
          _sessionBtn(dark, Icons.download, 'profile.export_btn'.tr(), InkColors.c500, _exportData),
          const SizedBox(height: 8),
          _sessionBtn(dark, Icons.delete_outline, 'profile.delete_btn'.tr(), CoralColors.c600, () => context.push('/profile/delete')),
        ])),
      ],
    );
  }


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

/// Quick settings — [RU|KG] + [☀|🌙], 1:1 with terme_ft SettingsCard.
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
