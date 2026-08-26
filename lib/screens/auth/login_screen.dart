import 'dart:async';

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
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/logo_mark.dart';
import 'auth_fields.dart';

/// Classical login — phone + password. "Forgot password" runs the Telegram-OTP
/// reset flow (send code → verify → new password). Registration lives on a
/// separate screen. No other login methods.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { login, otp, reset }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  _Step _step = _Step.login;
  bool _loading = false;
  bool _showPassword = false;
  bool _showNewPassword = false;
  int _resend = 0;
  Timer? _resendTimer;

  String get _fullPhone => '+996${_phone.text}';
  bool get _phoneValid => _phone.text.length == 9;
  bool get _canLogin => _phoneValid && _password.text.isNotEmpty;
  bool get _canReset =>
      _newPassword.text.length >= 8 && _newPassword.text == _confirmPassword.text;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _otp.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _resendTimer?.cancel();
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

  Future<void> _finishSession(String token) async {
    final auth = ref.read(authServiceProvider);
    ref.read(tokenStoreProvider).set(token);
    final me = await auth.me();
    ref.read(authProvider.notifier).setSession(me, accessToken: token);
    if (mounted) context.go('/');
  }

  // ── Login with password ──────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_canLogin || _loading) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(authServiceProvider).loginPassword(_fullPhone, _password.text);
      final token = result.accessToken;
      if (token == null) {
        Toasts.error('errors.global_desc'.tr());
        return;
      }
      await _finishSession(token);
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Forgot password: send Telegram OTP ───────────────────────────────────
  Future<void> _sendResetCode() async {
    if (!_phoneValid) {
      Toasts.error('auth.login.enter_phone_first'.tr());
      return;
    }
    if (_loading || _resend > 0) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).sendOtp(_fullPhone);
      if (!mounted) return;
      _otp.clear();
      setState(() => _step = _Step.otp);
      _startResend();
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Verify OTP → temporary session for the reset call ────────────────────
  Future<void> _verify() async {
    if (_otp.text.length < 6 || _loading) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(authServiceProvider).verifyOtp(_fullPhone, _otp.text);
      final token = result.accessToken;
      if (token == null) {
        Toasts.error('errors.global_desc'.tr());
        return;
      }
      ref.read(tokenStoreProvider).set(token);
      if (!mounted) return;
      setState(() => _step = _Step.reset);
    } catch (e) {
      Toasts.error(friendlyError(e));
      _otp.clear();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Set the new password ─────────────────────────────────────────────────
  Future<void> _reset() async {
    if (!_canReset || _loading) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      await auth.resetPassword(_newPassword.text);
      final token = ref.read(tokenStoreProvider).accessToken;
      if (token != null) {
        await _finishSession(token);
      } else if (mounted) {
        context.go('/');
      }
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                    setState(() => _step = _Step.login);
                  } else if (_step == _Step.reset) {
                    setState(() => _step = _Step.otp);
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
            if (_step == _Step.login)
              ..._loginStep(dark)
            else if (_step == _Step.otp)
              ..._otpStep(dark)
            else
              ..._resetStep(dark),
          ],
        ),
      ),
    );
  }

  List<Widget> _loginStep(bool dark) {
    return [
      PhoneField(controller: _phone, dark: dark, onChanged: () => setState(() {})),
      const SizedBox(height: 12),
      PasswordField(
        controller: _password,
        dark: dark,
        hint: 'auth.login.password_placeholder'.tr(),
        obscure: !_showPassword,
        onToggle: () => setState(() => _showPassword = !_showPassword),
        onChanged: () => setState(() {}),
        onSubmit: _canLogin ? _login : null,
      ),
      const SizedBox(height: 16),
      AppButton(label: 'auth.login.login_btn'.tr(), loading: _loading, onPressed: _canLogin ? _login : null),
      const SizedBox(height: 16),
      Center(
        child: GestureDetector(
          onTap: (_loading || _resend > 0) ? null : _sendResetCode,
          behavior: HitTestBehavior.opaque,
          child: Text(
            _resend > 0 ? 'auth.login.resend_in'.tr(namedArgs: {'n': '$_resend'}) : 'auth.login.forgot_password'.tr(),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: (_resend > 0) ? InkColors.c400 : InkColors.c500,
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
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
    ];
  }

  List<Widget> _otpStep(bool dark) {
    return [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.send, size: 16, color: Color(0xFF0088CC)),
        const SizedBox(width: 8),
        Flexible(
          child: Text('${'auth.login.otp_dm_hint'.tr()} $_fullPhone',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
        ),
      ]),
      const SizedBox(height: 20),
      OtpField(
        controller: _otp,
        dark: dark,
        onChanged: (v) {
          setState(() {});
          if (v.length == 6) _verify();
        },
      ),
      const SizedBox(height: 16),
      AppButton(label: 'auth.login.confirm_btn'.tr(), loading: _loading, onPressed: _otp.text.length >= 6 ? _verify : null),
      const SizedBox(height: 16),
      Center(
        child: _resend > 0
            ? Text('auth.login.resend_in'.tr(namedArgs: {'n': '$_resend'}), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400))
            : GestureDetector(
                onTap: _sendResetCode,
                behavior: HitTestBehavior.opaque,
                child: Text('auth.login.resend_btn'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BrandColors.c600)),
              ),
      ),
    ];
  }

  List<Widget> _resetStep(bool dark) {
    return [
      Center(
        child: Text('auth.login.reset_title'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
      ),
      const SizedBox(height: 20),
      PasswordField(
        controller: _newPassword,
        dark: dark,
        hint: 'auth.login.new_password_label'.tr(),
        obscure: !_showNewPassword,
        onToggle: () => setState(() => _showNewPassword = !_showNewPassword),
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 12),
      PasswordField(
        controller: _confirmPassword,
        dark: dark,
        hint: 'auth.login.confirm_password_label'.tr(),
        obscure: !_showNewPassword,
        onToggle: () => setState(() => _showNewPassword = !_showNewPassword),
        onChanged: () => setState(() {}),
        onSubmit: _canReset ? _reset : null,
      ),
      const SizedBox(height: 8),
      Text('auth.register.password_rule'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
      const SizedBox(height: 16),
      AppButton(label: 'auth.login.set_password_btn'.tr(), loading: _loading, onPressed: _canReset ? _reset : null),
    ];
  }
}
