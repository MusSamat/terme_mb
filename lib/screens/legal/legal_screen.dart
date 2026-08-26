import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/legal_content.dart';
import '../../theme/colors.dart';

/// Legal pages (about / privacy / terms). Copy is versioned inline in
/// `legal_content.dart` (ported 1:1 from the web) — heading + paragraphs render
/// per section in the active locale.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.kind});
  final String kind; // about | privacy | terms

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final doc = legalDoc(kind, context.locale.languageCode);
    final ink = dark ? Colors.white : InkColors.c900;
    final body = dark ? InkColors.c300 : InkColors.c600;

    return Scaffold(
      backgroundColor: dark ? InkColors.c950 : InkColors.c50,
      appBar: AppBar(
        backgroundColor: dark ? InkColors.c950 : InkColors.c50,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Text(doc.title,
            style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 20, color: ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(doc.title, style: TextStyle(fontSize: 24, height: 1.15, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 4),
          Text(doc.updated, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: InkColors.c400)),
          const SizedBox(height: 20),
          for (final s in doc.sections) ...[
            Text(s.heading, style: TextStyle(fontSize: 16, height: 1.3, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 6),
            for (final p in s.paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(p, style: TextStyle(fontSize: 14, height: 1.6, fontWeight: FontWeight.w500, color: body)),
              ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
