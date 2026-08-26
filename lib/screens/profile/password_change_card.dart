import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/friendly_error.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../auth/auth_fields.dart';

/// Change-password form for profile settings — current + new + repeat, wired to
/// PATCH /users/me/password. Mirrors the web PasswordForm.
class PasswordChangeCard extends ConsumerStatefulWidget {
  const PasswordChangeCard({super.key, required this.dark});

  final bool dark;

  @override
  ConsumerState<PasswordChangeCard> createState() => _PasswordChangeCardState();
}

class _PasswordChangeCardState extends ConsumerState<PasswordChangeCard> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _repeat = TextEditingController();
  bool _showCurrent = false;
  bool _showNext = false;
  bool _loading = false;

  bool get _valid =>
      _current.text.isNotEmpty &&
      _next.text.length >= 8 &&
      RegExp(r'\d').hasMatch(_next.text) &&
      _next.text == _repeat.text;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_valid || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(authServiceProvider).setPassword(_next.text, currentPassword: _current.text);
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _repeat.clear();
      setState(() {});
      Toasts.success('password_form.success'.tr());
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('profile.password_section'.tr().toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: InkColors.c400)),
      ),
      PasswordField(
        controller: _current,
        dark: dark,
        hint: 'password_form.current_label'.tr(),
        obscure: !_showCurrent,
        onToggle: () => setState(() => _showCurrent = !_showCurrent),
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 10),
      PasswordField(
        controller: _next,
        dark: dark,
        hint: 'password_form.new_label'.tr(),
        obscure: !_showNext,
        onToggle: () => setState(() => _showNext = !_showNext),
        onChanged: () => setState(() {}),
      ),
      const SizedBox(height: 10),
      PasswordField(
        controller: _repeat,
        dark: dark,
        hint: 'password_form.repeat_label'.tr(),
        obscure: !_showNext,
        onToggle: () => setState(() => _showNext = !_showNext),
        onChanged: () => setState(() {}),
        onSubmit: _valid ? _submit : null,
      ),
      if (_repeat.text.isNotEmpty && _next.text != _repeat.text) ...[
        const SizedBox(height: 6),
        Text('password_form.mismatch'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CoralColors.c600)),
      ],
      const SizedBox(height: 14),
      AppButton(label: 'password_form.save'.tr(), loading: _loading, onPressed: _valid ? _submit : null),
    ]);
  }
}
