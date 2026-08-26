import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/car.dart';
import '../theme/colors.dart';
import '../theme/dimens.dart';

/// Shared car-form pickers (colour list + year selector + the select box),
/// used by both the garage add-car sheet and the driver-verification form so
/// the two stay identical. Colours are picked from the catalog (swatch + name
/// in the UI language); the year is a plain year selector — no month/day.

const kCarManual = '__manual__';
const int kMinCarYear = 2000;

Color carHexColor(String hex) {
  final v = int.tryParse(hex.replaceFirst('#', ''), radix: 16) ?? 0;
  return Color(v | 0xFF000000);
}

/// UI language is Kyrgyz. Uses the built-in Localizations (null-safe) so it also
/// works in widget tests that don't mount the EasyLocalization widget.
bool carLocaleIsKy(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode == 'ky';

Widget carSwatch(String hex, {double size = 20}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: carHexColor(hex), shape: BoxShape.circle, border: Border.all(color: InkColors.c300)),
    );

/// A tap-to-open select box (matches the brand/model picker style). Optional
/// [leading] shows a colour swatch for the current value.
Widget carSelectBox({
  required bool dark,
  required String value,
  required String hint,
  VoidCallback? onTap,
  Widget? leading,
}) {
  return GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: dark ? InkColors.c800 : InkColors.c50,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: dark ? InkColors.c700 : InkColors.c200),
      ),
      child: Row(children: [
        if (leading != null) ...[leading, const SizedBox(width: 8)],
        Expanded(
          child: Text(
            value.isEmpty ? hint : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: value.isEmpty ? InkColors.c400 : (dark ? Colors.white : InkColors.c900)),
          ),
        ),
        Icon(Icons.expand_more, size: 20, color: onTap == null ? InkColors.c300 : InkColors.c500),
      ]),
    ),
  );
}

Widget _sheetShell(BuildContext ctx, bool dark, String title, Widget body) {
  return Container(
    height: MediaQuery.of(ctx).size.height * 0.7,
    decoration: BoxDecoration(color: dark ? InkColors.c900 : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl4))),
    padding: EdgeInsets.only(top: 12, bottom: MediaQuery.of(ctx).viewInsets.bottom),
    // Transparent Material so ListTile rows have a Material ancestor for their
    // ink splashes (the coloured Container above would otherwise hide them).
    child: Material(
      type: MaterialType.transparency,
      child: Column(children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: InkColors.c300, borderRadius: BorderRadius.circular(999)))),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(alignment: Alignment.centerLeft, child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: dark ? Colors.white : InkColors.c900))),
        ),
        const SizedBox(height: 8),
        Expanded(child: body),
      ]),
    ),
  );
}

/// Colour picker: swatch + localized name rows, plus a manual-entry row.
/// Returns the canonical Russian name, [kCarManual], or null (dismissed).
Future<String?> showCarColorPicker(BuildContext context, {required bool dark, required List<CarColor> colors}) {
  final ky = carLocaleIsKy(context);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _sheetShell(
      ctx,
      dark,
      'profile.car_color'.tr(),
      ListView(children: [
        for (final c in colors)
          ListTile(
            leading: carSwatch(c.hex),
            title: Text(ky ? c.nameKy : c.nameRu, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900)),
            onTap: () => Navigator.pop(ctx, c.nameRu),
          ),
        ListTile(
          leading: const Icon(Icons.edit_outlined, size: 20, color: GrapeColors.c600),
          title: Text('profile.manual_entry'.tr(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: GrapeColors.c600)),
          onTap: () => Navigator.pop(ctx, kCarManual),
        ),
      ]),
    ),
  );
}

/// Year picker: newest → [kMinCarYear]. Returns the chosen year or null.
Future<int?> showCarYearPicker(BuildContext context, {required bool dark}) {
  final years = [for (var y = DateTime.now().year; y >= kMinCarYear; y--) y];
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _sheetShell(
      ctx,
      dark,
      'driver_reg.year_label'.tr(),
      ListView(children: [
        for (final y in years)
          ListTile(
            title: Text('$y', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: dark ? Colors.white : InkColors.c900)),
            onTap: () => Navigator.pop(ctx, y),
          ),
      ]),
    ),
  );
}
