import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';

/// «+» → «Что создать?»: a trip (as a driver) or a ride request (as a
/// passenger). The pick only decides the form — it never flips the global
/// mode; the option matching the current mode comes first.
Future<void> showCreateSheet(BuildContext context, WidgetRef ref) async {
  final driverFirst = ref.read(authProvider).activeMode == ActiveMode.driver;
  final pick = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CreateSheet(driverFirst: driverFirst),
  );
  if (pick != null && context.mounted) context.push('/trips/create?kind=$pick');
}

class _CreateSheet extends StatelessWidget {
  const _CreateSheet({required this.driverFirst});

  final bool driverFirst;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final trip = _RoleCard(
      driver: true,
      heading: 'role_prompt.create_driver'.tr(),
      desc: 'role_prompt.create_driver_desc'.tr(),
      dark: dark,
      onTap: () => Navigator.pop(context, 'trip'),
    );
    final request = _RoleCard(
      driver: false,
      heading: 'role_prompt.create_passenger'.tr(),
      desc: 'role_prompt.create_passenger_desc'.tr(),
      dark: dark,
      onTap: () => Navigator.pop(context, 'request'),
    );
    return Container(
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 16),
          Text('role_prompt.create_title'.tr(),
              style: TextStyle(
                  fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
          const SizedBox(height: 4),
          Text('role_prompt.create_sub'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c400)),
          const SizedBox(height: 16),
          driverFirst ? trip : request,
          const SizedBox(height: 10),
          driverFirst ? request : trip,
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
    const accent = BrandColors.c600;
    final asset = driver ? 'assets/icons/role_driver.png' : 'assets/icons/role_passenger.png';
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
                colorFilter: const ColorFilter.mode(accent, BlendMode.srcIn),
                child: Image.asset(asset, width: 40, height: 40, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(heading, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: accent)),
                  const SizedBox(height: 2),
                  Text(desc,
                      style: const TextStyle(fontSize: 13.5, height: 1.25, fontWeight: FontWeight.w600, color: InkColors.c400)),
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
