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
import 'password_change_card.dart';
import 'trip_history_screen.dart';
import 'phone_change_card.dart';
import 'profile_edit_card.dart';

// Simple, light-only profile palette (inDrive/wb style): warm background
// (InkColors.c50), white grouped cards, ONE teal accent, red only for the two
// destructive actions. No tabs, no hero card, no theme toggle.
const _accent = BrandColors.c600; // teal
const _danger = CoralColors.c600; // red — logout / delete only
const _ink = InkColors.c900;
const _ink2 = InkColors.c500;
const _hair = InkColors.c200;

/// Profile root — a plain settings list (like inDrive / Яндекс): phone on top,
/// then grouped rows that open full-screen sub-pages.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _open(Widget page) => Navigator.of(context, rootNavigator: true)
      .push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDriver = user?.isDriver ?? false;
    final phone = user?.phone ?? '';
    final points = user?.loyaltyPoints ?? 0;
    final name = user?.name ?? 'roles.guest'.tr();

    return Scaffold(
      backgroundColor: InkColors.c50,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              16, 18, 16, AppLayout.pillNavClearance + MediaQuery.of(context).padding.bottom),
          children: [
            // Header — avatar + name + phone, taps into profile settings
            // (inDrive/Яндекс pattern). Replaces the old bare title and the
            // redundant «Настройки профиля» row.
            GestureDetector(
              onTap: () => _open(const _SettingsScreen()),
              behavior: HitTestBehavior.opaque,
              child: Row(children: [
                DriverAvatar(name: name, imageUrl: user?.avatarUrl, size: AvatarSize.lg),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.w800, color: _ink, letterSpacing: -0.3)),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(phone, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink2)),
                    ],
                  ]),
                ),
                const Icon(Icons.chevron_right, size: 22, color: InkColors.c400),
              ]),
            ),
            const SizedBox(height: 20),

            _Group(rows: [
              _Row(label: 'profile.tab_history'.tr(), onTap: () => _open(const TripHistoryScreen())),
              if (isDriver) _Row(label: 'profile.menu_cars'.tr(), onTap: () => _open(const _CarsScreen())),
              _Row(label: 'profile.tab_reviews'.tr(), onTap: () => _open(const _ReviewsScreen())),
              _Row(label: 'profile.quick_bonuses'.tr(), value: '$points', onTap: () => context.push('/loyalty')),
              _Row(label: 'profile.menu_language'.tr(), value: _localeLabel(), onTap: _pickLanguage),
            ]),

            if (!isDriver) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.push('/profile/driver'),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(16)),
                  child: Text('profile.become_driver_title'.tr(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],

            const SizedBox(height: 16),
            _Group(rows: [
              _Row(label: 'profile.logout_btn'.tr(), danger: true, onTap: _logout),
            ]),
          ],
        ),
      ),
    );
  }

  String _localeLabel() => context.locale.languageCode == 'kg' ? 'Кыргызча' : 'Русский';

  void _pickLanguage() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        void choose(String code) {
          context.setLocale(Locale(code));
          ref.read(hiveBoxProvider).put(StorageKeys.locale, code);
          Navigator.of(sheetCtx).pop();
        }

        final cur = context.locale.languageCode == 'kg' ? 'kg' : 'ru';
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            _LangOption(label: 'Русский', selected: cur == 'ru', onTap: () => choose('ru')),
            _LangOption(label: 'Кыргызча', selected: cur == 'kg', onTap: () => choose('kg')),
            const SizedBox(height: 10),
          ]),
        );
      },
    );
  }

  Future<void> _logout() async {
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
      await ref.read(authServiceProvider).logout();
    } catch (_) {/* clear locally regardless */}
    ref.read(authProvider.notifier).clearSession();
    if (mounted) context.go('/');
  }
}

// ── Shared list primitives ───────────────────────────────────────────────────

/// A white rounded group of rows with hairline dividers (iOS-settings style).
class _Group extends StatelessWidget {
  const _Group({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(const Divider(height: 1, thickness: 1, indent: 16, color: _hair));
      }
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, this.value, this.danger = false, required this.onTap});
  final String label;
  final String? value;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: danger ? _danger : _ink)),
          ),
          if (value != null) ...[
            Text(value!, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink2)),
            const SizedBox(width: 8),
          ],
          if (!danger) const Icon(Icons.chevron_right, size: 20, color: InkColors.c400),
        ]),
      ),
    );
  }
}

class _LangOption extends StatelessWidget {
  const _LangOption({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink))),
            if (selected) const Icon(Icons.check, color: _accent),
          ]),
        ),
      );
}

/// A full-screen sub-page scaffold — warm bg, back arrow, centered title.
class _SubScaffold extends StatelessWidget {
  const _SubScaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: InkColors.c50,
      appBar: AppBar(
        backgroundColor: InkColors.c50,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _ink),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title,
            style: const TextStyle(fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
      ),
      body: SafeArea(top: false, child: child),
    );
  }
}

/// White rounded panel wrapping a reused form card.
Widget _panel(Widget child) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: child,
    );

/// White panel with a tappable title that expands/collapses its child
/// (used to hide the password form until the user wants it).
class _Collapsible extends StatefulWidget {
  const _Collapsible({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
              ),
              AnimatedRotation(
                turns: _open ? 0.25 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.chevron_right, size: 20, color: InkColors.c400),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: widget.child,
          ),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ]),
    );
  }
}

// ── Sub-pages ────────────────────────────────────────────────────────────────

/// Настройки профиля — avatar + name/bio + phone + password, each a white panel.
class _SettingsScreen extends ConsumerStatefulWidget {
  const _SettingsScreen();

  @override
  ConsumerState<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<_SettingsScreen> {
  Future<void> _changeAvatar() async {
    try {
      final img = await pickCompressedImage();
      if (img == null) return;
      final url = await ref.read(profileServiceProvider).uploadAvatar(img);
      final cur = ref.read(authProvider).user;
      if (cur != null) ref.read(authProvider.notifier).updateUser(cur.copyWith(avatarUrl: url));
      if (mounted) Toasts.success('profile.saved'.tr());
    } catch (e) {
      if (mounted) Toasts.error(friendlyError(e));
    }
  }

  // GDPR export — pull the bytes into a temp file the OS can share.
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

  // Revoke every device, then pop back to the shell — the router redirects the
  // now-anonymous session to login (this screen is an imperative route on top).
  Future<void> _logoutAll() async {
    try {
      await ref.read(authServiceProvider).logoutAll();
    } catch (_) {/* clear locally regardless */}
    ref.read(authProvider.notifier).clearSession();
    if (mounted) Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final name = user?.name ?? 'roles.guest'.tr();
    return _SubScaffold(
      title: 'profile.menu_settings'.tr(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: GestureDetector(
              onTap: _changeAvatar,
              behavior: HitTestBehavior.opaque,
              child: Stack(children: [
                DriverAvatar(name: name, imageUrl: user?.avatarUrl, size: AvatarSize.xl, square: true),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: _accent, shape: BoxShape.circle, border: Border.all(color: InkColors.c50, width: 2.5)),
                    child: const Icon(Icons.camera_alt, size: 13, color: Colors.white),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 22),
          _panel(const ProfileEditCard(dark: false)),
          const SizedBox(height: 14),
          _panel(const PhoneChangeCard(dark: false)),
          const SizedBox(height: 14),
          _Collapsible(
            title: 'profile.password_section'.tr(),
            child: const PasswordChangeCard(dark: false, showHeader: false),
          ),
          const SizedBox(height: 22),
          // Rarely-used account & data actions live down here, out of the way.
          _Group(rows: [
            _Row(label: 'profile.logout_all'.tr(), onTap: _logoutAll),
            _Row(label: 'profile.export_btn'.tr(), onTap: _exportData),
            _Row(label: 'profile.delete_btn'.tr(), danger: true, onTap: () => context.push('/profile/delete')),
          ]),
        ],
      ),
    );
  }
}

class _CarsScreen extends StatelessWidget {
  const _CarsScreen();

  @override
  Widget build(BuildContext context) => _SubScaffold(
        title: 'profile.menu_cars'.tr(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [_panel(const CarsCard(dark: false))],
        ),
      );
}

class _ReviewsScreen extends ConsumerWidget {
  const _ReviewsScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = ref.watch(authProvider).user?.id;
    return _SubScaffold(
      title: 'profile.tab_reviews'.tr(),
      child: myId == null
          ? const SizedBox.shrink()
          : ref.watch(userRatingsProvider(myId)).when(
                loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: BrandColors.c500)),
                error: (e, _) => QueryError(error: e, onRetry: () => ref.invalidate(userRatingsProvider(myId))),
                data: (reviews) => reviews.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text('drivers.no_reviews'.tr(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: InkColors.c500)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: reviews.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final r = reviews[i];
                          return _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(r.raterName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
                              const Spacer(),
                              Row(children: [
                                for (var s = 0; s < r.score; s++) const Icon(Icons.star, size: 13, color: AccentColors.c400)
                              ]),
                            ]),
                            if ((r.comment ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(r.comment!,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: InkColors.c500)),
                            ],
                          ]));
                        },
                      ),
              ),
    );
  }
}
