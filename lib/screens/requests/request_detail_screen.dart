import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_requests.dart';
import '../../models/passenger_request.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/seat_meter.dart';

/// Request detail — 1:1 port of request-detail-pane.tsx (grape-themed, symmetric
/// to the trip detail): passenger header, route spine, details grid, comment,
/// sticky «Откликнуться» + contact reveal.
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final r = mockRequestById(id);

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go('/requests')),
        title: Text('requests.request_label'.tr(), style: TextStyle(fontFamily: 'Fredoka', fontWeight: FontWeight.w800, fontSize: 20, color: dark ? Colors.white : InkColors.c900)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                _passengerHeader(context, dark, r),
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
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, border: Border(top: BorderSide(color: dark ? InkColors.c800 : InkColors.c100))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
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
              const _ContactReveal(phone: '+996 700 123 456'),
            ]),
          ),
        ],
      ),
    );
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
  const _ContactReveal({required this.phone});
  final String phone;
  @override
  State<_ContactReveal> createState() => _ContactRevealState();
}

class _ContactRevealState extends State<_ContactReveal> {
  bool _revealed = false;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _revealed = true),
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
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_revealed ? Icons.call : Icons.phone_outlined, size: 18, color: dark ? GrapeColors.c300 : GrapeColors.c600),
          const SizedBox(width: 8),
          Text(_revealed ? widget.phone : 'contact.call'.tr(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark ? GrapeColors.c300 : GrapeColors.c700)),
        ]),
      ),
    );
  }
}

// ── Respond sheet ────────────────────────────────────────────────────────────

void _showRespondSheet(BuildContext context, PassengerRequestItem r) {
  final price = TextEditingController(text: '${r.budget}');
  final message = TextEditingController();
  showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final dark = Theme.of(ctx).brightness == Brightness.dark;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 14),
              Text('requests.respond_title'.tr(), style: TextStyle(fontFamily: 'Fredoka', fontSize: 20, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900)),
              const SizedBox(height: 14),
              Text('requests.price_label'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
              const SizedBox(height: 6),
              _field(dark, price, 'requests.price_placeholder'.tr(), number: true),
              const SizedBox(height: 12),
              Text('requests.message_label'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
              const SizedBox(height: 6),
              _field(dark, message, 'requests.message_placeholder'.tr(), lines: 3),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                  Toasts.success('toasts.offer_sent'.tr());
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: GrapeColors.c600, borderRadius: BorderRadius.circular(AppRadii.lg), boxShadow: AppShadows.indigoCta),
                  child: Text('requests.submit_response'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
