import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_toast.dart';

/// Permanent account deletion (DELETE /users/me) with an explicit confirmation.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _confirm = false;
  bool _loading = false;

  Future<void> _delete() async {
    if (!_confirm || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(profileServiceProvider).deleteAccount();
      ref.read(authProvider.notifier).clearSession();
      if (mounted) context.go('/');
    } catch (e) {
      Toasts.error(friendlyError(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/profile')),
        title: Text('delete_account.title'.tr(),
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 20, color: dark ? Colors.white : InkColors.c900)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dark ? CoralColors.c600.withValues(alpha: 0.1) : CoralColors.c50,
              borderRadius: BorderRadius.circular(AppRadii.xl2),
              border: Border.all(color: dark ? CoralColors.c600.withValues(alpha: 0.3) : CoralColors.c100),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: CoralColors.c600),
              const SizedBox(width: 10),
              Expanded(child: Text('delete_account.warning'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CoralColors.c700, height: 1.5))),
            ]),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _confirm = !_confirm),
            behavior: HitTestBehavior.opaque,
            child: Row(children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(value: _confirm, onChanged: (v) => setState(() => _confirm = v ?? false), activeColor: CoralColors.c600),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text('delete_account.confirm_label'.tr(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? InkColors.c200 : InkColors.c700))),
            ]),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: (_confirm && !_loading) ? _delete : null,
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: _confirm ? 1 : 0.4,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: CoralColors.c600, borderRadius: BorderRadius.circular(AppRadii.lg)),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : Text('delete_account.delete_btn'.tr(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
