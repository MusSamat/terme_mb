import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../widgets/logo_mark.dart';

/// Legal pages (about / privacy / terms). Full copy lives in i18n once the
/// legal content is finalized; for now the title + a placeholder body render.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});
  final String kind; // about | privacy | terms

  String get _titleKey => switch (kind) {
        'privacy' => 'footer.privacy',
        'terms' => 'footer.terms',
        _ => 'footer.about',
      };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(_titleKey.tr(),
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: dark ? Colors.white : InkColors.c900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Row(children: [
            LogoMark(size: 32),
            SizedBox(width: 10),
            Wordmark(fontSize: 22),
          ]),
          const SizedBox(height: 12),
          Text(
            'footer.tagline'.tr(),
            style: TextStyle(
                fontSize: 15,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: dark ? InkColors.c300 : InkColors.c600),
          ),
        ],
      ),
    );
  }
}
