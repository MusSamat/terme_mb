import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/friendly_error.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import 'app_toast.dart';

/// `+996 555 12-34-56` → `996555123456` (wa.me wants digits only).
String phoneDigits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

Future<void> callPhone(String phone) async {
  try {
    final ok = await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
    if (!ok) Toasts.error('contact.launch_failed'.tr());
  } catch (_) {
    Toasts.error('contact.launch_failed'.tr());
  }
}

Future<void> openWhatsapp(String phone) async {
  try {
    final ok = await launchUrl(Uri.parse('https://wa.me/${phoneDigits(phone)}'),
        mode: LaunchMode.externalApplication);
    if (!ok) Toasts.error('contact.launch_failed'.tr());
  } catch (_) {
    Toasts.error('contact.launch_failed'.tr());
  }
}

/// «Позвонить» + «WhatsApp» for a listing's owner. With [reveal], the number is
/// fetched (audited) on the first tap of «Показать номер»; with [phone] it's
/// already known (accepted bookings, chat). [onGuest] replaces the reveal for
/// signed-out viewers (→ login).
class ContactActions extends StatefulWidget {
  const ContactActions({super.key, this.reveal, this.phone, this.onGuest, this.compact = false})
      : assert(reveal != null || phone != null || onGuest != null);

  final Future<String?> Function()? reveal;
  final String? phone;
  final VoidCallback? onGuest;
  final bool compact;

  @override
  State<ContactActions> createState() => _ContactActionsState();
}

class _ContactActionsState extends State<ContactActions> {
  late String? _phone = widget.phone;
  bool _busy = false;

  Future<void> _reveal() async {
    if (widget.onGuest != null) return widget.onGuest!();
    if (_busy || widget.reveal == null) return;
    setState(() => _busy = true);
    try {
      final p = await widget.reveal!();
      if (!mounted) return;
      if (p == null || p.isEmpty) {
        Toasts.error('contact.no_phone'.tr());
      } else {
        setState(() => _phone = p);
      }
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final h = widget.compact ? 40.0 : 46.0;
    final phone = _phone;

    Widget btn({required IconData icon, required String label, required Color color, required VoidCallback onTap, bool filled = false}) =>
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: filled ? color : (dark ? InkColors.c900 : Colors.white),
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: filled ? color : color.withValues(alpha: 0.35)),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 18, color: filled ? Colors.white : color),
                  const SizedBox(width: 7),
                  Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: filled ? Colors.white : color)),
                ]),
              ),
            ),
          ),
        );

    if (phone == null) {
      return Row(children: [
        btn(
          icon: Icons.phone_outlined,
          label: 'contact.show_number'.tr(),
          color: dark ? BrandColors.c300 : BrandColors.c600,
          onTap: _busy ? () {} : _reveal,
        ),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (!widget.compact)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: SelectableText(phone,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dark ? InkColors.c300 : InkColors.c500)),
        ),
      Row(children: [
        btn(icon: Icons.call, label: 'contact.call'.tr(), color: BrandColors.c600, filled: true, onTap: () => callPhone(phone)),
        const SizedBox(width: 8),
        btn(icon: Icons.chat_rounded, label: 'contact.whatsapp'.tr(), color: const Color(0xFF1FAF55), onTap: () => openWhatsapp(phone)),
      ]),
    ]);
  }
}
