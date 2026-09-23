import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/core_providers.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import '../utils/config.dart' show StorageKeys;

/// Shared role-select bottom sheet — twin of the web RoleSelectModal.
///
/// Two call sites:
///  • [create] = false — the one-time «gate» on the home hub after first
///    login/reopen. Picking (or dismissing) records `roleChosen` so it never
///    asks again; the pick also sets the active mode.
///  • [create] = true — the «+» button. One button, two outcomes: the pick
///    sets the active mode and routes to the create form (a trip as a driver,
///    a request as a passenger). Never records `roleChosen` — create always asks.
Future<void> showRoleSelectSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool create,
}) async {
  final chosen = await showModalBottomSheet<ActiveMode>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _RoleSelectSheet(create: create),
  );

  final notifier = ref.read(authProvider.notifier);
  if (chosen == null) {
    // Dismiss: the gate accepts the current default (passenger) and stops
    // nagging; create just cancels.
    if (!create) _markRoleChosen(ref);
    return;
  }

  notifier.setActiveMode(chosen); // choice A — the pick always updates the mode
  if (create) {
    if (context.mounted) context.push('/trips/create');
  } else {
    _markRoleChosen(ref);
  }
}

/// Has the one-time role gate already been answered on this device?
bool hasChosenRole(WidgetRef ref) =>
    ref.read(hiveBoxProvider).get(StorageKeys.roleChosen) == '1';

void _markRoleChosen(WidgetRef ref) =>
    ref.read(hiveBoxProvider).put(StorageKeys.roleChosen, '1');

class _RoleSelectSheet extends StatelessWidget {
  const _RoleSelectSheet({required this.create});

  final bool create;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: InkColors.c300,
                  borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            (create ? 'role_prompt.create_title' : 'role_prompt.gate_title')
                .tr(),
            style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: dark ? Colors.white : InkColors.c900),
          ),
          const SizedBox(height: 4),
          Text(
            (create ? 'role_prompt.create_sub' : 'role_prompt.gate_sub').tr(),
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c400),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            driver: false,
            heading: (create ? 'role_prompt.create_passenger' : 'role_prompt.passenger')
                .tr(),
            desc: (create
                    ? 'role_prompt.create_passenger_desc'
                    : 'role_prompt.gate_passenger_desc')
                .tr(),
            dark: dark,
            onTap: () => Navigator.pop(context, ActiveMode.passenger),
          ),
          const SizedBox(height: 10),
          _RoleCard(
            driver: true,
            heading:
                (create ? 'role_prompt.create_driver' : 'role_prompt.driver').tr(),
            desc: (create
                    ? 'role_prompt.create_driver_desc'
                    : 'role_prompt.gate_driver_desc')
                .tr(),
            dark: dark,
            onTap: () => Navigator.pop(context, ActiveMode.driver),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.driver,
    required this.heading,
    required this.desc,
    required this.dark,
    required this.onTap,
  });

  final bool driver;
  final String heading;
  final String desc;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = driver ? GrapeColors.c600 : BrandColors.c600;
    final asset = driver
        ? 'assets/icons/role_driver.png'
        : 'assets/icons/role_passenger.png';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: dark ? 0.10 : 0.05),
          borderRadius: BorderRadius.circular(AppRadii.xl3),
          border: Border.all(color: accent.withValues(alpha: dark ? 0.4 : 0.25), width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: dark ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
                child: Image.asset(asset, width: 40, height: 40, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading,
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900, color: accent)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: InkColors.c400)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 22, color: accent.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
