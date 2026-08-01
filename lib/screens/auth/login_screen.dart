import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/friendly_error.dart';
import '../../models/self_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/config.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/logo_mark.dart';

/// Login — real Telegram auth: phone → «Получить код» (delivered to Telegram) →
/// OTP verify → session. Plus a Telegram bot deep-link login. DEV buttons only
/// appear in mock mode.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { phone, otp }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  _Step _step = _Step.phone;
  bool _loading = false;
  int _resend = 0;
  Timer? _resendTimer;
  Timer? _pollTimer;

  String get _fullPhone => '+996${_phone.text}';
  bool get _phoneValid => _phone.text.length == 9;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _resendTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startResend() {
    _resendTimer?.cancel();
    setState(() => _resend = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resend <= 1) t.cancel();
      if (mounted) setState(() => _resend = _resend > 0 ? _resend - 1 : 0);
    });
  }

  Future<void> _sendCode() async {
    if (!_phoneValid || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).sendOtp(_fullPhone);
      if (!mounted) return;
      setState(() => _step = _Step.otp);
      _startResend();
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_otp.text.length < 4 || _loading) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final result = await auth.verifyOtp(_fullPhone, _otp.text);
      final token = result.accessToken;
      if (token == null) {
        Toasts.error('errors.global_desc'.tr());
        return;
      }
      ref.read(tokenStoreProvider).set(token); // authenticate the me() call
      final me = await auth.me();
      ref.read(authProvider.notifier).setSession(me, accessToken: token);
      if (mounted) context.go('/');
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _telegramLogin() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final init = await auth.botLoginInit();
      final deepLink = init['deepLink'] as String?;
      final token = init['token'] as String?;
      if (deepLink == null || token == null) {
        Toasts.error('errors.global_desc'.tr());
        return;
      }
      await launchUrl(Uri.parse(deepLink), mode: LaunchMode.externalApplication);
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
        try {
          final status = await auth.botLoginStatus(token);
          if (status == 'done') {
            t.cancel();
            final result = await auth.botLoginClaim(token);
            final tk = result.accessToken;
            if (tk != null) {
              ref.read(tokenStoreProvider).set(tk);
              final me = await auth.me();
              ref.read(authProvider.notifier).setSession(me, accessToken: tk);
              if (mounted) context.go('/');
            }
          } else if (status == 'expired' || status == 'not_found') {
            t.cancel();
          }
        } catch (_) {
          t.cancel();
        }
      });
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  if (_step == _Step.otp) {
                    setState(() => _step = _Step.phone);
                  } else {
                    context.canPop() ? context.pop() : context.go('/');
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.arrow_back),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: AppShadows.brandCta),
                child: const LogoMark(size: 64),
              ),
            ),
            const SizedBox(height: 12),
            const Center(child: Wordmark(fontSize: 30)),
            const SizedBox(height: 28),
            if (_step == _Step.phone) ..._phoneStep(dark) else ..._otpStep(dark),
          ],
        ),
      ),
    );
  }

  List<Widget> _phoneStep(bool dark) {
    return [
      Container(
        height: 52,
        padding: const EdgeInsets.only(left: 14),
        decoration: BoxDecoration(
          color: dark ? InkColors.c800 : InkColors.c50,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: dark ? InkColors.c700 : InkColors.c200, width: 2),
        ),
        child: Row(children: [
          const Text('+996 ', style: TextStyle(fontWeight: FontWeight.w800, color: InkColors.c500)),
          Expanded(
            child: TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: dark ? Colors.white : InkColors.c900),
              decoration: const InputDecoration(hintText: '700 123 456', hintStyle: TextStyle(color: InkColors.c400), border: InputBorder.none),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      AppButton(
        label: 'auth.login.continue_btn'.tr(),
        loading: _loading,
        onPressed: _phoneValid ? _sendCode : null,
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Expanded(child: Divider(color: InkColors.c200)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('или', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400))),
          Expanded(child: Divider(color: InkColors.c200)),
        ]),
      ),
      GestureDetector(
        onTap: _telegramLogin,
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
      const SizedBox(height: 16),
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
      if (AppConfig.useMock) ...[
        const SizedBox(height: 28),
        _devBlock(dark),
      ],
    ];
  }

  List<Widget> _otpStep(bool dark) {
    return [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.send, size: 16, color: Color(0xFF0088CC)),
        const SizedBox(width: 8),
        Flexible(
          child: Text('Код отправлен в Telegram на $_fullPhone',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
        ),
      ]),
      const SizedBox(height: 20),
      TextField(
        controller: _otp,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 6,
        autofocus: true,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        onChanged: (v) {
          setState(() {});
          if (v.length == 6) _verify();
        },
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 8, color: dark ? Colors.white : InkColors.c900),
        decoration: InputDecoration(
          counterText: '',
          hintText: '••••••',
          hintStyle: const TextStyle(color: InkColors.c300, letterSpacing: 8),
          filled: true,
          fillColor: dark ? InkColors.c800 : InkColors.c50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: const BorderSide(color: BrandColors.c500, width: 2)),
        ),
      ),
      const SizedBox(height: 16),
      AppButton(label: 'auth.login.login_btn'.tr(), loading: _loading, onPressed: _otp.text.length >= 4 ? _verify : null),
      const SizedBox(height: 16),
      Center(
        child: _resend > 0
            ? Text('${'auth.login.sending'.tr()} · $_resend', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400))
            : GestureDetector(
                onTap: _sendCode,
                behavior: HitTestBehavior.opaque,
                child: Text('auth.login.login_sms'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BrandColors.c600)),
              ),
      ),
    ];
  }

  Widget _devBlock(bool dark) => Container(
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
      );
}
