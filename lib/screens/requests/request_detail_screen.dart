import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../models/passenger_request.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/date_format.dart';
import '../../widgets/airport_extras.dart';
import '../../widgets/action_modal.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/listing_metrics.dart';
import '../../widgets/query_error.dart';
import '../../widgets/request_edit_sheet.dart';
import '../../widgets/seat_meter.dart';
import '../../providers/core_providers.dart';
import '../../utils/deferred_action.dart';
import '../../utils/locale.dart';
import '../../widgets/contact_actions.dart';
import '../../widgets/route_map.dart';
import '../profile/cars_card.dart' show showAddCarSheet;

final _viewed = <String>{};

/// Request detail — 1:1 port of request-detail-pane.tsx (teal-themed, symmetric
/// to the trip detail): passenger header, route spine, details grid, comment,
/// sticky «Откликнуться» + contact reveal.
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ref.watch(requestDetailProvider(id)).when(
      loading: () => Scaffold(backgroundColor: dark ? InkColors.c950 : InkColors.c50, body: const Center(child: CircularProgressIndicator(strokeWidth: 2.6, color: BrandColors.c500))),
      error: (e, _) => Scaffold(backgroundColor: dark ? InkColors.c950 : InkColors.c50, body: Center(child: QueryError(error: e, onRetry: () => ref.invalidate(requestDetailProvider(id))))),
      data: (r) {
        // One deduped view per open (owners never count).
        if (_viewed.add(r.id) && ref.read(authProvider).user?.id != r.passengerId) {
          ref.read(requestsServiceProvider).recordView(r.id).catchError((_) {});
        }
        return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/')),
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
                _routeCard(context, dark, r),
                const SizedBox(height: 12),
                RouteMap(
                  origin: r.origin,
                  destination: r.destination,
                  originPoint: r.originPoint,
                  destinationPoint: r.destinationPoint,
                  accent: BrandColors.c600,
                ),
                const SizedBox(height: 16),
                _details(dark, r),
                if ((r.comment ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _label(dark, 'requests.passenger_comment'.tr()),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: dark ? BrandColors.c500.withValues(alpha: 0.1) : BrandColors.c50, borderRadius: BorderRadius.circular(AppRadii.xl2)),
                    child: Text('«${r.comment!}»', style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w600, color: dark ? InkColors.c200 : InkColors.c700)),
                  ),
                ],
              ],
            ),
          ),
          Builder(builder: (context) {
            final authed = ref.watch(authProvider).isAuthenticated;
            final myId = ref.watch(authProvider).user?.id;
            final isOwner = myId != null && r.passengerId == myId;
            void toLogin() {
              saveDeferredAction(ref.read(hiveBoxProvider), type: 'respond_request', payload: {'requestId': r.id});
              context.push('/auth/login');
            }
            return Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, border: Border(top: BorderSide(color: dark ? InkColors.c800 : InkColors.c100))),
              child: isOwner
                  // Owner: edit / cancel your OWN request — never respond or call yourself.
                  ? (r.status == 'open'
                      ? Row(children: [
                          Expanded(child: _barBtn(Icons.edit_outlined, 'my.act_edit'.tr(), BrandColors.c600, filled: false, onTap: () => showRequestEditSheet(context, r, onSaved: () => ref.invalidate(requestDetailProvider(id))))),
                          const SizedBox(width: 10),
                          Expanded(child: _barBtn(Icons.close, 'my.act_cancel'.tr(), DangerColors.c600, filled: false, onTap: () => _confirmCancel(context, ref, r))),
                        ])
                      : Center(child: Text('requests.my.closed'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400))))
                  // Anyone else: respond (needs a car) + call / WhatsApp. Guests → login.
                  : r.status != 'open'
                  ? Center(child: Text('requests.my.closed'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c400)))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      // Already offered → no second respond (the API answers 409).
                      if (r.responded)
                        Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: BrandColors.c600.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(AppRadii.lg)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle, size: 20, color: BrandColors.c600),
                            const SizedBox(width: 8),
                            Text('card.responded'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BrandColors.c600)),
                          ]),
                        )
                      else
                      GestureDetector(
                        onTap: () async {
                          if (!authed) return toLogin();
                          final cars = await ref.read(carsProvider.future).catchError((_) => const <Never>[]);
                          // A second tap while cars loaded: the first already opened a sheet.
                          if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
                          if (cars.isEmpty) {
                            Toasts.info('requests.need_car_title'.tr(), 'requests.need_car_body'.tr());
                            showAddCarSheet(context, dark: dark);
                            return;
                          }
                          _showRespondSheet(context, r);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AccentColors.c500, borderRadius: BorderRadius.circular(AppRadii.lg), boxShadow: AppShadows.cta),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle, size: 20, color: AccentColors.ink),
                            const SizedBox(width: 8),
                            Text('requests.respond_title'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AccentColors.ink)),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ContactActions(
                        reveal: () => ref.read(requestsServiceProvider).revealContact(r.id),
                        onGuest: authed ? null : toLogin,
                      ),
                    ]),
            );
          }),
        ],
      ),
      );
      },
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
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: filled ? Colors.white : color)),
            ),
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
      Toasts.success('toasts.request_cancelled'.tr());
      if (!context.mounted) return;
      ref.invalidate(myRequestsProvider);
      ref.invalidate(requestDetailProvider(id));
      context.canPop() ? context.pop() : context.go('/');
    } catch (e) {
      Toasts.error(friendlyError(e));
    }
  }

  Widget _passengerHeader(BuildContext context, bool dark, PassengerRequestItem r) {
    final showRating = r.passengerRating != null && r.passengerRatingCount >= 3;
    return GestureDetector(
      onTap: r.passengerId == null ? null : () => context.push('/drivers/${r.passengerId}'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? BrandColors.c500.withValues(alpha: 0.1) : BrandColors.c50,
          borderRadius: BorderRadius.circular(AppRadii.xl2),
          border: Border.all(color: dark ? BrandColors.c500.withValues(alpha: 0.2) : BrandColors.c100),
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
                    Flexible(
                      child: Text(' · ${r.passengerRatingCount} ${'drivers.ratings_count'.tr()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c500)),
                    ),
                  ])
                else
                  Text('requests.new_passenger'.tr(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: InkColors.c500)),
              ],
            ),
          ),
          const Icon(Icons.shield_outlined, size: 18, color: BrandColors.c400),
        ]),
      ),
    );
  }

  Widget _routeCard(BuildContext context, bool dark, PassengerRequestItem r) {
    final kg = isKg(context);
    final wait = r.originPoint?.label(kg) ?? '';
    final drop = r.destinationPoint?.label(kg) ?? '';
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
            Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: BrandColors.c500)),
            Container(width: 2, height: 40, margin: const EdgeInsets.symmetric(vertical: 6), color: dark ? InkColors.c700 : InkColors.c200),
            Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: BrandColors.c400)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.originName(kg), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                Text(wait.isNotEmpty ? '📍 $wait' : 'requests.origin_point'.tr(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c500)),
                const SizedBox(height: 16),
                Text(r.destinationName(kg), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
                Text(drop.isNotEmpty ? '📍 $drop' : 'requests.dest_point'.tr(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c500)),
                if (r.flightNumber != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.flight_rounded, size: 16, color: BrandColors.c600),
                    const SizedBox(width: 6),
                    Text('airport.flight_label'.tr(namedArgs: {'n': r.flightNumber!}),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: BrandColors.c600)),
                  ]),
                ],
                const SizedBox(height: 8),
                AirportExtras(request: r, fontSize: 13),
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
          Text('${r.seatsNeeded}', style: const TextStyle(fontSize: 28, height: 1, fontWeight: FontWeight.w800, color: BrandColors.c600)),
          const SizedBox(height: 6),
          SeatMeter(free: r.seatsNeeded.clamp(1, 4), total: r.seatsNeeded.clamp(1, 4)),
        ])),
      ],
    );
  }

  Widget _label(bool dark, String text) => Text(text.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: InkColors.c500));
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
  late final _price = TextEditingController(text: widget.request.budget > 0 ? '${widget.request.budget}' : '');
  final _message = TextEditingController();
  bool _loading = false;
  // Offer departure: the passenger's requested time (09:00 when the request has
  // no date: tomorrow), never sooner than 40 min from now — the API rejects
  // past times. The driver can change it.
  late DateTime _departAt = _defaultDepart();

  DateTime _defaultDepart() {
    final now = DateTime.now();
    final d = widget.request.departureDate;
    var at = d ?? DateTime(now.year, now.month, now.day + 1, 9);
    final earliest = now.add(const Duration(minutes: 40));
    if (at.isBefore(earliest)) {
      at = DateTime(earliest.year, earliest.month, earliest.day, earliest.hour, (earliest.minute ~/ 15 + 1) * 15);
    }
    return at;
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_departAt));
    if (t == null || !mounted) return;
    setState(() => _departAt = DateTime(_departAt.year, _departAt.month, _departAt.day, t.hour, t.minute));
  }

  @override
  void dispose() {
    _price.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final price = int.tryParse(_price.text.trim());
    if (price == null || price < 50 || price > 10000) {
      Toasts.error('requests.err_price_range'.tr());
      return;
    }
    if (!_departAt.isAfter(DateTime.now())) {
      Toasts.error('api_errors.departure_too_soon'.tr());
      return;
    }
    setState(() => _loading = true);
    try {
      final msg = _message.text.trim();
      await ref.read(requestsServiceProvider).respond(
            widget.request.id,
            price: price,
            departureTime: _departAt.toUtc().toIso8601String(),
            message: msg.isEmpty ? null : msg,
          );
      Toasts.success('toasts.offer_sent'.tr());
      if (!mounted) return;
      ref.invalidate(requestDetailProvider(widget.request.id));
      Navigator.of(context).pop();
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
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
        child: SingleChildScrollView(
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
            const SizedBox(height: 12),
            Text('requests.depart_label'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickTime,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: dark ? InkColors.c800 : InkColors.c50,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
                ),
                child: Row(children: [
                  const Icon(Icons.schedule, size: 18, color: BrandColors.c600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${departureLabel(_departAt).date} · ${hhmm(_departAt)}',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900)),
                  ),
                  const Icon(Icons.edit_outlined, size: 16, color: InkColors.c400),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loading ? null : _submit,
              behavior: HitTestBehavior.opaque,
              child: Opacity(
                opacity: _loading ? 0.6 : 1,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AccentColors.c500, borderRadius: BorderRadius.circular(AppRadii.lg), boxShadow: AppShadows.cta),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: AccentColors.ink))
                      : Text('requests.submit_response'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AccentColors.ink)),
                ),
              ),
            ),
          ],
        ),
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
