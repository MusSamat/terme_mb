import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_requests.dart';
import '../../models/passenger_request.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/driver_avatar.dart';
import '../../widgets/verified_badge.dart';

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/requests'),
        ),
        title: Text('requests.request_label'.tr(),
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                _card(dark, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      DriverAvatar(name: r.passengerName, size: AvatarSize.lg, square: true, verified: r.passengerVerified),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Flexible(
                                child: Text(r.passengerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: dark ? Colors.white : InkColors.c900)),
                              ),
                              if (r.passengerVerified) ...[const SizedBox(width: 6), const VerifiedBadge()],
                            ]),
                            const SizedBox(height: 2),
                            if (r.passengerRating != null && r.passengerRatingCount >= 3)
                              Row(children: [
                                const Icon(Icons.star, size: 14, color: AccentColors.c400),
                                const SizedBox(width: 3),
                                Text('${r.passengerRating!.toStringAsFixed(1)} · ${r.passengerRatingCount} ${'drivers.ratings_count'.tr()}',
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w600, color: InkColors.c400)),
                              ])
                            else
                              Text('requests.new_passenger'.tr(),
                                  style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700, color: GrapeColors.c600)),
                          ],
                        ),
                      ),
                    ]),
                  ],
                )),
                const SizedBox(height: 12),
                _card(dark, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kv(dark, 'requests.origin_point'.tr(), r.originCity),
                    const SizedBox(height: 8),
                    _kv(dark, 'requests.dest_point'.tr(), r.destinationCity),
                    const SizedBox(height: 8),
                    _kv(dark, 'requests.date_label'.tr(), r.dateLabel),
                    const SizedBox(height: 8),
                    _kv(dark, 'bookings.seats_label'.tr(), '${r.seatsNeeded}'),
                    const SizedBox(height: 8),
                    _kv(dark, 'requests.price_label'.tr(), '${r.budget} с'),
                  ],
                )),
                if ((r.comment ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _card(dark, Text(r.comment!,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: dark ? InkColors.c200 : InkColors.c700))),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: dark ? InkColors.c900 : Colors.white,
              border: Border(top: BorderSide(color: dark ? InkColors.c800 : InkColors.c100)),
            ),
            child: AppButton(
              label: 'requests.respond_title'.tr(),
              variant: AppButtonVariant.grape,
              onPressed: () => _showRespondSheet(context, r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(bool dark, String k, String v) {
    return Row(
      children: [
        Expanded(
          child: Text(k,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400)),
        ),
        Text(v,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: dark ? Colors.white : InkColors.c900)),
      ],
    );
  }

  Widget _card(bool dark, Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? InkColors.c900 : Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.xl3),
        border: Border.all(color: dark ? InkColors.c800 : InkColors.c100),
        boxShadow: AppShadows.card,
      ),
      child: child,
    );
  }
}

void _showRespondSheet(BuildContext context, PassengerRequestItem r) {
  final price = TextEditingController(text: '${r.budget}');
  final message = TextEditingController();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final dark = Theme.of(ctx).brightness == Brightness.dark;
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? InkColors.c900 : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: InkColors.c300, borderRadius: BorderRadius.circular(999))),
              ),
              const SizedBox(height: 14),
              Text('requests.respond_title'.tr(),
                  style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : InkColors.c900)),
              const SizedBox(height: 14),
              Text('requests.price_label'.tr(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
              const SizedBox(height: 6),
              _sheetField(dark, price, 'requests.price_placeholder'.tr(), number: true),
              const SizedBox(height: 12),
              Text('requests.message_label'.tr(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
              const SizedBox(height: 6),
              _sheetField(dark, message, 'requests.message_placeholder'.tr(), lines: 3),
              const SizedBox(height: 16),
              AppButton(
                label: 'requests.submit_response'.tr(),
                variant: AppButtonVariant.grape,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('toasts.offer_sent'.tr())));
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _sheetField(bool dark, TextEditingController c, String hint, {bool number = false, int lines = 1}) {
  return TextField(
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
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          borderSide: BorderSide(color: dark ? InkColors.c700 : InkColors.c200)),
    ),
  );
}
