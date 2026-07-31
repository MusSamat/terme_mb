import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../theme/dimens.dart';

/// Floating pill bottom navigation — port of tappjet_ft/src/components/layout/
/// bottom-nav.tsx. Five slots for authenticated users with a raised amber
/// create-FAB in the center; two slots for guests.
///
/// Hide this (don't render it) on auth routes, chat threads, and when the
/// keyboard is open — the shell decides visibility.
class PillNav extends ConsumerWidget {
  const PillNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onCreate,
    this.chatUnread = 0,
  });

  /// Index into the tab list (0..3, skipping the center FAB).
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;
  final int chatUnread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AppColors>()!;
    final role = ref.watch(roleThemeProvider);
    final brightness = Theme.of(context).brightness;
    final authed = ref.watch(authProvider).isAuthenticated;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // NOTE: Material icons stand in for the web's lucide-react set. Swap to
    // lucide_icons_flutter when building out the final visual pass (ТЗ §7).
    final items = authed
        ? const [
            _NavSpec(Icons.search, 'nav.search'),
            _NavSpec(Icons.receipt_long_outlined, 'nav.bookings'),
            _NavSpec(Icons.chat_bubble_outline, 'nav.chats'),
            _NavSpec(Icons.person_outline, 'nav.profile'),
          ]
        : const [
            _NavSpec(Icons.search, 'nav.search'),
            _NavSpec(Icons.login, 'nav.login'),
          ];

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + safeBottom),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadii.xl4),
          boxShadow: AppShadows.lift,
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _NavButton(
                spec: items[i],
                active: authed && i == currentIndex,
                pillOn: role.navPill(brightness),
                textOn: role.navText(brightness),
                idle: c.textMuted,
                badge: authed && items[i].icon == Icons.chat_bubble_outline ? chatUnread : 0,
                onTap: () => onSelect(i),
              ),
              // Insert the raised create-FAB in the middle for authed users.
              if (authed && i == 1) _CreateFab(onTap: onCreate),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.icon, this.labelKey);
  final IconData icon;
  final String labelKey;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.spec,
    required this.active,
    required this.pillOn,
    required this.textOn,
    required this.idle,
    required this.badge,
    required this.onTap,
  });

  final _NavSpec spec;
  final bool active;
  final Color pillOn;
  final Color textOn;
  final Color idle;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? pillOn : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(spec.icon, size: 22, color: active ? textOn : idle),
            if (badge > 0)
              Positioned(
                right: -6,
                top: -4,
                child: _Badge(count: badge),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF43F5E), // coral-500
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CreateFab extends StatelessWidget {
  const _CreateFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -18), // raised above the pill (-mt-8)
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            gradient: kCreateFabGradient,
            shape: BoxShape.circle,
            boxShadow: AppShadows.cta,
          ),
          child: const Icon(Icons.add, color: AppTextOnAmber.color, size: 26),
        ),
      ),
    );
  }
}

/// Amber-surface text/icon color (accent-ink).
class AppTextOnAmber {
  static const color = Color(0xFF4A2C00);
}
