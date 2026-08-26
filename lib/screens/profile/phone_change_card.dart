import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/friendly_error.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../auth/auth_fields.dart';

/// Shows the current phone with a "change" action that runs the secured phone
/// change: re-auth with password → OTP to the new number → confirm.
class PhoneChangeCard extends ConsumerWidget {
  const PhoneChangeCard({super.key, required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phone = ref.watch(authProvider).user?.phone ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('profile.phone_section'.tr().toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: InkColors.c400)),
      ),
      Row(children: [
        const Icon(Icons.phone, size: 18, color: InkColors.c400),
        const SizedBox(width: 10),
        Expanded(child: Text(phone, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900))),
        GestureDetector(
          onTap: () => showModalBottomSheet<void>(
            useRootNavigator: true,
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _PhoneChangeSheet(dark: dark),
          ),
          behavior: HitTestBehavior.opaque,
          child: Text('profile.change'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BrandColors.c600)),
        ),
      ]),
    ]);
  }
}

class _PhoneChangeSheet extends ConsumerStatefulWidget {
  const _PhoneChangeSheet({required this.dark});
  final bool dark;
  @override
  ConsumerState<_PhoneChangeSheet> createState() => _PhoneChangeSheetState();
}

enum _Step { form, otp }

class _PhoneChangeSheetState extends ConsumerState<_PhoneChangeSheet> {
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  _Step _step = _Step.form;
  bool _showPass = false;
  bool _loading = false;

  String get _fullPhone => '+996${_phone.text}';

  @override
  void dispose() {
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_phone.text.length != 9 || _password.text.isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(profileServiceProvider).startPhoneChange(_fullPhone, _password.text);
      if (mounted) setState(() => _step = _Step.otp);
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    if (_otp.text.length != 6 || _loading) return;
    setState(() => _loading = true);
    try {
      final profile = ref.read(profileServiceProvider);
      await profile.confirmPhoneChange(_fullPhone, _otp.text);
      // Tokens were reissued server-side — refresh the profile so the UI updates.
      final auth = ref.read(authServiceProvider);
      final me = await auth.me();
      ref.read(authProvider.notifier).updateUser(me);
      if (mounted) Navigator.of(context).pop();
      Toasts.success('profile.phone_changed'.tr());
    } catch (e) {
      Toasts.error(friendlyError(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 14),
          Text('profile.change_phone_title'.tr(), style: TextStyle(fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
          const SizedBox(height: 14),
          if (_step == _Step.form) ...[
            PhoneField(controller: _phone, dark: dark, onChanged: () => setState(() {})),
            const SizedBox(height: 10),
            PasswordField(
              controller: _password,
              dark: dark,
              hint: 'password_form.current_label'.tr(),
              obscure: !_showPass,
              onToggle: () => setState(() => _showPass = !_showPass),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: 'auth.register.send_code_btn'.tr(),
              loading: _loading,
              onPressed: (_phone.text.length == 9 && _password.text.isNotEmpty) ? _start : null,
            ),
          ] else ...[
            Text('${'auth.register.otp_dm_hint'.tr()} $_fullPhone', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c500)),
            const SizedBox(height: 12),
            OtpField(controller: _otp, dark: dark, onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            AppButton(
              label: 'auth.login.confirm_btn'.tr(),
              loading: _loading,
              onPressed: _otp.text.length == 6 ? _confirm : null,
            ),
          ],
        ]),
      ),
    );
  }
}
