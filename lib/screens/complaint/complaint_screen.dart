import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/friendly_error.dart';
import '../../providers/data_providers.dart';
import '../../theme/colors.dart';
import '../../theme/dimens.dart';
import '../../utils/image_pick.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_toast.dart';

class ComplaintScreen extends ConsumerStatefulWidget {
  const ComplaintScreen({super.key, this.userId, this.tripId});
  final String? userId;
  final String? tripId;

  @override
  ConsumerState<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends ConsumerState<ComplaintScreen> {
  // Backend enum: safety | fraud | rudeness | no_show | other.
  static const _categories = ['safety', 'fraud', 'rudeness', 'no_show', 'other'];
  String _category = 'safety';
  final _desc = TextEditingController();
  final List<File> _photos = [];
  bool _sent = false;
  bool _submitting = false;

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    if (_photos.length >= 5) return;
    try {
      final picked = await pickCompressedImages(limit: 5 - _photos.length);
      if (picked.isNotEmpty && mounted) setState(() => _photos.addAll(picked));
    } catch (e) {
      Toasts.error(friendlyError(e));
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (widget.userId == null && widget.tripId == null) {
      Toasts.error('complaint.err_no_target'.tr());
      return;
    }
    if (_desc.text.trim().length < 20) return;
    setState(() => _submitting = true);
    try {
      await ref.read(complaintsServiceProvider).create(
            category: _category,
            description: _desc.text.trim(),
            targetUserId: widget.userId,
            targetTripId: widget.tripId,
            attachments: _photos,
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
                        fontFamily: 'Manrope',
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
                fontFamily: 'Manrope',
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
          if (_photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _photos.length; i++)
                    Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        child: Image.file(_photos[i], width: 72, height: 72, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: IconButton(
                          onPressed: () => setState(() => _photos.removeAt(i)),
                          icon: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 14, color: Colors.white)),
                          tooltip: 'complaint.remove_photo_label'.tr(),
                        ),
                      ),
                    ]),
                ],
              ),
            ),
          if (_photos.length < 5)
            GestureDetector(
              onTap: _pickPhotos,
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
            loading: _submitting,
            onPressed: valid && !_submitting ? _submit : null,
          ),
        ],
      ),
    );
  }
}
