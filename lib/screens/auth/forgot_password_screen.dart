import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/logo_mark.dart';
import 'auth_fields.dart';
import '../../utils/phone.dart';

/// Password reset — phone → WhatsApp code → new password.
///   POST /auth/phone/send-otp → POST /auth/phone/reset-password {phone,code,newPassword}
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Step { phone, reset }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phone = TextEditingController(text: kDefaultDial);
  final _otp = TextEditingController();
  final _password = TextEditingController();

  _Step _step = _Step.phone;
  bool _showPassword = false;
  bool _loading = false;
  int _resend = 0;
  Timer? _resendTimer;

  String get _fullPhone => _phone.text;
  bool get _phoneValid => isValidPhone(_phone.text);
  bool get _canReset =>
      _otp.text.length >= 6 &&
      _password.text.length >= 8 &&
      RegExp(r'\d').hasMatch(_password.text);

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _password.dispose();
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

  Future<void> _sendCode() async {
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
      setState(() => _step = _Step.reset);
      _startResend();
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendCode() async {
    if (_loading || _resend > 0) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).sendOtp(_fullPhone);
      _otp.clear();
      _startResend();
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (!_canReset || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).resetPassword(_fullPhone, _otp.text, _password.text);
      if (!mounted) return;
      Toasts.success('auth.login.reset_success'.tr());
      context.go('/auth/login');
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _back() {
    if (_step == _Step.reset) {
      setState(() => _step = _Step.phone);
    } else {
      context.canPop() ? context.pop() : context.go('/auth/login');
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
                onTap: _back,
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
            if (_step == _Step.phone) ..._phoneStep(dark) else ..._resetStep(dark),
          ],
        ),
      ),
    );
  }

  List<Widget> _phoneStep(bool dark) {
    return [
      Center(
        child: Text('auth.login.otp_reset_hint'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
      ),
      const SizedBox(height: 16),
      PhoneField(controller: _phone, dark: dark, onChanged: () => setState(() {})),
      const SizedBox(height: 16),
      AppButton(
        label: 'auth.register.send_code_btn'.tr(),
        loading: _loading,
        onPressed: _phoneValid && !_loading ? _sendCode : null,
      ),
    ];
  }

  List<Widget> _resetStep(bool dark) {
    return [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(
          child: Text('${'auth.login.otp_reset_sent'.tr()} $_fullPhone',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
        ),
      ]),
      const SizedBox(height: 20),
      OtpField(
        controller: _otp,
        dark: dark,
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      PasswordField(
        controller: _password,
        dark: dark,
        hint: 'auth.login.new_password_label'.tr(),
        obscure: !_showPassword,
        onToggle: () => setState(() => _showPassword = !_showPassword),
        onChanged: () => setState(() {}),
        onSubmit: _canReset ? _submit : null,
      ),
      const SizedBox(height: 6),
      Text('auth.login.reset_min_chars'.tr(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
      const SizedBox(height: 16),
      AppButton(
        label: 'auth.login.save_password'.tr(),
        loading: _loading,
        onPressed: _canReset && !_loading ? _submit : null,
      ),
      const SizedBox(height: 16),
      Center(
        child: _resend > 0
            ? Text('auth.login.resend_in'.tr(namedArgs: {'n': '$_resend'}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400))
            : GestureDetector(
                onTap: _resendCode,
                behavior: HitTestBehavior.opaque,
                child: Text('auth.login.resend_btn'.tr(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BrandColors.c600)),
              ),
      ),
    ];
  }
}
