import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/self_user.dart';
import '../../providers/auth_provider.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/logo_mark.dart';

/// Login — 1:1 port of auth/login (login step): logo + wordmark, Telegram
/// primary, «или по телефону» divider, phone + password, «Войти», forgot /
/// register. Real OTP/Telegram flow is ТЗ step 3; DEV buttons fake a session.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _devLogin(ActiveMode mode) {
    final user = SelfUser(
      id: 'dev-user',
      name: mode == ActiveMode.driver ? 'Дев Водитель' : 'Дев Пассажир',
      roles: mode == ActiveMode.driver ? const ['passenger', 'driver'] : const ['passenger'],
      phone: '+996700000000',
      phoneVerified: true,
      telegramLinked: true,
      language: context.locale.languageCode == 'kg' ? 'kg' : 'ru',
      rating: 4.8,
      ratingCount: 24,
      loyaltyTier: 'traveler',
      loyaltyPoints: 180,
      createdAt: DateTime(2024, 3, 15),
    );
    ref.read(authProvider.notifier).setActiveMode(mode);
    ref.read(authProvider.notifier).setSession(user, accessToken: 'dev-token');
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    InputDecoration field(String hint, {Widget? suffix}) => InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: InkColors.c400, fontWeight: FontWeight.w700),
          filled: true,
          fillColor: dark ? InkColors.c800 : InkColors.c50,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: const BorderSide(color: BrandColors.c500, width: 2)),
        );

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.arrow_back),
              ),
            ),
            const SizedBox(height: 24),
            // Brand mark + wordmark
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: AppShadows.brandCta),
                child: const LogoMark(size: 64),
              ),
            ),
            const SizedBox(height: 12),
            const Center(child: Wordmark(fontSize: 30)),
            const SizedBox(height: 24),
            // Telegram primary (Telegram blue #0088cc)
            GestureDetector(
              onTap: () {},
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFF0088CC), borderRadius: BorderRadius.circular(AppRadii.lg)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.send, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('auth.login.login_telegram'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ]),
              ),
            ),
            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                Expanded(child: Container(height: 1, color: dark ? InkColors.c700 : InkColors.c200)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('auth.login.or_phone'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400))),
                Expanded(child: Container(height: 1, color: dark ? InkColors.c700 : InkColors.c200)),
              ]),
            ),
            // Phone
            Container(
              height: 52,
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(color: dark ? InkColors.c800 : InkColors.c50, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
              child: Row(children: [
                const Text('+996 ', style: TextStyle(fontWeight: FontWeight.w800, color: InkColors.c500)),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.phone,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: dark ? Colors.white : InkColors.c900),
                    decoration: const InputDecoration(hintText: '700 123 456', hintStyle: TextStyle(color: InkColors.c400), border: InputBorder.none),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            // Password
            TextField(
              controller: _password,
              obscureText: !_showPassword,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: dark ? Colors.white : InkColors.c900),
              decoration: field('auth.login.password_placeholder'.tr(),
                  suffix: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 18, color: InkColors.c400),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  )),
            ),
            const SizedBox(height: 16),
            AppButton(label: 'auth.login.login_btn'.tr(), onPressed: () {}),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () {},
                child: Text('auth.login.forgot_password'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: InkColors.c500)),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: () => context.push('/auth/register'),
                behavior: HitTestBehavior.opaque,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${'auth.login.no_account'.tr()} ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400)),
                  TextSpan(text: 'auth.login.register_link'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? BrandColors.c300 : BrandColors.c700)),
                ])),
              ),
            ),
            const SizedBox(height: 28),
            // ── DEV login (temporary) ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: dark ? InkColors.c900 : InkColors.c100, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: dark ? InkColors.c800 : InkColors.c200)),
              child: Column(children: [
                const Text('DEV — быстрый вход без бэкенда', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: InkColors.c400)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: AppButton(label: 'Пассажир', variant: AppButtonVariant.brand, height: 44, onPressed: () => _devLogin(ActiveMode.passenger))),
                  const SizedBox(width: 8),
                  Expanded(child: AppButton(label: 'Водитель', variant: AppButtonVariant.grape, height: 44, onPressed: () => _devLogin(ActiveMode.driver))),
                ]),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
