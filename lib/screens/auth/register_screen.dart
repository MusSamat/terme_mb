import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';

/// Registration (phone step) — real OTP/Telegram flow lands in ТЗ step 3.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

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
              const SizedBox(height: 24),
              Text('welcome.cta_primary'.tr(),
                  style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : InkColors.c900)),
              const SizedBox(height: 20),
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
                      decoration: const InputDecoration(
                        hintText: '700 123 456',
                        hintStyle: TextStyle(color: InkColors.c400),
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
              AppButton(label: 'onboarding.next'.tr(), onPressed: () {}),
              const Spacer(),
              Center(
                child: GestureDetector(
                  onTap: () => context.go('/auth/login'),
                  child: Text('welcome.have_account'.tr(),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: BrandColors.c600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
