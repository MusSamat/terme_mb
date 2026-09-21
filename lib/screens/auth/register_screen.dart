import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
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
import '../../utils/phone.dart';

/// Classical registration — phone → WhatsApp OTP (own page) → name + surname +
/// password (own page) → account created. If the number already exists, we stop
/// and point the user to sign in / restore password.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

enum _Step { phone, otp, details }

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _phone = TextEditingController(text: kDefaultDial);
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _password = TextEditingController();

  _Step _step = _Step.phone;
  bool _loading = false;
  bool _showPassword = false;
  bool _existing = false;
  bool _terms = false;
  int _resend = 0;
  Timer? _resendTimer;

  String get _fullPhone => _phone.text;
  bool get _phoneValid => isValidPhone(_phone.text);
  bool get _otpValid => _otp.text.length == 6;
  bool get _canSubmit =>
      _name.text.trim().isNotEmpty &&
      _surname.text.trim().isNotEmpty &&
      _password.text.length >= 8 &&
      RegExp(r'\d').hasMatch(_password.text) && // backend requires a digit
      _terms;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _name.dispose();
    _surname.dispose();
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

  // Step 1: reject already-registered numbers, otherwise send the OTP.
  Future<void> _start() async {
    if (!_phoneValid || _loading || _resend > 0) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final info = await auth.checkPhone(_fullPhone);
      if ((info['exists'] as bool?) ?? false) {
        if (mounted) setState(() => _existing = true);
        return;
      }
      await auth.sendOtp(_fullPhone);
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

  Future<void> _resendCode() async {
    if (_loading || _resend > 0) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).sendOtp(_fullPhone);
      if (mounted) _startResend();
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (!_canSubmit || _loading) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final result = await auth.register(
        phone: _fullPhone,
        code: _otp.text,
        name: _name.text.trim(),
        surname: _surname.text.trim(),
        password: _password.text,
      );
      final token = result.accessToken;
      if (token == null) {
        Toasts.error('errors.global_desc'.tr());
        return;
      }
      ref.read(tokenStoreProvider).set(token);
      final me = await auth.me();
      ref.read(authProvider.notifier).setSession(me, accessToken: token);
      if (mounted) context.go('/');
    } catch (e) {
      Toasts.error(friendlyError(e));
      // Code likely wrong/expired — send them back to re-enter it.
      if (mounted) {
        _otp.clear();
        setState(() => _step = _Step.otp);
      }
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
                  if (_step == _Step.details) {
                    setState(() => _step = _Step.otp);
                  } else if (_step == _Step.otp) {
                    setState(() => _step = _Step.phone);
                  } else {
                    context.canPop() ? context.pop() : context.go('/auth/login');
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
            const SizedBox(height: 6),
            Center(
              child: Text(
                _step == _Step.phone
                    ? 'auth.register.phone_hint'.tr()
                    : _step == _Step.otp
                        ? 'auth.register.code_hint'.tr()
                        : 'auth.register.details_hint'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400),
              ),
            ),
            const SizedBox(height: 24),
            if (_step == _Step.phone)
              ..._phoneStep(dark)
            else if (_step == _Step.otp)
              ..._otpStep(dark)
            else
              ..._detailsStep(dark),
          ],
        ),
      ),
    );
  }

  List<Widget> _phoneStep(bool dark) {
    if (_existing) {
      return [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: dark ? BrandColors.c500.withValues(alpha: 0.1) : BrandColors.c50,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: dark ? BrandColors.c500.withValues(alpha: 0.3) : BrandColors.c200, width: 2),
          ),
          child: Column(children: [
            Text('auth.register.already_registered_title'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900)),
            const SizedBox(height: 6),
            Text('auth.register.already_registered_desc'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c500)),
            const SizedBox(height: 16),
            AppButton(
              label: 'auth.register.restore_password'.tr(),
              onPressed: () => context.go('/auth/login'),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => context.go('/auth/login'),
              behavior: HitTestBehavior.opaque,
              child: Text('auth.register.sign_in'.tr(),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? BrandColors.c300 : BrandColors.c700)),
            ),
          ]),
        ),
      ];
    }
    return [
      PhoneField(controller: _phone, dark: dark, onChanged: () => setState(() => _existing = false)),
      const SizedBox(height: 12),
      // WhatsApp-green: this button triggers WhatsApp code delivery.
      _WhatsappButton(
        label: _resend > 0 ? 'auth.register.resend_in'.tr(namedArgs: {'n': '$_resend'}) : 'auth.register.send_code_btn'.tr(),
        loading: _loading,
        onPressed: (_phoneValid && _resend == 0) ? _start : null,
      ),
      const SizedBox(height: 16),
      Center(
        child: GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go('/auth/login'),
          behavior: HitTestBehavior.opaque,
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${'auth.register.have_account'.tr()} ', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400)),
            TextSpan(text: 'auth.register.sign_in'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? BrandColors.c300 : BrandColors.c700)),
          ])),
        ),
      ),
    ];
  }

  List<Widget> _otpStep(bool dark) {
    return [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Flexible(
          child: Text('${'auth.register.otp_dm_hint'.tr()} $_fullPhone',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
        ),
      ]),
      const SizedBox(height: 20),
      OtpField(controller: _otp, dark: dark, onChanged: (v) {
        setState(() {});
        if (v.length == 6) setState(() => _step = _Step.details);
      }),
      const SizedBox(height: 12),
      Center(
        child: _resend > 0
            ? Text('auth.register.resend_in'.tr(namedArgs: {'n': '$_resend'}), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: InkColors.c400))
            : GestureDetector(
                onTap: _resendCode,
                behavior: HitTestBehavior.opaque,
                child: Text('auth.register.resend_btn'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BrandColors.c600)),
              ),
      ),
      const SizedBox(height: 16),
      AppButton(
        label: 'auth.register.continue_btn'.tr(),
        onPressed: _otpValid ? () => setState(() => _step = _Step.details) : null,
      ),
    ];
  }

  List<Widget> _detailsStep(bool dark) {
    return [
      LabeledField(
        label: 'auth.register.name_label'.tr(),
        child: TextFieldBox(controller: _name, dark: dark, hint: 'auth.register.name_label'.tr(), onChanged: () => setState(() {}), autofillHints: const [AutofillHints.givenName]),
      ),
      const SizedBox(height: 14),
      LabeledField(
        label: 'auth.register.surname_label'.tr(),
        child: TextFieldBox(controller: _surname, dark: dark, hint: 'auth.register.surname_label'.tr(), onChanged: () => setState(() {}), autofillHints: const [AutofillHints.familyName]),
      ),
      const SizedBox(height: 14),
      LabeledField(
        label: 'auth.register.password_label'.tr(),
        child: PasswordField(
          controller: _password,
          dark: dark,
          hint: 'auth.register.password_label'.tr(),
          obscure: !_showPassword,
          onToggle: () => setState(() => _showPassword = !_showPassword),
          onChanged: () => setState(() {}),
          onSubmit: _canSubmit ? _register : null,
        ),
      ),
      const SizedBox(height: 6),
      Text('auth.register.password_rule'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
      const SizedBox(height: 16),
      _termsRow(dark),
      const SizedBox(height: 16),
      AppButton(label: 'auth.register.create_btn'.tr(), loading: _loading, onPressed: _canSubmit ? _register : null),
    ];
  }

  // Terms + privacy consent — required to enable account creation.
  Widget _termsRow(bool dark) {
    final linkStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: dark ? BrandColors.c300 : BrandColors.c700,
    );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: _terms,
          onChanged: (v) => setState(() => _terms = v ?? false),
          activeColor: BrandColors.c600,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text.rich(TextSpan(
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c500),
            children: [
              TextSpan(text: '${'auth.register.terms_prefix'.tr()} '),
              TextSpan(
                text: 'auth.register.terms_link'.tr(),
                style: linkStyle,
                recognizer: TapGestureRecognizer()..onTap = () => context.push('/terms'),
              ),
              TextSpan(text: ' ${'auth.register.terms_and'.tr()} '),
              TextSpan(
                text: 'auth.register.privacy_link'.tr(),
                style: linkStyle,
                recognizer: TapGestureRecognizer()..onTap = () => context.push('/privacy'),
              ),
            ],
          )),
        ),
      ),
    ]);
  }
}

/// Primary action button (brand amber) for the "get WhatsApp code" action.
class _WhatsappButton extends StatelessWidget {
  const _WhatsappButton({required this.label, required this.onPressed, this.loading = false});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AccentColors.c500, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AccentColors.ink))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.chat_bubble_outline, size: 18, color: AccentColors.ink),
                  const SizedBox(width: 8),
                  Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AccentColors.ink)),
                ]),
        ),
      ),
    );
  }
}
