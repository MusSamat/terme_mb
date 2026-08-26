import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/friendly_error.dart';
import '../models/passenger_request.dart';
import '../providers/data_providers.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';
import 'action_modal.dart';
import 'app_button.dart';
import 'app_toast.dart';

/// Edit a passenger's own open request (seats / date / comment). Shared by the
/// «Мои» list and the request detail (owner view) so both stay identical.
Future<void> showRequestEditSheet(BuildContext context, PassengerRequestItem request, {VoidCallback? onSaved}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RequestEditSheet(request: request, onSaved: onSaved),
  );
}

class RequestEditSheet extends ConsumerStatefulWidget {
  const RequestEditSheet({super.key, required this.request, this.onSaved});
  final PassengerRequestItem request;
  final VoidCallback? onSaved;
  @override
  ConsumerState<RequestEditSheet> createState() => _RequestEditSheetState();
}

class _RequestEditSheetState extends ConsumerState<RequestEditSheet> {
  late int _seats = widget.request.seatsNeeded;
  late final _comment = TextEditingController(text: widget.request.comment ?? '');
  late DateTime _date = widget.request.departureDate ?? DateTime.now().add(const Duration(days: 1));
  bool _loading = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) setState(() => _date = DateTime(picked.year, picked.month, picked.day, 12));
  }

  Future<void> _save() async {
    if (_loading) return;
    final ok = await showConfirmModal(
      context,
      icon: Icons.edit_outlined,
      title: 'requests.my.edit'.tr(),
      body: 'my.edit_confirm'.tr(),
      confirmLabel: 'profile.save'.tr(),
      cancelLabel: 'book_form.cancel'.tr(),
    );
    if (!ok) return;
    setState(() => _loading = true);
    try {
      await ref.read(requestsServiceProvider).edit(widget.request.id, {
        'seatsNeeded': _seats,
        'departureDate': _date.toUtc().toIso8601String(),
        'comment': _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      });
      ref.invalidate(myRequestsProvider);
      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop();
      Toasts.success('toasts.saved'.tr());
    } catch (e) {
      Toasts.error(friendlyError(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _stepBtn(String s, bool enabled, VoidCallback onTap) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: enabled ? GrapeColors.c600 : InkColors.c300, borderRadius: BorderRadius.circular(10)),
          child: Text(s, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget label(String t) => Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999)))),
          const SizedBox(height: 14),
          Text('requests.my.edit'.tr(), style: TextStyle(fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
          const SizedBox(height: 14),
          label('requests.my.seats_label'.tr()),
          const SizedBox(height: 6),
          Row(children: [
            _stepBtn('−', _seats > 1, () => setState(() => _seats--)),
            SizedBox(width: 48, child: Text('$_seats', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark ? Colors.white : InkColors.c900))),
            _stepBtn('+', _seats < 8, () => setState(() => _seats++)),
          ]),
          const SizedBox(height: 12),
          label('requests.my.date_label'.tr()),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: dark ? InkColors.c800 : InkColors.c50, borderRadius: BorderRadius.circular(AppRadii.lg), border: Border.all(color: dark ? InkColors.c700 : InkColors.c200)),
              child: Row(children: [
                const Icon(Icons.event, size: 18, color: InkColors.c500),
                const SizedBox(width: 8),
                Text('${_date.day.toString().padLeft(2, '0')}.${_date.month.toString().padLeft(2, '0')}.${_date.year}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          label('book_form.comment_label'.tr()),
          const SizedBox(height: 6),
          TextField(
            controller: _comment,
            maxLines: 2,
            maxLength: 300,
            style: TextStyle(fontSize: 14, color: dark ? Colors.white : InkColors.c900),
            decoration: InputDecoration(
              hintText: 'book_form.comment_placeholder'.tr(),
              hintStyle: const TextStyle(color: InkColors.c400),
              counterText: '',
              filled: true,
              fillColor: dark ? InkColors.c800 : InkColors.c50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200, width: 2)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: const BorderSide(color: BrandColors.c500, width: 2)),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(label: 'profile.save'.tr(), loading: _loading, onPressed: _save),
        ]),
      ),
    );
  }
}
