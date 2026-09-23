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
import '../../utils/deferred_action.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/logo_mark.dart';
import 'auth_fields.dart';
import '../../utils/phone.dart';

/// Passwordless auth — the only login method on mobile.
///   phone → WhatsApp code → verify
///     • registered number → sign in (full history)
///     • new number        → name + surname → create account (no password)
/// The session persists (silent refresh on launch) until the user logs out.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum _Step { phone, otp, name }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController(text: kDefaultDial);
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _surname = TextEditingController();

  _Step _step = _Step.phone;
  bool _isNew = false; // set by checkPhone before sending the code
  bool _loading = false;
  int _resend = 0;
  Timer? _resendTimer;

  String get _fullPhone => _phone.text;
  bool get _phoneValid => isValidPhone(_phone.text);
  bool get _canSubmitName =>
      _name.text.trim().isNotEmpty && _surname.text.trim().isNotEmpty;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _name.dispose();
    _surname.dispose();
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
    if (!mounted) return;
    // Resume a guest intent parked before the login redirect (TTL-guarded);
    // anything bad/expired falls through to home.
    final deferred = takeDeferredAction(ref.read(hiveBoxProvider));
    final tripId = deferred?.payload['tripId'];
    final requestId = deferred?.payload['requestId'];
    if (deferred?.type == 'book_trip' && tripId is String && tripId.isNotEmpty) {
      context.go('/trips/$tripId?book=1');
    } else if (deferred?.type == 'respond_request' && requestId is String && requestId.isNotEmpty) {
      context.go('/requests/$requestId');
    } else {
      context.go('/');
    }
  }

  // Step 1: check whether the number exists, then send a WhatsApp code.
  Future<void> _start() async {
    if (!_phoneValid) {
      Toasts.error('auth.login.enter_phone_first'.tr());
      return;
    }
    if (_loading || _resend > 0) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authServiceProvider);
      final info = await auth.checkPhone(_fullPhone);
      _isNew = !((info['exists'] as bool?) ?? false);
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
      _otp.clear();
      _startResend();
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Step 2: code entered. Existing → sign in; new → collect name + surname.
  void _onOtpReady() {
    if (_otp.text.length < 6 || _loading) return;
    if (_isNew) {
      setState(() => _step = _Step.name);
    } else {
      _signIn();
    }
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      final result = await ref.read(authServiceProvider).verifyOtp(_fullPhone, _otp.text);
      final token = result.accessToken;
      if (token == null) {
        Toasts.error('errors.global_desc'.tr());
        return;
      }
      await _finishSession(token);
    } catch (e) {
      Toasts.error(friendlyError(e));
      _otp.clear();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Step 3 (new users only): create the account passwordless.
  Future<void> _createAccount() async {
    if (!_canSubmitName || _loading) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(authServiceProvider).register(
            phone: _fullPhone,
            code: _otp.text,
            name: _name.text.trim(),
            surname: _surname.text.trim(),
          );
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

  void _back() {
    if (_step == _Step.name) {
      setState(() => _step = _Step.otp);
    } else if (_step == _Step.otp) {
      setState(() => _step = _Step.phone);
    } else {
      context.canPop() ? context.pop() : context.go('/');
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
            if (_step == _Step.phone)
              ..._phoneStep(dark)
            else if (_step == _Step.otp)
              ..._otpStep(dark)
            else
              ..._nameStep(dark),
          ],
        ),
      ),
    );
  }

  List<Widget> _phoneStep(bool dark) {
    return [
      Center(
        child: Text('auth.register.phone_hint'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
      ),
      const SizedBox(height: 16),
      PhoneField(controller: _phone, dark: dark, onChanged: () => setState(() {})),
      const SizedBox(height: 16),
      AppButton(
        label: 'auth.register.send_code_btn'.tr(),
        loading: _loading,
        onPressed: _phoneValid && !_loading ? _start : null,
      ),
      const SizedBox(height: 16),
      Center(
        child: GestureDetector(
          onTap: () => context.push('/auth/forgot-password'),
          behavior: HitTestBehavior.opaque,
          child: Text('auth.login.forgot_password'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BrandColors.c600)),
        ),
      ),
    ];
  }

  List<Widget> _otpStep(bool dark) {
    return [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
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
          if (v.length == 6) _onOtpReady();
        },
      ),
      const SizedBox(height: 16),
      AppButton(
        label: 'auth.login.confirm_btn'.tr(),
        loading: _loading,
        onPressed: _otp.text.length >= 6 && !_loading ? _onOtpReady : null,
      ),
      const SizedBox(height: 16),
      Center(
        child: _resend > 0
            ? Text('auth.login.resend_in'.tr(namedArgs: {'n': '$_resend'}), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400))
            : GestureDetector(
                onTap: _resendCode,
                behavior: HitTestBehavior.opaque,
                child: Text('auth.login.resend_btn'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BrandColors.c600)),
              ),
      ),
    ];
  }

  List<Widget> _nameStep(bool dark) {
    return [
      Center(
        child: Text('auth.register.details_hint'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
      ),
      const SizedBox(height: 16),
      TextFieldBox(
        controller: _name,
        dark: dark,
        hint: 'auth.register.name_label'.tr(),
        autofillHints: const [AutofillHints.givenName],
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 12),
      TextFieldBox(
        controller: _surname,
        dark: dark,
        hint: 'auth.register.surname_label'.tr(),
        autofillHints: const [AutofillHints.familyName],
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 16),
      AppButton(
        label: 'auth.register.create_btn'.tr(),
        loading: _loading,
        onPressed: _canSubmitName && !_loading ? _createAccount : null,
      ),
    ];
  }
}
