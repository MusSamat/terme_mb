import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';

/// Become-a-driver / verification form — port of tappjet_ft driver-reg.
/// Camera capture + upload wire up in ТЗ step 6; here the doc tiles are stubs.
class DriverVerificationScreen extends StatelessWidget {
  const DriverVerificationScreen({super.key});

  static const _docs = [
    ('Водительское удостоверение', Icons.badge_outlined),
    ('Тех. паспорт авто', Icons.description_outlined),
    ('Фото автомобиля', Icons.directions_car_outlined),
    ('Селфи', Icons.face_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
        title: Text('driver_reg.title'.tr(),
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          Text('driver_reg.subtitle'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c400)),
          const SizedBox(height: 16),
          _section(dark, 'driver_reg.car_section'.tr()),
          const SizedBox(height: 10),
          _field(dark, 'driver_reg.make_label'.tr(), 'driver_reg.make_placeholder'.tr()),
          _field(dark, 'driver_reg.model_label'.tr(), 'driver_reg.model_placeholder'.tr()),
          _field(dark, 'driver_reg.year_label'.tr(), 'driver_reg.year_placeholder'.tr()),
          _field(dark, 'driver_reg.color_label'.tr(), 'driver_reg.color_placeholder'.tr()),
          _field(dark, 'driver_reg.plate_label'.tr(), 'driver_reg.plate_placeholder'.tr()),
          const SizedBox(height: 16),
          _section(dark, 'driver_reg.docs_section'.tr()),
          const SizedBox(height: 10),
          for (final (label, icon) in _docs) _docTile(dark, label, icon),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.lock_outline, size: 14, color: InkColors.c400),
            const SizedBox(width: 6),
            Expanded(
              child: Text('driver_reg.privacy_note'.tr(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: InkColors.c400)),
            ),
          ]),
          const SizedBox(height: 20),
          AppButton(
            label: 'create.gate_cta'.tr(),
            variant: AppButtonVariant.grape,
            onPressed: () {
              context.canPop() ? context.pop() : context.go('/profile');
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('create.gate_pending_title'.tr())));
            },
          ),
        ],
      ),
    );
  }

  Widget _section(bool dark, String text) => Text(text,
      style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: dark ? Colors.white : InkColors.c900));

  Widget _field(bool dark, String label, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: InkColors.c400)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: dark ? InkColors.c900 : Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
              ),
              child: TextField(
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: InkColors.c400),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _docTile(bool dark, String label, IconData icon) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: dark ? InkColors.c800 : InkColors.c200),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: dark ? GrapeColors.c300 : GrapeColors.c600),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dark ? Colors.white : InkColors.c900))),
          Text('driver_reg.upload_btn'.tr(),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: GrapeColors.c600)),
        ]),
      );
}
