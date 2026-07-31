import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_trips.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';

class RateScreen extends StatefulWidget {
  const RateScreen({super.key, required this.tripId, required this.rateeId});
  final String tripId;
  final String rateeId;

  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  int _score = 0;
  bool _sent = false;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = mockTripById(widget.tripId).driver.name;

    if (_sent) return _success(dark);

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text('rate.question'.tr(namedArgs: {'name': name}),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : InkColors.c900)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  GestureDetector(
                    onTap: () => setState(() => _score = i),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i <= _score ? Icons.star : Icons.star_border,
                        size: 44,
                        color: i <= _score ? AccentColors.c400 : InkColors.c300,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('rate.label_$_score'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: InkColors.c500)),
            const SizedBox(height: 24),
            if (_score > 0) ...[
              Text('rate.comment_label'.tr(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
              const SizedBox(height: 8),
              TextField(
                controller: _comment,
                maxLines: 4,
                style: TextStyle(fontSize: 14, color: dark ? Colors.white : InkColors.c900),
                decoration: InputDecoration(
                  hintText: 'rate.comment_placeholder'.tr(),
                  hintStyle: const TextStyle(color: InkColors.c400),
                  filled: true,
                  fillColor: dark ? InkColors.c900 : Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      borderSide: BorderSide(color: dark ? InkColors.c800 : InkColors.c200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      borderSide: BorderSide(color: dark ? InkColors.c800 : InkColors.c200)),
                ),
              ),
            ],
            const Spacer(),
            AppButton(
              label: 'book_form.submit'.tr(),
              onPressed: _score > 0 ? () => setState(() => _sent = true) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _success(bool dark) {
    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: BrandColors.c600, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text('rate.success_title'.tr(),
                  style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: dark ? Colors.white : InkColors.c900)),
              const SizedBox(height: 8),
              Text('rate.success_desc'.tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c400)),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: AppButton(
                  label: 'rate.my_bookings_link'.tr(),
                  variant: AppButtonVariant.brand,
                  onPressed: () => context.canPop() ? context.pop() : context.go('/my/bookings'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
