import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../widgets/app_button.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key, this.userId, this.tripId});
  final String? userId;
  final String? tripId;

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  static const _categories = ['safety', 'fraud', 'behavior', 'payment', 'other'];
  String _category = 'behavior';
  final _desc = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (_sent) {
      return Scaffold(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: BrandColors.c600, shape: BoxShape.circle),
                  child: const Icon(Icons.check, size: 44, color: Colors.white),
                ),
                const SizedBox(height: 18),
                Text('complaint.success_title'.tr(),
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : InkColors.c900)),
                const SizedBox(height: 8),
                Text('complaint.success_hint'.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c400)),
                const SizedBox(height: 24),
                SizedBox(
                  width: 200,
                  child: AppButton(
                    label: 'detail.back'.tr(),
                    variant: AppButtonVariant.brand,
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final valid = _desc.text.trim().length >= 20;
    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text('complaint.title'.tr(),
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          Text('complaint.subtitle'.tr(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: InkColors.c400)),
          const SizedBox(height: 16),
          Text('complaint.category_label'.tr(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _categories)
                GestureDetector(
                  onTap: () => setState(() => _category = c),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: _category == c
                          ? BrandColors.c600
                          : (dark ? InkColors.c900 : Colors.white),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: _category == c
                              ? BrandColors.c600
                              : (dark ? InkColors.c800 : InkColors.c200)),
                    ),
                    child: Text('complaint.categories.$c'.tr(),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _category == c
                                ? Colors.white
                                : (dark ? InkColors.c200 : InkColors.c700))),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('complaint.description_label'.tr(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
          const SizedBox(height: 8),
          TextField(
            controller: _desc,
            maxLines: 5,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            style: TextStyle(fontSize: 14, color: dark ? Colors.white : InkColors.c900),
            decoration: InputDecoration(
              hintText: 'complaint.description_placeholder'.tr(),
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
          if (!valid)
            Text('complaint.description_min'.tr(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CoralColors.c500)),
          const SizedBox(height: 12),
          Text('complaint.photos_label'.tr(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: InkColors.c400)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                color: dark ? InkColors.c900 : Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(
                    color: dark ? InkColors.c800 : InkColors.c200, style: BorderStyle.solid),
              ),
              child: const Center(child: Icon(Icons.add_a_photo_outlined, color: InkColors.c400)),
            ),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'complaint.submit_btn'.tr(),
            onPressed: valid ? () => setState(() => _sent = true) : null,
          ),
        ],
      ),
    );
  }
}
