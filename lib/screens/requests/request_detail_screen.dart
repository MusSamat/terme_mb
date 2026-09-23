import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../models/passenger_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/action_modal.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/listing_metrics.dart';
import '../../widgets/query_error.dart';
import '../../widgets/request_edit_sheet.dart';
import '../../widgets/seat_meter.dart';

/// Request detail — 1:1 port of request-detail-pane.tsx (grape-themed, symmetric
/// to the trip detail): passenger header, route spine, details grid, comment,
/// sticky «Откликнуться» + contact reveal.
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ref.watch(requestDetailProvider(id)).when(
      loading: () => Scaffold(backgroundColor: dark ? InkColors.c950 : InkColors.c50, body: const Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: GrapeColors.c500))),
      error: (e, _) => Scaffold(backgroundColor: dark ? InkColors.c950 : InkColors.c50, body: Center(child: QueryError(error: e, onRetry: () => ref.invalidate(requestDetailProvider(id))))),
      data: (r) => Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/requests')),
        title: Text('requests.request_label'.tr(), style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 20, color: dark ? Colors.white : InkColors.c900)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                _passengerHeader(context, dark, r),
                if (r.metrics != null) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: ListingMetricsRow(metrics: r.metrics)),
                ],
                const SizedBox(height: 16),
                _label(dark, 'request_filters.route_label'.tr()),
                const SizedBox(height: 8),
                _routeCard(dark, r),
                const SizedBox(height: 16),
                _details(dark, r),
                if ((r.comment ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _label(dark, 'requests.passenger_comment'.tr()),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: dark ? GrapeColors.c500.withValues(alpha: 0.1) : GrapeColors.c50, borderRadius: BorderRadius.circular(AppRadii.xl2)),
                    child: Text('«${r.comment!}»', style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600, color: dark ? InkColors.c200 : InkColors.c700)),
                  ),
                ],
              ],
            ),
          ),
          Builder(builder: (context) {
            final myId = ref.watch(authProvider).user?.id;
            final isOwner = myId != null && r.passengerId == myId;
            return Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, border: Border(top: BorderSide(color: dark ? InkColors.c800 : InkColors.c100))),
              child: isOwner
                  // Owner: edit / cancel your OWN request — never respond or call yourself.
                  ? (r.status == 'open'
                      ? Row(children: [
                          Expanded(child: _barBtn(Icons.edit_outlined, 'my.act_edit'.tr(), GrapeColors.c600, filled: false, onTap: () => showRequestEditSheet(context, r, onSaved: () => ref.invalidate(requestDetailProvider(id))))),
                          const SizedBox(width: 10),
                          Expanded(child: _barBtn(Icons.close, 'my.act_cancel'.tr(), CoralColors.c600, filled: false, onTap: () => _confirmCancel(context, ref, r))),
                        ])
                      : Center(child: Text('requests.my.closed'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400))))
                  // Driver: respond + reveal contact.
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      GestureDetector(
                        onTap: () => _showRespondSheet(context, r),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: GrapeColors.c600, borderRadius: BorderRadius.circular(AppRadii.lg), boxShadow: AppShadows.indigoCta),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('requests.respond_title'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ContactReveal(onReveal: () => ref.read(requestsServiceProvider).revealContact(r.id)),
                    ]),
            );
          }),
        ],
      ),
      ),
    );
  }

  Widget _barBtn(IconData icon, String label, Color color, {required bool filled, required VoidCallback onTap}) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: filled ? Colors.white : color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: filled ? Colors.white : color)),
          ]),
        ),
      );

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref, PassengerRequestItem r) async {
    final ok = await showConfirmModal(
      context,
      icon: Icons.cancel_outlined,
      title: 'requests.my.cancel_title'.tr(),
      confirmLabel: 'requests.my.cancel_btn'.tr(),
      cancelLabel: 'book_form.cancel'.tr(),
      danger: true,
    );
    if (!ok) return;
    try {
      await ref.read(requestsServiceProvider).cancel(r.id);
      ref.invalidate(myRequestsProvider);
      ref.invalidate(requestDetailProvider(id));
      Toasts.success('toasts.request_cancelled'.tr());
      if (context.mounted) context.canPop() ? context.pop() : context.go('/requests');
    } catch (e) {
      Toasts.error(friendlyError(e));
    }
  }

  Widget _passengerHeader(BuildContext context, bool dark, PassengerRequestItem r) {
    final showRating = r.passengerRating != null && r.passengerRatingCount >= 3;
    return GestureDetector(
      onTap: () => context.push('/drivers/${r.id}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? GrapeColors.c500.withValues(alpha: 0.1) : GrapeColors.c50,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: dark ? GrapeColors.c500.withValues(alpha: 0.2) : GrapeColors.c100),
        ),
        child: Row(children: [
          DriverAvatar(name: r.passengerName, size: AvatarSize.lg, square: true, verified: r.passengerVerified),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.passengerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                const SizedBox(height: 2),
                if (showRating)
                  Row(children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(Icons.star, size: 12, color: i <= r.passengerRating!.round() ? AccentColors.c400 : InkColors.c300),
                    const SizedBox(width: 5),
                    Text(r.passengerRating!.toStringAsFixed(1), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                    Text(' · ${r.passengerRatingCount} ${'drivers.ratings_count'.tr()}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c500)),
                  ])
                else
                  Text('requests.new_passenger'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
              ],
            ),
          ),
          const Icon(Icons.shield_outlined, size: 18, color: GrapeColors.c400),
        ]),
      ),
    );
  }

  Widget _routeCard(bool dark, PassengerRequestItem r) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? InkColors.c800 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl2),
        border: Border.all(color: dark ? InkColors.c700 : InkColors.c100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            const SizedBox(height: 4),
            Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: GrapeColors.c500)),
            Container(width: 2, height: 40, margin: const EdgeInsets.symmetric(vertical: 6), color: dark ? InkColors.c700 : InkColors.c200),
            Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: GrapeColors.c400)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.originCity, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                Text('requests.origin_point'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c500)),
                const SizedBox(height: 16),
                Text(r.destinationCity, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                Text('requests.dest_point'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(bool dark, PassengerRequestItem r) {
    Widget card(Widget child) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: dark ? InkColors.c800 : Colors.white, borderRadius: BorderRadius.circular(AppRadii.xl2), border: Border.all(color: dark ? InkColors.c700 : InkColors.c100)),
            child: child,
          ),
        );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.calendar_today, size: 12, color: InkColors.c400),
            const SizedBox(width: 6),
            Text('requests.date_detail'.tr().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: InkColors.c400)),
          ]),
          const SizedBox(height: 6),
          Text(r.dateLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900)),
        ])),
        const SizedBox(width: 12),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.group, size: 12, color: InkColors.c400),
            const SizedBox(width: 6),
            Text('requests.seats_needed'.tr().toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: InkColors.c400)),
          ]),
          const SizedBox(height: 4),
          Text('${r.seatsNeeded}', style: const TextStyle(fontSize: 28, height: 1, fontWeight: FontWeight.w800, color: GrapeColors.c600)),
          const SizedBox(height: 6),
          SeatMeter(free: r.seatsNeeded.clamp(1, 4), total: r.seatsNeeded.clamp(1, 4)),
        ])),
      ],
    );
  }

  Widget _label(bool dark, String text) => Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: InkColors.c500));
}

class _ContactReveal extends StatefulWidget {
  const _ContactReveal({required this.onReveal});
  final Future<String?> Function() onReveal;
  @override
  State<_ContactReveal> createState() => _ContactRevealState();
}

class _ContactRevealState extends State<_ContactReveal> {
  String? _phone;
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    if (_phone != null) {
      await launchUrl(Uri.parse('tel:$_phone'));
      return;
    }
    setState(() => _busy = true);
    try {
      final p = await widget.onReveal();
      if (mounted) setState(() => _phone = p);
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final revealed = _phone != null;
    return GestureDetector(
      onTap: _tap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? InkColors.c900 : Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: dark ? GrapeColors.c500.withValues(alpha: 0.4) : GrapeColors.c200),
        ),
        child: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: GrapeColors.c500))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(revealed ? Icons.call : Icons.phone_outlined, size: 18, color: dark ? GrapeColors.c300 : GrapeColors.c600),
                const SizedBox(width: 8),
                Text(revealed ? _phone! : 'contact.call'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? GrapeColors.c300 : GrapeColors.c700)),
              ]),
      ),
    );
  }
}

// ── Respond sheet ────────────────────────────────────────────────────────────

void _showRespondSheet(BuildContext context, PassengerRequestItem r) {
  showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RespondSheet(request: r),
  );
}

class _RespondSheet extends ConsumerStatefulWidget {
  const _RespondSheet({required this.request});
  final PassengerRequestItem request;
  @override
  ConsumerState<_RespondSheet> createState() => _RespondSheetState();
}

class _RespondSheetState extends ConsumerState<_RespondSheet> {
  late final _price = TextEditingController(text: '${widget.request.budget}');
  final _message = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _price.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final price = int.tryParse(_price.text.trim());
    if (price == null || price < 1 || price > 100000) {
      Toasts.error('requests.err_price_range'.tr());
      return;
    }
    setState(() => _loading = true);
    try {
      final msg = _message.text.trim();
      // Backend requires a departureTime — offer for the day the passenger asked
      // (default 09:00), falling back to tomorrow if the request has no date.
      final day = widget.request.departureDate ?? DateTime.now().add(const Duration(days: 1));
      final departAt = DateTime(day.year, day.month, day.day, 9).toUtc().toIso8601String();
      await ref.read(requestsServiceProvider).respond(
            widget.request.id,
            price: price,
            departureTime: departAt,
            message: msg.isEmpty ? null : msg,
          );
      ref.invalidate(requestDetailProvider(widget.request.id));
      if (mounted) Navigator.of(context).pop();
      Toasts.success('toasts.offer_sent'.tr());
    } catch (e) {
      Toasts.error(friendlyError(e));
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 14),
            Text('requests.respond_title'.tr(), style: TextStyle(fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
            const SizedBox(height: 14),
            Text('requests.price_label'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
            const SizedBox(height: 6),
            _field(dark, _price, 'requests.price_placeholder'.tr(), number: true),
            const SizedBox(height: 12),
            Text('requests.message_label'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
            const SizedBox(height: 6),
            _field(dark, _message, 'requests.message_placeholder'.tr(), lines: 3),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loading ? null : _submit,
              behavior: HitTestBehavior.opaque,
              child: Opacity(
                opacity: _loading ? 0.6 : 1,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: GrapeColors.c600, borderRadius: BorderRadius.circular(AppRadii.lg), boxShadow: AppShadows.indigoCta),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Text('requests.submit_response'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _field(bool dark, TextEditingController c, String hint, {bool number = false, int lines = 1}) => TextField(
      controller: c,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
      maxLines: lines,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: InkColors.c400),
        filled: true,
        fillColor: dark ? InkColors.c800 : InkColors.c50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200)),
      ),
    );
