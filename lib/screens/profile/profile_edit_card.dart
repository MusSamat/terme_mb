import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/friendly_error.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';
import '../auth/auth_fields.dart';

/// Editable personal-info card (name + bio) → PATCH /users/me. Holds its
/// controllers in state (the old inline fields were recreated every rebuild and
/// never saved).
class ProfileEditCard extends ConsumerStatefulWidget {
  const ProfileEditCard({super.key, required this.dark});
  final bool dark;

  @override
  ConsumerState<ProfileEditCard> createState() => _ProfileEditCardState();
}

class _ProfileEditCardState extends ConsumerState<ProfileEditCard> {
  late final TextEditingController _name;
  late final TextEditingController _bio;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).user;
    _name = TextEditingController(text: u?.name ?? '');
    _bio = TextEditingController(text: u?.bio ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2 || _loading) return;
    setState(() => _loading = true);
    try {
      final updated = await ref.read(profileServiceProvider).update(name: name, bio: _bio.text.trim());
      ref.read(authProvider.notifier).updateUser(updated);
      Toasts.success('profile.saved'.tr());
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
        child: Text('profile.personal_section'.tr().toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: InkColors.c400)),
      ),
      LabeledField(
        label: 'auth.register.name_label'.tr(),
        child: TextFieldBox(controller: _name, dark: dark, hint: 'auth.register.name_label'.tr(), onChanged: () => setState(() {})),
      ),
      const SizedBox(height: 12),
      LabeledField(
        label: 'profile.bio_title'.tr(),
        child: TextField(
          controller: _bio,
          maxLines: 3,
          maxLength: 300,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900),
          decoration: InputDecoration(
            filled: true,
            fillColor: dark ? InkColors.c800 : InkColors.c50,
            counterText: '',
            hintText: 'profile.bio_placeholder'.tr(),
            hintStyle: const TextStyle(color: InkColors.c400, fontWeight: FontWeight.w600),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: BrandColors.c500, width: 2)),
          ),
        ),
      ),
      const SizedBox(height: 14),
      AppButton(label: 'profile.save'.tr(), loading: _loading, onPressed: _name.text.trim().length >= 2 ? _save : null),
    ]);
  }
}
