import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';

class RateScreen extends ConsumerStatefulWidget {
  const RateScreen({super.key, required this.tripId, required this.rateeId});
  final String tripId;
  final String rateeId;

  @override
  ConsumerState<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends ConsumerState<RateScreen> {
  int _score = 0;
  bool _sent = false;
  bool _submitting = false;
  final _comment = TextEditingController();
  final Set<String> _tags = {};

  // Tag sets differ by who you're rating (backend DRIVER_TAGS / PASSENGER_TAGS).
  // A driver (active mode) rates a passenger → passenger tags; else driver tags.
  static const _driverPos = ['on_time', 'clean_car', 'safe_driving', 'pleasant_chat', 'comfortable_ride'];
  static const _driverNeg = ['late', 'dirty_car', 'dangerous_driving', 'rudeness', 'car_mismatch'];
  static const _passengerPos = ['arrived_on_time', 'polite', 'no_heavy_luggage', 'pleasant_chat'];
  static const _passengerNeg = ['late', 'too_much_luggage', 'rudeness', 'no_show'];

  bool get _ratingPassenger => ref.read(authProvider).activeMode == ActiveMode.driver;
  List<String> get _positiveTags => _ratingPassenger ? _passengerPos : _driverPos;
  List<String> get _negativeTags => _ratingPassenger ? _passengerNeg : _driverNeg;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_score < 1 || _submitting) return;
    setState(() => _submitting = true);
    try {
      final comment = _comment.text.trim();
      await ref.read(ratingsServiceProvider).create(
            tripId: widget.tripId,
            rateeId: widget.rateeId,
            score: _score,
            tags: _tags.toList(),
            comment: comment.isEmpty ? null : comment,
          );
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      Toasts.error(friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

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
            Text('rate.question_generic'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Manrope',
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_score >= 4 ? 'rate.liked'.tr() : 'rate.disliked'.tr(),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: InkColors.c400)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in (_score >= 4 ? _positiveTags : _negativeTags))
                    GestureDetector(
                      onTap: () => setState(() => _tags.contains(tag) ? _tags.remove(tag) : _tags.add(tag)),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          color: _tags.contains(tag) ? (dark ? BrandColors.c500.withValues(alpha: 0.15) : BrandColors.c50) : (dark ? InkColors.c900 : Colors.white),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _tags.contains(tag) ? BrandColors.c500 : (dark ? InkColors.c700 : InkColors.c200)),
                        ),
                        child: Text('ratings.tags.$tag'.tr(),
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _tags.contains(tag) ? (dark ? BrandColors.c300 : BrandColors.c700) : (dark ? InkColors.c200 : InkColors.c700))),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('rate.comment_label'.tr(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
              const SizedBox(height: 8),
              TextField(
                controller: _comment,
                maxLines: 4,
                maxLength: 500, // mini-app parity: MAX_COMMENT = 500 (+ counter)
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
              label: 'rate.submit'.tr(),
              loading: _submitting,
              onPressed: _score > 0 && !_submitting ? _submit : null,
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
                      fontFamily: 'Manrope',
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
